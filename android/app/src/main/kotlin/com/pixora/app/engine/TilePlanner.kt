package com.pixora.app.engine

/**
 * Pure tiling arithmetic for the restoration engine.
 *
 * The LiteRT model takes a fixed 128x128 window and produces a 512x512 window.
 * A large photograph cannot be fed in whole (the activations would not fit in
 * RAM), so it is split into square tiles. To stop the network from producing
 * visible seams at tile borders, every tile is surrounded by a [halo] of extra
 * context that is computed but then discarded.
 *
 * This class deliberately has no Android dependencies: it is the part of the
 * engine that can be unit tested on a plain JVM, and it is where the
 * off-by-one bugs live if anywhere.
 */
data class TileWindow(
    val column: Int,
    val row: Int,
    val x: Int,
    val y: Int,
    val width: Int,
    val height: Int,
)

class TilePlan(
    val sourceWidth: Int,
    val sourceHeight: Int,
    val tileSize: Int = 128,
    val halo: Int = 16,
) {
    init {
        require(tileSize > 0) { "tileSize must be positive" }
        require(halo >= 0) { "halo must not be negative" }
        require(halo * 2 < tileSize) { "halo must be smaller than half a tile" }
        require(sourceWidth > 0 && sourceHeight > 0) { "source must not be empty" }
    }

    /** Pixels a tile contributes to the result, i.e. the tile minus its halo. */
    val stride: Int = tileSize - 2 * halo

    /** Size of the mirror-padded source the tiles are read from. */
    val paddedWidth: Int = sourceWidth + 2 * halo
    val paddedHeight: Int = sourceHeight + 2 * halo

    val columns: Int = ceilDiv(sourceWidth, stride)
    val rows: Int = ceilDiv(sourceHeight, stride)
    val tileCount: Int get() = columns * rows

    fun window(index: Int): TileWindow {
        require(index in 0 until tileCount) { "tile index $index out of range" }
        val column = index % columns
        val row = index / columns
        // The last tile in a row/column is pulled back so it stays fully inside
        // the image: it then overlaps its predecessor instead of being short.
        val x = (column * stride).coerceAtMost((sourceWidth - stride).coerceAtLeast(0))
        val y = (row * stride).coerceAtMost((sourceHeight - stride).coerceAtLeast(0))
        return TileWindow(
            column = column,
            row = row,
            x = x,
            y = y,
            width = minOf(stride, sourceWidth - x),
            height = minOf(stride, sourceHeight - y),
        )
    }

    /** Inclusive-exclusive bounds of the padded region read for a tile. */
    fun readBounds(window: TileWindow): IntArray =
        intArrayOf(window.x, window.y, window.x + tileSize, window.y + tileSize)

    private companion object {
        fun ceilDiv(value: Int, divisor: Int): Int =
            ((value + divisor - 1) / divisor).coerceAtLeast(1)
    }
}

/** Thrown when the user cancels a job; never escapes the channel. */
class JobCancelledException(message: String = "cancelled") : Exception(message)
