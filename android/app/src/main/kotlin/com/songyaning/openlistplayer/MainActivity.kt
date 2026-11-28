package com.songyaning.openlistplayer

import android.content.Intent
// audio_service 要求 Activity 继承 AudioServiceActivity（提供共享 FlutterEngine）
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "olp/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAppInstalled" -> {
                        val pkg = call.argument<String>("packageName")
                        if (pkg.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            val installed = packageManager.getLaunchIntentForPackage(pkg) != null
                            result.success(installed)
                        }
                    }
                    "launchApp" -> {
                        val pkg = call.argument<String>("packageName")
                        if (pkg.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            try {
                                val intent = packageManager.getLaunchIntentForPackage(pkg)
                                if (intent != null) {
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                    result.success(true)
                                } else {
                                    result.success(false)
                                }
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
