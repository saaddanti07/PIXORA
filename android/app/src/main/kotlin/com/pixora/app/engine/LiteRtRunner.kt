package com.pixora.app.engine

import android.content.Context
import android.util.Log
import org.tensorflow.lite.Interpreter
import java.io.Closeable
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

/**
 * Thin wrapper around the LiteRT interpreter for the bundled restoration model.
 *
 * Everything is allocated once and reused for every tile: a job runs hundreds of
 * tiles, and letting the garbage collector see a 3 MB float buffer per tile would
 * turn a slow job into a stuttering one.
 *
 * CPU execution with LiteRT's XNNPACK kernels is the trusted baseline. GPU and
 * NPU acceleration are deliberately not used in Phase 02: on the conservative
 * target device (PowerVR GE8320 / Mali-G52) a delegate has to prove both
 * numerical agreement and a real speed-up before it may be enabled, and that
 * proof requires the physical device.
 */
class LiteRtRunner private constructor(
    private val interpreter: Interpreter,
    val meta: ModelMeta,
) : Closeable {

    private val inputFloats = meta.inputPixels * CHANNELS
    private val outputFloats = meta.outputPixels * CHANNELS

    private val inputBuffer: ByteBuffer =
        ByteBuffer.allocateDirect(inputFloats * Float.SIZE_BYTES).order(ByteOrder.nativeOrder())
    private val outputBuffer: ByteBuffer =
        ByteBuffer.allocateDirect(outputFloats * Float.SIZE_BYTES).order(ByteOrder.nativeOrder())

    /** Reused across tiles; valid until the next call to [runTile]. */
    val output: FloatArray = FloatArray(outputFloats)

    /** Scratch buffer for one tile's input, in the model's layout. */
    val input: FloatArray = FloatArray(inputFloats)

    fun runTile() {
        inputBuffer.rewind()
        inputBuffer.asFloatBuffer().put(input)
        outputBuffer.rewind()
        interpreter.run(inputBuffer, outputBuffer)
        outputBuffer.rewind()
        outputBuffer.asFloatBuffer().get(output)
    }

    override fun close() {
        try {
            interpreter.close()
        } catch (error: Exception) {
            Log.w(TAG, "interpreter close failed", error)
        }
    }

    companion object {
        private const val TAG = "PixoraLiteRt"
        private const val CHANNELS = 3

        fun create(context: Context, modelAsset: String, meta: ModelMeta, threads: Int): LiteRtRunner {
            val options = Interpreter.Options().apply {
                setNumThreads(threads.coerceAtLeast(1))
            }
            val model = loadModel(context, modelAsset)
                ?: throw IllegalStateException("model asset $modelAsset is unreadable")
            val interpreter = Interpreter(model, options)
            interpreter.allocateTensors()

            val inputShape = interpreter.getInputTensor(0).shape()
            val outputShape = interpreter.getOutputTensor(0).shape()
            Log.i(TAG, "model loaded: input=${inputShape.joinToString("x")} " +
                "output=${outputShape.joinToString("x")} threads=$threads")
            return LiteRtRunner(interpreter, meta)
        }

        /**
         * Maps the model straight from the APK (no copy in RAM) when possible and
         * falls back to reading it into a direct buffer when the asset is
         * compressed or not file-backed.
         */
        private fun loadModel(context: Context, assetPath: String): ByteBuffer? {
            return try {
                context.assets.openFd(assetPath).use { descriptor ->
                    FileInputStream(descriptor.fileDescriptor).use { stream ->
                        stream.channel.map(
                            FileChannel.MapMode.READ_ONLY,
                            descriptor.startOffset,
                            descriptor.declaredLength,
                        )
                    }
                }
            } catch (error: Exception) {
                Log.w(TAG, "mmap failed for $assetPath, reading into memory", error)
                try {
                    val bytes = context.assets.open(assetPath).use { it.readBytes() }
                    val buffer = ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder())
                    buffer.put(bytes)
                    buffer.rewind()
                    buffer
                } catch (readError: Exception) {
                    Log.e(TAG, "model asset $assetPath could not be read", readError)
                    null
                }
            }
        }
    }
}
