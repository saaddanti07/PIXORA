package com.pixora.app.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TilePlannerTest {
    @Test fun partitionsSmallAndExactDimensionsWithoutGapsOrOverlap() {
        for (width in listOf(1, 95, 96, 97, 191, 192, 193, 200, 287, 288, 289, 512)) {
            val plan = TilePlan(width, 128)
            val writes = (0 until plan.tileCount).map { plan.window(it) }
            val coverage = IntArray(width)
            writes.forEach { window ->
                for (x in window.writeX until window.writeX + window.writeWidth) coverage[x]++
            }
            assertTrue("width=$width windows=${writes.map { it.writeX to it.writeWidth }}",
                coverage.all { it == 1 })
            assertEquals(0, writes.first().writeX)
            assertEquals(width, writes.last().writeX + writes.last().writeWidth)
        }
    }

    @Test fun twoDimensionalPartitionsCoverEveryPixelExactlyOnce() {
        val plan = TilePlan(200, 193)
        val coverage = IntArray(plan.sourceWidth * plan.sourceHeight)
        for (index in 0 until plan.tileCount) {
            val tile = plan.window(index)
            for (y in tile.writeY until tile.writeY + tile.writeHeight) {
                for (x in tile.writeX until tile.writeX + tile.writeWidth) {
                    coverage[y * plan.sourceWidth + x]++
                }
            }
        }
        assertTrue(coverage.all { it == 1 })
    }

    @Test fun eachWritePartitionFitsInItsModelCore() {
        val plan = TilePlan(512, 384)
        for (index in 0 until plan.tileCount) {
            val tile = plan.window(index)
            assertTrue(tile.writeX >= tile.x)
            assertTrue(tile.writeY >= tile.y)
            assertTrue(tile.writeX + tile.writeWidth <= tile.x + plan.stride)
            assertTrue(tile.writeY + tile.writeHeight <= tile.y + plan.stride)
        }
    }
}
