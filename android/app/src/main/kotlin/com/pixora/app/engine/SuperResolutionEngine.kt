package com.pixora.app.engine

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** One restoration job, in the units the engine actually enforces. */
data class RestoreRequest(
    val sourcePath: String,
    val outputPath: String,
    /** Ceiling for the pixels handed to the network (≈0.75 MP by default). */
    val maxInputPixels: Int = 750_000,
    /** Ceiling for the produced image; also caps the working resolution. */
    val maxOutputDimension: Int = 2048,
    val halo: Int = 16,
    val jpegQuality: Int = 95,
)

data class RestoreProgress(
    val completedTiles: Int,
    val totalTiles: Int,
    val elapsedMs: Long,
) {
    /** Linear projection; -1 while it is still meaningless. */
    val estimatedRemainingMs: Long
        get() = if (completedTiles <= 0) -1L
        else ((elapsedMs.toDouble() / completedTiles) * (totalTiles - completedTiles)).toLong()
}

data class RestoreOutcome(
    val outputPath: String,
    val sourceWidth: Int,
    val sourceHeight: Int,
    val workingWidth: Int,
    val workingHeight: Int,
    val outputWidth: Int,
    val outputHeight: Int,
    val tiles: Int,
    val durationMs: Long,
) {
    /** True when the source had to be reduced before the network saw it. */
    val downscaled: Boolean get() = workingWidth < sourceWidth || workingHeight < sourceHeight
}

/**
 * Tiled Real-ESRGAN restoration on LiteRT.
 *
 * Pipeline for one job:
 *
 * 1. read the source bounds and EXIF orientation without decoding pixels;
 * 2. decide the *working* resolution — the AI path only ever processes a few
 *    hundred thousand pixels, because the cost is linear in input area;
 * 3. decode at a reduced sample size (never a full 12 MP bitmap), scale, rotate;
 * 4. mirror-pad the working image so edge tiles have real neighbours;
 * 5. run every tile through the network with a halo of context that is then
 *    discarded, writing each tile's contribution exactly once;
 * 6. encode JPEG.
 *
 * Cancellation is checked between tiles; a cancelled job deletes its output.
 */
