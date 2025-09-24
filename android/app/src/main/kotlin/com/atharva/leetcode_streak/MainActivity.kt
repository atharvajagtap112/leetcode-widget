package com.atharva.leetcode_streak

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "leetcode_streak/widgets"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPinAppWidget" -> {
                        val awm = getSystemService(AppWidgetManager::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            awm.isRequestPinAppWidgetSupported
                        ) {
                            // Replace with your real provider class
                            val provider = ComponentName(this, LeetCodeWidgetProvider::class.java)

                            val successCallback = PendingIntent.getActivity(
                                this, 0,
                                Intent(this, MainActivity::class.java),
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            val ok = awm.requestPinAppWidget(provider, null, successCallback)
                            result.success(ok)
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}