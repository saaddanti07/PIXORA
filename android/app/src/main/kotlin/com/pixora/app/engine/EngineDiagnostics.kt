package com.pixora.app.engine

import android.graphics.Bitmap
import android.util.Log
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.Locale

/** Private, debug-build-only stage evidence; no pixels or user paths are logged. */
internal class EngineDiagnostics(
    private val cacheDirectory: File,
    enabled: Boolean,
) {
    private val active = enabled
    private val input = FloatSummary()
    private val output = FloatSummary()
    private var rawDirectory: File? = null

    fun source(file: File, rawWidth: Int, rawHeight: Int, orientation: Int) = trace("source") {
        log("source", "fileBytes=${file.length()} sha256=${sha256(file)} raw=${rawWidth}x$rawHeight exif=$orientation")
    }

    fun working(bitmap: Bitmap, pixels: IntArray) = trace("working_bitmap") {
        log("working_bitmap", "${bitmap.width}x${bitmap.height} ${pixelStats(pixels)}")
    }

    fun inputTile(values: FloatArray, tileIndex: Int, layout: String, width: Int, height: Int) =
        trace("input_tensor") {
            input.add(values, layout, width, height)
            if (tileIndex == 0) dump("first_input_tile.f32le", values)
        }

    fun outputTile(values: FloatArray, tileIndex: Int, layout: String, width: Int, height: Int) =
        trace("raw_model_output") {
            output.add(values, layout, width, height)
            if (tileIndex == 0) dump("first_raw_output_tile.f32le", values)
        }

    fun finishTensors(
        inputLayout: String,
        outputLayout: String,
        inputWidth: Int,
        inputHeight: Int,
        outputWidth: Int,
        outputHeight: Int,
        valueRange: ClosedFloatingPointRange<Float>,
        inputTiles: Int,
        outputTiles: Int,
    ) = trace("tensor_summary") {
            log("input_tensor", "shape=${tensorShape(inputLayout, inputWidth, inputHeight)} layout=$inputLayout range=$valueRange tiles=$inputTiles ${input.finish()}")
            log("raw_model_output", "shape=${tensorShape(outputLayout, outputWidth, outputHeight)} layout=$outputLayout range=$valueRange tiles=$outputTiles ${output.finish()}")
            rawDirectory?.let {
                log("raw_tensor_files", "privateCache=${it.absolutePath}; files are little-endian float32 from tile 0")
            }
        }

    fun stitched(bitmap: Bitmap) = trace("stitched_bitmap") {
        val pixels = IntArray(bitmap.width)
        val summary = PixelSummary()
        for (y in 0 until bitmap.height) {
            bitmap.getPixels(pixels, 0, bitmap.width, 0, y, bitmap.width, 1)
            summary.add(pixels)
        }
        log("stitched_bitmap", "${bitmap.width}x${bitmap.height} ${summary.finish()}")
    }

    fun encoded(file: File, width: Int, height: Int) = trace("encoded_output") {
        log("encoded_output", "${width}x$height fileBytes=${file.length()} sha256=${sha256(file)}")
    }

    private inline fun trace(stage: String, block: () -> Unit) {
        if (!active) return
        try {
            block()
        } catch (error: Exception) {
            // A full cache, unsupported hash provider, or diagnostic bug must
            // never turn successful inference into a failed user job.
            Log.w(TAG, "debug trace stage=$stage unavailable (${error.javaClass.simpleName})")
        }
    }

    private fun dump(name: String, values: FloatArray) {
        val directory = rawDirectory ?: File(cacheDirectory, "pixora_engine_diagnostics").apply {
            deleteRecursively()
            mkdirs()
        }.also { rawDirectory = it }
        val target = File(directory, name)
        FileOutputStream(target).use { stream ->
            val bytes = ByteBuffer.allocate(64 * 1024).order(ByteOrder.LITTLE_ENDIAN)
            var offset = 0
            while (offset < values.size) {
                bytes.clear()
                val count = minOf(bytes.capacity() / Float.SIZE_BYTES, values.size - offset)
                repeat(count) { bytes.putFloat(values[offset++]) }
                stream.write(bytes.array(), 0, bytes.position())
            }
        }
    }

    private fun pixelStats(pixels: IntArray): String = PixelSummary().also { it.add(pixels) }.finish()

    private inner class PixelSummary {
        private val digest = MessageDigest.getInstance("SHA-256")
        private val bytes = ByteBuffer.allocate(64 * 1024).order(ByteOrder.LITTLE_ENDIAN)
        private val sum = DoubleArray(3)
        private val minimum = IntArray(3) { 255 }
        private val maximum = IntArray(3)
        private var count = 0L

        fun add(pixels: IntArray) {
            pixels.forEach { pixel ->
                val channels = intArrayOf((pixel ushr 16) and 255, (pixel ushr 8) and 255, pixel and 255)
                channels.forEachIndexed { channel, value ->
                    sum[channel] += value
                    minimum[channel] = minOf(minimum[channel], value)
                    maximum[channel] = maxOf(maximum[channel], value)
                }
                count++
                if (bytes.remaining() < Int.SIZE_BYTES) flush()
                bytes.putInt(pixel)
            }
        }

        fun finish(): String {
            if (bytes.position() > 0) flush()
            if (count == 0L) return "empty"
            val divisor = count.toDouble()
            return "sha256=${digest.digest().hex()} argbPixels=$count " +
                "rgbMean=${sum.joinToString(",") { format(it / divisor) }} " +
                "rgbMin=${minimum.joinToString(",")} rgbMax=${maximum.joinToString(",")}"
        }

        private fun flush() {
            digest.update(bytes.array(), 0, bytes.position())
            bytes.clear()
        }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        BufferedInputStream(FileInputStream(file)).use { stream ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().hex()
    }

    private fun log(stage: String, message: String) = Log.i(TAG, "TRACE stage=$stage $message")

    private fun format(value: Double): String = String.format(Locale.US, "%.5f", value)

    private fun tensorShape(layout: String, width: Int, height: Int): String =
        if (layout == "NCHW") "1x3x${height}x$width" else "1x${height}x${width}x3"

    private fun ByteArray.hex(): String = joinToString("") { (it.toInt() and 0xff).toString(16).padStart(2, '0') }

    private inner class FloatSummary {
        private val digest = MessageDigest.getInstance("SHA-256")
        private val scratch = ByteBuffer.allocate(64 * 1024).order(ByteOrder.LITTLE_ENDIAN)
        private var count = 0L
        private var sum = 0.0
        private var minimum = Float.POSITIVE_INFINITY
        private var maximum = Float.NEGATIVE_INFINITY
        private val channelSums = DoubleArray(3)
        private val channelCounts = LongArray(3)

        fun add(values: FloatArray, layout: String, width: Int, height: Int) {
            val plane = width * height
            values.forEachIndexed { index, value ->
                minimum = minOf(minimum, value)
                maximum = maxOf(maximum, value)
                sum += value
                val channel = if (layout == "NCHW") index / plane else index % 3
                channelSums[channel] += value
                channelCounts[channel]++
                count++
                if (scratch.remaining() < Float.SIZE_BYTES) flush()
                scratch.putFloat(value)
            }
        }

        fun finish(): String {
            if (scratch.position() > 0) flush()
            if (count == 0L) return "empty"
            val means = channelSums.indices.joinToString(",") { channel ->
                format(channelSums[channel] / channelCounts[channel])
            }
            return "sha256=${digest.digest().hex()} values=$count min=${format(minimum.toDouble())} " +
                "max=${format(maximum.toDouble())} mean=${format(sum / count)} channelMeans=$means"
        }

        private fun flush() {
            digest.update(scratch.array(), 0, scratch.position())
            scratch.clear()
        }
    }

    companion object {
        private const val TAG = "PixoraEngine"
    }
}
