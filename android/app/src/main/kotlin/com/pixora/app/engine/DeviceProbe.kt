package com.pixora.app.engine

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.PowerManager

/**
 * What the Smart AI Engine is allowed to know about the device.
 *
 * Values are read from the platform, never guessed: total/available RAM from
 * [ActivityManager.MemoryInfo], the CPU count from the runtime, the low-RAM flag
 * from the system itself and the thermal status where the API exposes it.
 */
data class DeviceSnapshot(
    val totalRamBytes: Long,
    val availableRamBytes: Long,
    val cpuCores: Int,
    val isLowRamDevice: Boolean,
    val thermalStatus: Int,
) {
    /** Threads to give the interpreter: all big cores is usually too many. */
    val inferenceThreads: Int
        get() = when {
            cpuCores >= 8 -> 4
            cpuCores >= 4 -> 3
            else -> 2
        }

    /** Conservative per-job ceiling for a single decoded bitmap. */
    val imageBudgetBytes: Long
        get() = (availableRamBytes * 0.25).toLong().coerceAtMost(160L * 1024 * 1024)
}

object DeviceProbe {
    fun snapshot(context: Context): DeviceSnapshot {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val thermal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            powerManager.currentThermalStatus
        } else {
            PowerManager.THERMAL_STATUS_NONE
        }
        return DeviceSnapshot(
            totalRamBytes = memoryInfo.totalMem,
            availableRamBytes = memoryInfo.availMem,
            cpuCores = Runtime.getRuntime().availableProcessors(),
            isLowRamDevice = activityManager.isLowRamDevice,
            thermalStatus = thermal,
        )
    }
}
