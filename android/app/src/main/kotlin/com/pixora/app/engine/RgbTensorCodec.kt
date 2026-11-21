package com.pixora.app.engine

import kotlin.math.roundToInt

/** Pure RGB/NCHW/NHWC conversion helpers so tensor order/range can be tested. */
object RgbTensorCodec {
    fun writeTile(
        pixels: IntArray,
        bitmapWidth: Int,
        startX: Int,
        startY: Int,
        size: Int,
        layout: String,
        valueRange: ClosedFloatingPointRange<Float>,
        target: FloatArray,
    ) {
        require(layout == "NCHW" || layout == "NHWC")
        require(target.size >= size * size * 3)
        val range = valueRange.endInclusive - valueRange.start
        require(range > 0f)
        fun normalized(pixel: Int, shift: Int): Float =
            valueRange.start + (((pixel shr shift) and 0xFF) / 255f) * range
        if (layout == "NCHW") {
            val plane = size * size
            for (channel in 0..2) {
                val shift = 16 - channel * 8
                var out = channel * plane
                for (y in 0 until size) {
                    val base = (startY + y) * bitmapWidth + startX
                    for (x in 0 until size) target[out++] = normalized(pixels[base + x], shift)
                }
            }
        } else {
            var out = 0
            for (y in 0 until size) {
                val base = (startY + y) * bitmapWidth + startX
                for (x in 0 until size) {
                    val pixel = pixels[base + x]
                    target[out++] = normalized(pixel, 16)
                    target[out++] = normalized(pixel, 8)
                    target[out++] = normalized(pixel, 0)
                }
            }
        }
    }

    fun outputPixel(
        values: FloatArray,
        layout: String,
        width: Int,
        x: Int,
        y: Int,
        valueRange: ClosedFloatingPointRange<Float>,
    ): Int {
        val range = valueRange.endInclusive - valueRange.start
        require(range > 0f)
        val index = y * width + x
        val plane = width * width
        val red: Float
        val green: Float
        val blue: Float
        if (layout == "NCHW") {
            red = values[index]
            green = values[plane + index]
            blue = values[2 * plane + index]
        } else {
            val offset = index * 3
            red = values[offset]
            green = values[offset + 1]
            blue = values[offset + 2]
        }
        fun byte(value: Float): Int = (((value - valueRange.start) / range) * 255f)
            .roundToInt().coerceIn(0, 255)
        return 0xFF000000.toInt() or (byte(red) shl 16) or (byte(green) shl 8) or byte(blue)
    }

}
