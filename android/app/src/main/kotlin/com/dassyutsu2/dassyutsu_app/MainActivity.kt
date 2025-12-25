package com.dassyutsu2.dassyutsu_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.dassyutsu2.dassyutsu_app/camera_foreground_service"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    try {
                        val intent = Intent(this, CameraForegroundService::class.java)
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", "Foreground Serviceの開始に失敗しました: ${e.message}", null)
                    }
                }
                "stopForegroundService" -> {
                    try {
                        val intent = Intent(this, CameraForegroundService::class.java)
                        stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", "Foreground Serviceの停止に失敗しました: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

