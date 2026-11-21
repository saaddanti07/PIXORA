package com.pixora.app.engine

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * The only bridge between Flutter and the on-device engine.
 *
 * Design rules that come straight from the Phase 02 audit:
 *
 * * **paths, not pixels.** Bitmaps never cross the platform channel; a
 *   restoration result is a local file path.
 * * **one job at a time.** A second request while a job runs is rejected with a
 *   `busy` error instead of competing for the same interpreter.
 * * **progress is pushed**, one event per tile, so the UI can show a real ETA
 *   rather than a spinner pretending to know something.
 * * **cancellation is cooperative** and always cleans up: a cancelled job
 *   deletes its partial output.
 * * **no network, ever.** Nothing in this class can reach the network, and the
 *   application manifest does not request `INTERNET`.
 */
class EngineChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "pixora-engine").apply { priority = Thread.NORM_PRIORITY }
    }
    private val cancelRequested = AtomicBoolean(false)

    @Volatile
    private var activeJobId: String? = null

    private var restoration: SuperResolutionEngine? = null
    private val classical: ClassicalEnhancer by lazy { ClassicalEnhancer(activity) }

    fun attach() {
        channel.setMethodCallHandler(this)
    }

    fun detach() {
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
        restoration?.close()
        restoration = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> result.success(capabilities())
            "restore" -> startRestoration(call, result)
            "enhance" -> startEnhancement(call, result)
            "cancel" -> cancel(call, result)
            "saveToGallery" -> saveToGallery(call, result)
            "paths" -> result.success(
                mapOf(
                    "filesDir" to activity.filesDir.absolutePath,
                    "cacheDir" to activity.cacheDir.absolutePath,
                ),
            )
            "setKeepScreenOn" -> setKeepScreenOn(call, result)
            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------ commands

    private fun capabilities(): Map<String, Any?> {
        val snapshot = DeviceProbe.snapshot(activity)
        val engine = engine()
        return mapOf(
            "modelAvailable" to engine.isAvailable,
            "modelId" to engine.modelId,
            "backend" to "litert-cpu",
            "scale" to engine.scale,
            "tileSize" to engine.tileSize,
            "supportsGpuAcceleration" to false,
            "totalRamBytes" to snapshot.totalRamBytes,
            "availableRamBytes" to snapshot.availableRamBytes,
            "imageBudgetBytes" to snapshot.imageBudgetBytes,
            "cpuCores" to snapshot.cpuCores,
            "inferenceThreads" to snapshot.inferenceThreads,
            "isLowRamDevice" to snapshot.isLowRamDevice,
            "thermalStatus" to snapshot.thermalStatus,
            "busy" to (activeJobId != null),
        )
    }

    private fun startRestoration(call: MethodCall, result: MethodChannel.Result) {
        val jobId = call.argument<String>("jobId") ?: "restore"
        val sourcePath = call.argument<String>("sourcePath")
        val outputPath = call.argument<String>("outputPath")
        if (sourcePath == null || outputPath == null) {
            result.error("bad_request", "sourcePath and outputPath are required", null)
            return
        }
        if (!beginJob(jobId, result)) return

        val engine = engine()
        if (!engine.isAvailable) {
            finishJob()
            result.error(
                "unavailable",
                "The restoration model is not bundled in this build.",
                null,
            )
            return
        }

        val snapshot = DeviceProbe.snapshot(activity)
        val request = RestoreRequest(
            sourcePath = sourcePath,
            outputPath = outputPath,
            maxInputPixels = call.argument<Int>("maxInputPixels") ?: 750_000,
            maxOutputDimension = call.argument<Int>("maxOutputDimension") ?: 2048,
            halo = call.argument<Int>("halo") ?: 16,
            jpegQuality = call.argument<Int>("jpegQuality") ?: 95,
        )

        executor.execute {
            try {
                val outcome = engine.restore(
                    request = request,
                    threads = snapshot.inferenceThreads,
                    onProgress = { progress -> emitProgress(jobId, progress) },
                    isCancelled = { cancelRequested.get() },
                )
                mainHandler.post {
                    finishJob()
                    result.success(outcome.toMap())
                }
            } catch (cancelled: JobCancelledException) {
                mainHandler.post {
                    finishJob()
                    result.error("cancelled", "Restoration was cancelled.", null)
                }
            } catch (error: Throwable) {
                Log.e(TAG, "restoration failed", error)
                mainHandler.post {
                    finishJob()
                    result.error("failed", error.message ?: error.toString(), null)
                }
            }
        }
    }

    private fun startEnhancement(call: MethodCall, result: MethodChannel.Result) {
        val jobId = call.argument<String>("jobId") ?: "enhance"
        val sourcePath = call.argument<String>("sourcePath")
        val outputPath = call.argument<String>("outputPath")
        if (sourcePath == null || outputPath == null) {
            result.error("bad_request", "sourcePath and outputPath are required", null)
            return
        }
        if (!beginJob(jobId, result)) return

        val maxDimension = call.argument<Int>("maxOutputDimension") ?: 2048
        val quality = call.argument<Int>("jpegQuality") ?: 95

        executor.execute {
            try {
                val outcome = classical.enhance(
                    sourcePath = sourcePath,
                    outputPath = outputPath,
                    maxDimension = maxDimension,
                    jpegQuality = quality,
                    isCancelled = { cancelRequested.get() },
                )
                mainHandler.post {
                    finishJob()
                    result.success(outcome.toMap())
                }
            } catch (cancelled: JobCancelledException) {
                mainHandler.post {
                    finishJob()
                    result.error("cancelled", "Enhancement was cancelled.", null)
                }
            } catch (error: Throwable) {
                Log.e(TAG, "enhancement failed", error)
                mainHandler.post {
                    finishJob()
                    result.error("failed", error.message ?: error.toString(), null)
                }
            }
        }
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val jobId = call.argument<String>("jobId")
        val active = activeJobId
        if (active != null && (jobId == null || jobId == active)) {
            cancelRequested.set(true)
            result.success(true)
        } else {
            result.success(false)
        }
    }

    /** Android 10+ uses scoped MediaStore writes; Android 9 and below request
     * the narrowly capped legacy write permission only when the user exports. */
    private fun saveToGallery(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("sourcePath")
        val name = call.argument<String>("displayName")
        if (path.isNullOrBlank() || name.isNullOrBlank() || !File(path).isFile) {
            result.error("bad_request", "A valid output file and name are required.", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED) {
            if (pendingGallerySave != null) {
                result.error("busy", "A gallery permission request is already active.", null)
                return
            }
            pendingGallerySave = PendingGallerySave(path, name, result)
            activity.requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                GALLERY_PERMISSION_REQUEST,
            )
            return
        }
        writeGalleryEntry(path, name, result)
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != GALLERY_PERMISSION_REQUEST) return false
        val pending = pendingGallerySave
        pendingGallerySave = null
        if (pending == null) return true
        if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            pending.result.error("permission_denied", "Storage permission was denied.", null)
        } else {
            writeGalleryEntry(pending.sourcePath, pending.displayName, pending.result)
        }
        return true
    }

    private fun writeGalleryEntry(path: String, displayName: String, result: MethodChannel.Result) {
        executor.execute {
            var uri: Uri? = null
            try {
                val resolver = activity.contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
                        put(MediaStore.Images.Media.RELATIVE_PATH,
                            "${Environment.DIRECTORY_PICTURES}/PIXORA")
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    } else {
                        val legacyDirectory = File(
                            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                            "PIXORA",
                        )
                        check(legacyDirectory.exists() || legacyDirectory.mkdirs()) {
                            "Could not create Pictures/PIXORA"
                        }
                        val baseName = displayName.substringBeforeLast('.', displayName)
                        var destination = File(legacyDirectory, displayName)
                        var suffix = 1
                        while (destination.exists()) {
                            destination = File(legacyDirectory, "${baseName}_$suffix.jpg")
                            suffix++
                        }
                        put(MediaStore.Images.Media.DATA, destination.absolutePath)
                        put(MediaStore.Images.Media.TITLE, destination.nameWithoutExtension)
                    }
                }
                uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("MediaStore refused the image entry")
                FileInputStream(File(path)).use { input ->
                    resolver.openOutputStream(uri!!, "w")?.use { output ->
                        input.copyTo(output)
                        output.flush()
                    } ?: throw IllegalStateException("Could not open the gallery output stream")
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val published = ContentValues().apply {
                        put(MediaStore.Images.Media.IS_PENDING, 0)
                    }
                    check(resolver.update(uri!!, published, null, null) == 1) {
                        "Could not publish the image to the gallery"
                    }
                }
                mainHandler.post { result.success(uri.toString()) }
            } catch (error: Throwable) {
                uri?.let { try { activity.contentResolver.delete(it, null, null) } catch (_: Exception) {} }
                Log.e(TAG, "gallery export failed", error)
                mainHandler.post {
                    result.error("export_failed", error.message ?: "Gallery export failed.", null)
                }
            }
        }
    }

    private fun setKeepScreenOn(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        activity.runOnUiThread {
            if (enabled) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
        result.success(true)
    }

    // -------------------------------------------------------------- helpers

    private fun beginJob(jobId: String, result: MethodChannel.Result): Boolean {
        if (activeJobId != null) {
            result.error("busy", "Another job is already running.", null)
            return false
        }
        activeJobId = jobId
        cancelRequested.set(false)
        return true
    }

    private fun finishJob() {
        activeJobId = null
        cancelRequested.set(false)
    }

    private fun emitProgress(jobId: String, progress: RestoreProgress) {
        val payload = mapOf(
            "jobId" to jobId,
            "completedTiles" to progress.completedTiles,
            "totalTiles" to progress.totalTiles,
            "elapsedMs" to progress.elapsedMs,
            "etaMs" to progress.estimatedRemainingMs,
        )
        mainHandler.post {
            try {
                channel.invokeMethod("onProgress", payload)
            } catch (error: Exception) {
                Log.w(TAG, "progress event dropped", error)
            }
        }
    }

    private fun engine(): SuperResolutionEngine =
        restoration ?: SuperResolutionEngine(activity.applicationContext).also { restoration = it }

    private fun RestoreOutcome.toMap(): Map<String, Any?> = mapOf(
        "outputPath" to outputPath,
        "sourceWidth" to sourceWidth,
        "sourceHeight" to sourceHeight,
        "workingWidth" to workingWidth,
        "workingHeight" to workingHeight,
        "outputWidth" to outputWidth,
        "outputHeight" to outputHeight,
        "tiles" to tiles,
        "durationMs" to durationMs,
        "downscaled" to downscaled,
        "usedAi" to true,
    )

    private fun ClassicalEnhancer.Outcome.toMap(): Map<String, Any?> = mapOf(
        "outputPath" to outputPath,
        "sourceWidth" to sourceWidth,
        "sourceHeight" to sourceHeight,
        "workingWidth" to width,
        "workingHeight" to height,
        "outputWidth" to width,
        "outputHeight" to height,
        "tiles" to 0,
        "durationMs" to durationMs,
        "downscaled" to downscaled,
        "usedAi" to false,
    )

    private companion object {
        const val TAG = "PixoraEngineChannel"
        const val CHANNEL_NAME = "pixora/engine"
        const val GALLERY_PERMISSION_REQUEST = 4147
    }
}
