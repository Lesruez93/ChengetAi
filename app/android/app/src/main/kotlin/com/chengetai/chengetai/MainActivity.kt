package com.chengetai.chengetai

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var protectionChannel: ProtectionChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Created up front rather than lazily so the notification channels exist
        // before screening ever fires — a warning posted to a channel that
        // doesn't exist yet is dropped on API 26+.
        ProtectionAlerts.ensureChannels(this)

        val channel = ProtectionChannel(this)
        protectionChannel = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ProtectionChannel.CHANNEL)
            .setMethodCallHandler(channel)
    }

    // FlutterActivity extends the platform Activity, not ComponentActivity, so
    // the AndroidX result APIs aren't available here — these two overrides are
    // how the role and permission prompts get their answers back to Dart.

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (protectionChannel?.onActivityResult(requestCode) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (protectionChannel?.onRequestPermissionsResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
