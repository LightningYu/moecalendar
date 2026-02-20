package com.lightningyu.moecalendar

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.lightningyu.moecalendar/import"
    private var pendingJson: String? = null

    /**
     * 当应用通过分享启动时，返回 null 让 Flutter 使用
     * go_router 配置的 initialLocation，而不是把 intent 内容
     * 当作路由传入 go_router。
     */
    override fun getInitialRoute(): String? {
        val action = intent?.action
        if (action == Intent.ACTION_SEND) {
            return null
        }
        return super.getInitialRoute()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialJson" -> {
                    result.success(pendingJson)
                    pendingJson = null
                }
                else -> result.notImplemented()
            }
        }

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        if (intent.action == Intent.ACTION_SEND) {
            // 处理分享过来的 JSON 文件或文本
            if (intent.type == "application/json") {
                val uri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
                if (uri != null) {
                    try {
                        val inputStream = contentResolver.openInputStream(uri)
                        val json = inputStream?.bufferedReader()?.readText()
                        inputStream?.close()
                        if (json != null && json.isNotEmpty()) {
                            pendingJson = json
                            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                                MethodChannel(messenger, CHANNEL).invokeMethod("onJsonReceived", json)
                            }
                        }
                    } catch (e: Exception) {
                        // 忽略
                    }
                }
            } else if (intent.type == "text/plain") {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (text != null && text.isNotEmpty()) {
                    pendingJson = text
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, CHANNEL).invokeMethod("onJsonReceived", text)
                    }
                }
            }
        }
    }
}
