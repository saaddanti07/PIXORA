package com.pixora.app

import com.pixora.app.engine.EngineChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Hosts the on-device processing engine.
 *
 * Phase 01 shipped a bare activity. Phase 02 attaches the single MethodChannel
 * that exposes the LiteRT restoration engine and the classical enhancement path
 * to Dart — nothing else crosses the platform boundary.
 */
class MainActivity : FlutterActivity() {

    private var engineChannel: EngineChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        engineChannel = EngineChannel(this, flutterEngine.dartExecutor.binaryMessenger).also {
            it.attach()
        }
    }

    @Deprecated("Deprecated in Android, retained for Android 9 and below gallery permission")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (engineChannel?.onRequestPermissionsResult(requestCode, grantResults) != true) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        engineChannel?.detach()
        engineChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
