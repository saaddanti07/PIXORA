package com.pixora.app.engine

import org.junit.Assert.assertEquals
import org.junit.Test

class RgbTensorCodecTest {
    @Test fun extractsRedGreenBlueInNchwPlaneOrder() {
        val pixels = intArrayOf(0xFFFF0000.toInt(), 0xFF00FF00.toInt(), 0xFF0000FF.toInt(), -1)
        val target = FloatArray(12)
        RgbTensorCodec.writeTile(pixels, 2, 0, 0, 2, "NCHW", 0f..1f, target)
        assertEquals(listOf(1f, 0f, 0f, 1f), target.slice(0..3))
        assertEquals(listOf(0f, 1f, 0f, 1f), target.slice(4..7))
        assertEquals(listOf(0f, 0f, 1f, 1f), target.slice(8..11))
    }

    @Test fun extractsRgbInterleavedInNhwcOrderAndAppliesRecordedRange() {
        val target = FloatArray(3)
        RgbTensorCodec.writeTile(
            intArrayOf(0xFFFF8000.toInt()), 1, 0, 0, 1, "NHWC", -1f..1f, target,
        )
        assertEquals(1f, target[0], 0.00001f)
        assertEquals(0.0039216f, target[1], 0.0001f)
        assertEquals(-1f, target[2], 0.00001f)
    }

    @Test fun decodesNchwModelOutputToArgbInRgbOrder() {
        // A 2x2 NCHW tensor: first row is red then green.
        val pixels = floatArrayOf(
            1f, 0f, 0f, 0f, // red plane
            0f, 1f, 0f, 0f, // green plane
            0f, 0f, 0f, 0f, // blue plane
        )
        assertEquals(0xFFFF0000.toInt(), RgbTensorCodec.outputPixel(pixels, "NCHW", 2, 0, 0, 0f..1f))
        assertEquals(0xFF00FF00.toInt(), RgbTensorCodec.outputPixel(pixels, "NCHW", 2, 1, 0, 0f..1f))
    }

    @Test fun decodesNhwcOutputAndClampsDenormalizedValues() {
        val pixel = RgbTensorCodec.outputPixel(
            floatArrayOf(1.2f, -0.1f, 0.5f), "NHWC", 1, 0, 0, 0f..1f,
        )
        assertEquals(0xFFFF0080.toInt(), pixel)
    }
}
