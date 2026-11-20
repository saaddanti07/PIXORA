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

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        engineChannel?.detach()
        engineChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
