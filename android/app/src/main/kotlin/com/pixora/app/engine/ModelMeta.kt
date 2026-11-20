package com.pixora.app.engine

import android.content.Context
import org.json.JSONObject

/**
 * Tensor contract of the bundled LiteRT model, read from the
 * `<model>.tflite.meta.json` file that `tool/convert_model.py` writes next to the
 * model.
 *
 * The engine never assumes a layout: the conversion pipeline reports what it
 * actually produced (LiteRT keeps the ONNX/NCHW layout of the graph's output for
 * this network), and the runtime adapts. If the metadata is missing or
 * unreadable the engine reports the model as unavailable instead of guessing.
 */
data class ModelMeta(
    val modelId: String,
    val inputWidth: Int,
    val inputHeight: Int,
    val inputLayout: String,
    val outputWidth: Int,
    val outputHeight: Int,
    val outputLayout: String,
    val scale: Int,
    val valueRange: ClosedFloatingPointRange<Float>,
) {
    val inputPixels: Int get() = inputWidth * inputHeight
    val outputPixels: Int get() = outputWidth * outputHeight

    companion object {
        const val DEFAULT_MODEL_ASSET = "models/realesr_general_x4v3_fp32.tflite"

        fun metaAssetFor(modelAsset: String): String = "$modelAsset.meta.json"

        /** Returns null when the file is absent — the caller then disables AI. */
        fun load(context: Context, assetPath: String): ModelMeta? = try {
            context.assets.open(assetPath).use { stream ->
                parse(JSONObject(stream.bufferedReader().use { it.readText() }))
            }
        } catch (_: Exception) {
            null
        }

        internal fun parse(json: JSONObject): ModelMeta {
            val input = json.getJSONObject("input")
            val output = json.getJSONObject("output")
            val inputShape = input.getJSONArray("shape")
            val outputShape = output.getJSONArray("shape")
            val inputLayout = input.optString("layout", "NHWC")
            val outputLayout = output.optString("layout", "NHWC")
            val range = input.optJSONArray("valueRange")
            val inputHeight = if (inputLayout == "NCHW") inputShape.getInt(2) else inputShape.getInt(1)
            val inputWidth = if (inputLayout == "NCHW") inputShape.getInt(3) else inputShape.getInt(2)
            val outputHeight = if (outputLayout == "NCHW") outputShape.getInt(2) else outputShape.getInt(1)
            val outputWidth = if (outputLayout == "NCHW") outputShape.getInt(3) else outputShape.getInt(2)
            return ModelMeta(
                modelId = json.optString("modelId", "real_esrgan_general_x4v3"),
                inputWidth = inputWidth,
                inputHeight = inputHeight,
                inputLayout = inputLayout,
                outputWidth = outputWidth,
                outputHeight = outputHeight,
                outputLayout = outputLayout,
                scale = json.optInt("scale", 4),
                valueRange = (range?.getDouble(0)?.toFloat() ?: 0f)..
                    (range?.getDouble(1)?.toFloat() ?: 1f),
            )
        }
    }
}