class SuperResolutionEngine(
    private val context: Context,
    private val modelAsset: String = ModelMeta.DEFAULT_MODEL_ASSET,
    private val metaAsset: String = ModelMeta.metaAssetFor(ModelMeta.DEFAULT_MODEL_ASSET),
) {
    private val meta: ModelMeta? = ModelMeta.load(context, metaAsset)
    private var runner: LiteRtRunner? = null

    val isAvailable: Boolean get() = meta != null
    val modelId: String get() = meta?.modelId ?: "real_esrgan_general_x4v3"
    val scale: Int get() = meta?.scale ?: 4
    val tileSize: Int get() = meta?.inputWidth ?: 128

    /** Pixels the network can accept in one job at the current output ceiling. */
    fun supportsOutputDimension(dimension: Int): Boolean =
        meta != null && dimension / scale >= tileSize

    fun restore(
        request: RestoreRequest,
        threads: Int,
        onProgress: (RestoreProgress) -> Unit,
        isCancelled: () -> Boolean,
    ): RestoreOutcome {
        val model = meta ?: throw IllegalStateException("model metadata missing")
        val started = System.currentTimeMillis()
        val source = File(request.sourcePath)
        if (!source.isFile) throw IllegalArgumentException("source not found: ${request.sourcePath}")

        var outputFile: File? = null
        var working: Bitmap? = null
        var outputBitmap: Bitmap? = null
        try {
            val orientation = orientationOf(request.sourcePath)
            val (rawWidth, rawHeight) = boundsOf(request.sourcePath)
            val swap = orientation in 5..8
            val sourceWidth = if (swap) rawHeight else rawWidth
            val sourceHeight = if (swap) rawWidth else rawHeight

            val (workingWidth, workingHeight) = workingSize(
                sourceWidth = sourceWidth,
                sourceHeight = sourceHeight,
                maxOutputDimension = request.maxOutputDimension,
                maxInputPixels = request.maxInputPixels,
                scale = model.scale,
                tile = model.inputWidth,
            )

            working = decodeWorking(
                path = request.sourcePath,
                workingWidth = workingWidth,
                workingHeight = workingHeight,
                swapAxes = swap,
                orientation = orientation,
            )

            val sourcePixels = IntArray(working.width * working.height)
            working.getPixels(sourcePixels, 0, working.width, 0, 0, working.width, working.height)
            val padded = mirrorPad(sourcePixels, working.width, working.height, request.halo)

            val outputWidth = working.width * model.scale
            val outputHeight = working.height * model.scale
            val outBitmap = Bitmap.createBitmap(outputWidth, outputHeight, Bitmap.Config.ARGB_8888)
            outputBitmap = outBitmap

            val plan = TilePlan(
                sourceWidth = working.width,
                sourceHeight = working.height,
                tileSize = model.inputWidth,
                halo = request.halo,
            )

            val engine = obtainRunner(threads)
            val pixelsOut = IntArray(plan.stride * model.scale * plan.stride * model.scale)
            val tileStarted = System.currentTimeMillis()

            for (index in 0 until plan.tileCount) {
                if (isCancelled()) throw JobCancelledException()
                val window = plan.window(index)
                extractTile(
                    padded = padded,
                    paddedWidth = plan.paddedWidth,
                    window = window,
                    tile = model.inputWidth,
                    layout = model.inputLayout,
                    valueRange = model.valueRange,
                    target = engine.input,
                )
                engine.runTile()
                composeTile(
                    tileOutput = engine.output,
                    layout = model.outputLayout,
                    valueRange = model.valueRange,
                    modelSize = model.inputWidth * model.scale,
                    scale = model.scale,
                    halo = request.halo,
                    window = window,
                    target = pixelsOut,
                    bitmap = outBitmap,
                )
                onProgress(
                    RestoreProgress(
                        completedTiles = index + 1,
                        totalTiles = plan.tileCount,
                        elapsedMs = System.currentTimeMillis() - tileStarted,
                    ),
                )
            }

            outputFile = File(request.outputPath)
            outputFile.parentFile?.mkdirs()
            FileOutputStream(outputFile).use { stream ->
                if (!outBitmap.compress(Bitmap.CompressFormat.JPEG, request.jpegQuality, stream)) {
                    throw IllegalStateException("JPEG encoding failed")
                }
            }

            val duration = System.currentTimeMillis() - started
            Log.i(
                TAG,
                "restored ${working.width}x${working.height} -> ${outputWidth}x$outputHeight " +
                    "in $duration ms (${plan.tileCount} tiles)",
            )
            return RestoreOutcome(
                outputPath = outputFile.absolutePath,
                sourceWidth = sourceWidth,
                sourceHeight = sourceHeight,
                workingWidth = working.width,
                workingHeight = working.height,
                outputWidth = outputWidth,
                outputHeight = outputHeight,
                tiles = plan.tileCount,
                durationMs = duration,
            )
        } catch (error: Throwable) {
            // Never leave a half-written file behind: the UI would show it as a result.
            outputFile?.delete()
            outputBitmap?.recycle()
            throw error
        } finally {
            working?.recycle()
        }
    }

    fun close() {
        runner?.close()
        runner = null
    }

    private fun obtainRunner(threads: Int): LiteRtRunner {
        runner?.let { return it }
        val model = meta ?: throw IllegalStateException("model metadata missing")
        return LiteRtRunner.create(context, modelAsset, model, threads).also { runner = it }
    }

    // ---------------------------------------------------------------- inputs

    private fun boundsOf(path: String): Pair<Int, Int> {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, options)
        if (options.outWidth <= 0 || options.outHeight <= 0) {
            throw IllegalArgumentException("unsupported or unreadable image: $path")
        }
        return options.outWidth to options.outHeight
    }

    /** EXIF orientation tag (1..8), preserved so mirrored variants are handled too. */
    private fun orientationOf(path: String): Int = try {
        ExifInterface(path).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        ).coerceIn(1, 8)
    } catch (error: Exception) {
        Log.w(TAG, "EXIF unreadable, assuming upright", error)
        ExifInterface.ORIENTATION_NORMAL
    }

    /**
     * Working resolution: the largest size that satisfies *both* ceilings —
     * the output dimension divided by the scale factor, and the AI input-pixel
     * budget. A small photo is never enlarged here; the network does that.
     */
    private fun workingSize(
        sourceWidth: Int,
        sourceHeight: Int,
        maxOutputDimension: Int,
        maxInputPixels: Int,
        scale: Int,
        tile: Int,
    ): Pair<Int, Int> {
        val longEdge = max(sourceWidth, sourceHeight)
        val maxWorkingLong = max(tile, maxOutputDimension / scale)
        var factor = 1.0
        if (longEdge > maxWorkingLong) factor = min(factor, maxWorkingLong.toDouble() / longEdge)
        val pixels = sourceWidth.toDouble() * sourceHeight
        if (pixels > maxInputPixels) factor = min(factor, sqrt(maxInputPixels / pixels))
        val width = max(tile, (sourceWidth * factor).roundToInt())
        val height = max(tile, (sourceHeight * factor).roundToInt())
        return min(width, sourceWidth) to min(height, sourceHeight)
    }

    private fun decodeWorking(
        path: String,
        workingWidth: Int,
        workingHeight: Int,
        swapAxes: Boolean,
        orientation: Int,
    ): Bitmap {
        val rawTargetWidth = if (swapAxes) workingHeight else workingWidth
        val rawTargetHeight = if (swapAxes) workingWidth else workingHeight

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)

        var sample = 1
        while (
            bounds.outWidth / (sample * 2) >= rawTargetWidth &&
            bounds.outHeight / (sample * 2) >= rawTargetHeight
        ) {
            sample *= 2
        }

        val decodeOptions = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = BitmapFactory.decodeFile(path, decodeOptions)
            ?: throw IllegalArgumentException("image could not be decoded: $path")

        var bitmap = decoded
        if (bitmap.width != rawTargetWidth || bitmap.height != rawTargetHeight) {
            val scaled = Bitmap.createScaledBitmap(bitmap, rawTargetWidth, rawTargetHeight, true)
            if (scaled !== bitmap) bitmap.recycle()
            bitmap = scaled
        }
        if (orientation != ExifInterface.ORIENTATION_NORMAL) {
            val w = bitmap.width.toFloat()
            val h = bitmap.height.toFloat()
            val values = when (orientation) {
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> floatArrayOf(-1f, 0f, w, 0f, 1f, 0f, 0f, 0f, 1f)
                ExifInterface.ORIENTATION_ROTATE_180 -> floatArrayOf(-1f, 0f, w, 0f, -1f, h, 0f, 0f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> floatArrayOf(1f, 0f, 0f, 0f, -1f, h, 0f, 0f, 1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> floatArrayOf(0f, 1f, 0f, 1f, 0f, 0f, 0f, 0f, 1f)
                ExifInterface.ORIENTATION_ROTATE_90 -> floatArrayOf(0f, -1f, h, 1f, 0f, 0f, 0f, 0f, 1f)
                ExifInterface.ORIENTATION_TRANSVERSE -> floatArrayOf(0f, -1f, h, -1f, 0f, w, 0f, 0f, 1f)
                ExifInterface.ORIENTATION_ROTATE_270 -> floatArrayOf(0f, 1f, 0f, -1f, 0f, w, 0f, 0f, 1f)
                else -> floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f)
            }
            val matrix = Matrix().apply { setValues(values) }
            val oriented = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (oriented !== bitmap) bitmap.recycle()
            bitmap = oriented
        }
        return bitmap
    }

    /** Reflect-101 padding so every edge tile sees plausible neighbours. */
    private fun mirrorPad(source: IntArray, width: Int, height: Int, halo: Int): IntArray {
        if (halo == 0) return source
        val paddedWidth = width + 2 * halo
        val paddedHeight = height + 2 * halo
        val padded = IntArray(paddedWidth * paddedHeight)
        for (y in 0 until paddedHeight) {
            val sourceY = reflect(y - halo, height)
            val targetRow = y * paddedWidth
            val sourceRow = sourceY * width
            for (x in 0 until paddedWidth) {
                padded[targetRow + x] = source[sourceRow + reflect(x - halo, width)]
            }
        }
        return padded
    }

    private fun reflect(index: Int, size: Int): Int {
        if (size <= 1) return 0
        val period = 2 * (size - 1)
        var value = index % period
        if (value < 0) value += period
        return if (value >= size) period - value else value
    }

    // -------------------------------------------------------------- tile I/O

    private fun extractTile(
        padded: IntArray,
        paddedWidth: Int,
        window: TileWindow,
        tile: Int,
        layout: String,
        valueRange: ClosedFloatingPointRange<Float>,
        target: FloatArray,
    ) = RgbTensorCodec.writeTile(
        pixels = padded,
        bitmapWidth = paddedWidth,
        startX = window.x,
        startY = window.y,
        size = tile,
        layout = layout,
        valueRange = valueRange,
        target = target,
    )

    /**
     * Writes exactly the non-overlapping partition assigned by TilePlan.
     * Overlap predictions are divided at their midpoint; no pixel is omitted
     * or overwritten, and each selected sample retains the model halo context.
     */
    private fun composeTile(
        tileOutput: FloatArray,
        layout: String,
        valueRange: ClosedFloatingPointRange<Float>,
        modelSize: Int,
        scale: Int,
        halo: Int,
        window: TileWindow,
        target: IntArray,
        bitmap: Bitmap,
    ) {
        val writeStartX = window.writeX
        val writeStartY = window.writeY
        val columns = window.writeWidth
        val rows = window.writeHeight
        if (columns <= 0 || rows <= 0) return

        require(valueRange.endInclusive > valueRange.start) { "invalid model output range: $valueRange" }
        val sourceOffsetX = (halo + writeStartX - window.x) * scale
        val sourceOffsetY = (halo + writeStartY - window.y) * scale
        var targetIndex = 0
        for (row in 0 until rows * scale) {
            val sourceY = sourceOffsetY + row
            for (column in 0 until columns * scale) {
                val sourceX = sourceOffsetX + column
                target[targetIndex++] = RgbTensorCodec.outputPixel(
                    values = tileOutput,
                    layout = layout,
                    width = modelSize,
                    x = sourceX,
                    y = sourceY,
                    valueRange = valueRange,
                )
            }
        }
        bitmap.setPixels(
            target,
            0,
            columns * scale,
            writeStartX * scale,
            writeStartY * scale,
            columns * scale,
            rows * scale,
        )
    }

    private companion object {
        const val TAG = "PixoraEngine"
    }
}
