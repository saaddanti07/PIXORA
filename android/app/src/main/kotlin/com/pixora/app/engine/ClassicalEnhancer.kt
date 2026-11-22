package com.pixora.app.engine

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.FileOutputStream
import kotlin.math.roundToInt

/**
 * "Fast enhancement" — the classical, non-AI path.
 *
 * This is what runs on photographs that are too large for the neural network, on
 * devices that fail the capability check, and as the fallback whenever the AI
 * path is unavailable. It is explicitly **not** labelled as AI anywhere in the
 * app: it repairs tone and micro-contrast with well-understood image processing
 * (auto levels from a luminance histogram, a gentle saturation lift and an
 * unsharp mask), and it is deterministic and fast on every device.
 *
 * It never upscales beyond the source resolution; when the photograph is larger
 * than the working ceiling it is downscaled, and the outcome reports both sizes
 * so the UI can say so plainly.
 */
class ClassicalEnhancer(private val context: Context) {

    data class Outcome(
        val outputPath: String,
        val sourceWidth: Int,
        val sourceHeight: Int,
        val width: Int,
        val height: Int,
        val durationMs: Long,
    ) {
        val downscaled: Boolean get() = width < sourceWidth || height < sourceHeight
    }

    fun enhance(
        sourcePath: String,
        outputPath: String,
        maxDimension: Int = 2048,
        jpegQuality: Int = 95,
        isCancelled: () -> Boolean = { false },
    ): Outcome {
        val started = System.currentTimeMillis()
        val source = File(sourcePath)
        if (!source.isFile) throw IllegalArgumentException("source not found: $sourcePath")

        val rotation = orientationOf(sourcePath)
        val (rawWidth, rawHeight) = boundsOf(sourcePath)
        val swap = rotation == 90 || rotation == 270
        val sourceWidth = if (swap) rawHeight else rawWidth
        val sourceHeight = if (swap) rawWidth else rawHeight

        val factor = if (maxOf(sourceWidth, sourceHeight) > maxDimension) {
            maxDimension.toDouble() / maxOf(sourceWidth, sourceHeight)
        } else {
            1.0
        }
        val targetWidth = (sourceWidth * factor).roundToInt().coerceAtLeast(1)
        val targetHeight = (sourceHeight * factor).roundToInt().coerceAtLeast(1)

        var bitmap = decode(sourcePath, if (swap) targetHeight else targetWidth,
            if (swap) targetWidth else targetHeight)
        if (rotation != 0) {
            val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated !== bitmap) bitmap.recycle()
            bitmap = rotated
        }
        try {
            if (isCancelled()) throw JobCancelledException()
            val width = bitmap.width
            val height = bitmap.height
            val pixels = IntArray(width * height)
            bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

            applyLevels(pixels)
            applySaturation(pixels, 1.06f)
            applyUnsharpMask(pixels, width, height, amount = 0.55f)
            bitmap.setPixels(pixels, 0, width, 0, 0, width, height)

            val file = File(outputPath)
            file.parentFile?.mkdirs()
            FileOutputStream(file).use { stream ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, jpegQuality, stream)) {
                    throw IllegalStateException("JPEG encoding failed")
                }
            }
            return Outcome(
                outputPath = file.absolutePath,
                sourceWidth = sourceWidth,
                sourceHeight = sourceHeight,
                width = width,
                height = height,
                durationMs = System.currentTimeMillis() - started,
            )
        } finally {
            bitmap.recycle()
        }
    }

    // ------------------------------------------------------------- pipeline

    /** Auto levels driven by luminance percentiles, applied equally to RGB. */
    private fun applyLevels(pixels: IntArray) {
        val histogram = IntArray(256)
        for (pixel in pixels) {
            val r = (pixel shr 16) and 0xFF
            val g = (pixel shr 8) and 0xFF
            val b = pixel and 0xFF
            histogram[(r * 299 + g * 587 + b * 114) / 1000]++
        }
        val total = pixels.size.toLong()
        val lowCut = (total * 0.005).toLong()
        val highCut = (total * 0.995).toLong()
        var low = 0
        var high = 255
        var running = 0L
        for (value in 0..255) {
            running += histogram[value]
            if (running >= lowCut) { low = value; break }
        }
        running = 0
        for (value in 255 downTo 0) {
            running += histogram[value]
            if (running >= total - highCut) { high = value; break }
        }
        if (high - low < 8) return // already flat or degenerate: leave it alone

        val lut = IntArray(256)
        for (value in 0..255) {
            val scaled = ((value - low) * 255.0 / (high - low)).roundToInt()
            lut[value] = scaled.coerceIn(0, 255)
        }
        for (index in pixels.indices) {
            val pixel = pixels[index]
            val r = lut[(pixel shr 16) and 0xFF]
            val g = lut[(pixel shr 8) and 0xFF]
            val b = lut[pixel and 0xFF]
            pixels[index] = (pixel and -0x1000000) or (r shl 16) or (g shl 8) or b
        }
    }

    private fun applySaturation(pixels: IntArray, factor: Float) {
        for (index in pixels.indices) {
            val pixel = pixels[index]
            val r = (pixel shr 16) and 0xFF
            val g = (pixel shr 8) and 0xFF
            val b = pixel and 0xFF
            val luma = (r * 299 + g * 587 + b * 114) / 1000
            val nr = (luma + (r - luma) * factor).roundToInt().coerceIn(0, 255)
            val ng = (luma + (g - luma) * factor).roundToInt().coerceIn(0, 255)
            val nb = (luma + (b - luma) * factor).roundToInt().coerceIn(0, 255)
            pixels[index] = (pixel and -0x1000000) or (nr shl 16) or (ng shl 8) or nb
        }
    }

    /** Unsharp mask with a 3x3 box blur; recovers micro-contrast without halos. */
    private fun applyUnsharpMask(pixels: IntArray, width: Int, height: Int, amount: Float) {
        if (width < 3 || height < 3) return
        val blurred = IntArray(pixels.size)
        for (y in 0 until height) {
            val y0 = if (y == 0) 0 else y - 1
            val y2 = if (y == height - 1) height - 1 else y + 1
            val row0 = y0 * width
            val row1 = y * width
            val row2 = y2 * width
            for (x in 0 until width) {
                val x0 = if (x == 0) 0 else x - 1
                val x2 = if (x == width - 1) width - 1 else x + 1
                var r = 0
                var g = 0
                var b = 0
                for (offset in 0 until 3) {
                    val row = when (offset) {
                        0 -> row0
                        1 -> row1
                        else -> row2
                    }
                    for (step in 0 until 3) {
                        val column = when (step) {
                            0 -> x0
                            1 -> x
                            else -> x2
                        }
                        val pixel = pixels[row + column]
                        r += (pixel shr 16) and 0xFF
                        g += (pixel shr 8) and 0xFF
                        b += pixel and 0xFF
                    }
                }
                blurred[row1 + x] = -0x1000000 or ((r / 9) shl 16) or ((g / 9) shl 8) or (b / 9)
            }
        }
        for (index in pixels.indices) {
            val original = pixels[index]
            val soft = blurred[index]
            val r = sharpen((original shr 16) and 0xFF, (soft shr 16) and 0xFF, amount)
            val g = sharpen((original shr 8) and 0xFF, (soft shr 8) and 0xFF, amount)
            val b = sharpen(original and 0xFF, soft and 0xFF, amount)
            pixels[index] = (original and -0x1000000) or (r shl 16) or (g shl 8) or b
        }
    }

    private fun sharpen(value: Int, blurred: Int, amount: Float): Int =
        (value + amount * (value - blurred)).roundToInt().coerceIn(0, 255)

    // ---------------------------------------------------------------- input

    private fun boundsOf(path: String): Pair<Int, Int> {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, options)
        if (options.outWidth <= 0 || options.outHeight <= 0) {
            throw IllegalArgumentException("unsupported or unreadable image: $path")
        }
        return options.outWidth to options.outHeight
    }

    private fun orientationOf(path: String): Int = try {
        when (
            ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        ) {
            ExifInterface.ORIENTATION_ROTATE_90, ExifInterface.ORIENTATION_TRANSPOSE -> 90
            ExifInterface.ORIENTATION_ROTATE_180, ExifInterface.ORIENTATION_FLIP_VERTICAL -> 180
            ExifInterface.ORIENTATION_ROTATE_270, ExifInterface.ORIENTATION_TRANSVERSE -> 270
            else -> 0
        }
    } catch (error: Exception) {
        Log.w(TAG, "EXIF unreadable, assuming upright", error)
        0
    }

    private fun decode(path: String, targetWidth: Int, targetHeight: Int): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while (
            bounds.outWidth / (sample * 2) >= targetWidth &&
            bounds.outHeight / (sample * 2) >= targetHeight
        ) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = BitmapFactory.decodeFile(path, options)
            ?: throw IllegalArgumentException("image could not be decoded: $path")
        if (decoded.width == targetWidth && decoded.height == targetHeight) return decoded
        val scaled = Bitmap.createScaledBitmap(decoded, targetWidth, targetHeight, true)
        if (scaled !== decoded) decoded.recycle()
        return scaled
    }

    private companion object {
        const val TAG = "PixoraClassical"
    }
}
