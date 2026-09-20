package com.chengetai.chengetai

import com.chengetai.chengetai.callguard.CallGuardChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var callGuardChannel: CallGuardChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        callGuardChannel = CallGuardChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        callGuardChannel?.dispose()
        callGuardChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
