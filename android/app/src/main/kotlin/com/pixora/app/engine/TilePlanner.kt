package com.pixora.app.engine

/** A fixed model input window and the non-overlapping output area it owns. */
data class TileWindow(
    val column: Int,
    val row: Int,
    /** Input window's core origin in working-image coordinates. */
    val x: Int,
    val y: Int,
    val width: Int,
    val height: Int,
    /** Output core partition in working-image coordinates. */
    val writeX: Int,
    val writeY: Int,
    val writeWidth: Int,
    val writeHeight: Int,
)

/** Pure tiling arithmetic, testable on a plain JVM. */
class TilePlan(
    val sourceWidth: Int,
    val sourceHeight: Int,
    val tileSize: Int = 128,
    val halo: Int = 16,
) {
    init {
        require(tileSize > 0)
        require(halo >= 0)
        require(halo * 2 < tileSize)
        require(sourceWidth > 0 && sourceHeight > 0)
    }

    /** Largest output core a tile can contribute after its context halo. */
    val stride: Int = tileSize - 2 * halo
    val paddedWidth: Int = sourceWidth + 2 * halo
    val paddedHeight: Int = sourceHeight + 2 * halo
    val columns: Int = ceilDiv(sourceWidth, stride)
    val rows: Int = ceilDiv(sourceHeight, stride)
    val tileCount: Int get() = columns * rows

    private val xStarts: List<Int> = starts(sourceWidth, columns)
    private val yStarts: List<Int> = starts(sourceHeight, rows)

    fun window(index: Int): TileWindow {
        require(index in 0 until tileCount) { "tile index $index out of range" }
        val column = index % columns
        val row = index / columns
        val x = xStarts[column]
        val y = yStarts[row]
        val writeX = partitionStart(xStarts, column)
        val writeY = partitionStart(yStarts, row)
        val writeRight = partitionEnd(xStarts, column, sourceWidth)
        val writeBottom = partitionEnd(yStarts, row, sourceHeight)
        return TileWindow(
            column = column,
            row = row,
            x = x,
            y = y,
            width = minOf(stride, sourceWidth - x),
            height = minOf(stride, sourceHeight - y),
            writeX = writeX,
            writeY = writeY,
            writeWidth = writeRight - writeX,
            writeHeight = writeBottom - writeY,
        )
    }

    /** Coordinates in the mirror-padded source for this fixed-size model read. */
    fun readBounds(window: TileWindow): IntArray =
        intArrayOf(window.x, window.y, window.x + tileSize, window.y + tileSize)

    /**
     * For the last tile, shift its core back so it reaches the image edge.
     * Adjacent cores may overlap; the midpoint of that overlap is a unique,
     * deterministic write boundary. Thus all pixels are written exactly once.
     */
    private fun starts(length: Int, count: Int): List<Int> =
        List(count) { index -> (index * stride).coerceAtMost((length - stride).coerceAtLeast(0)) }

    private fun partitionStart(starts: List<Int>, index: Int): Int =
        if (index == 0) 0 else (starts[index - 1] + stride + starts[index]) / 2

    private fun partitionEnd(starts: List<Int>, index: Int, length: Int): Int =
        if (index == starts.lastIndex) length
        else (starts[index] + stride + starts[index + 1]) / 2

    private fun ceilDiv(value: Int, divisor: Int): Int =
        ((value + divisor - 1) / divisor).coerceAtLeast(1)
}

class JobCancelledException(message: String = "cancelled") : Exception(message)
