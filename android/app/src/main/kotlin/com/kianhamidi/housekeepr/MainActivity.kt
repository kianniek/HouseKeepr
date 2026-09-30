package com.kianhamidi.housekeepr

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "housekeepr/notification_intents"
    private val widgetChannelName = "housekeepr/widget_actions"
    
    private var pendingAction: String? = null
    private var shouldOpenShopping = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Notification Actions Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            if (call.method == "getNotificationAction") {
                result.success(pendingAction)
                pendingAction = null
            } else {
                result.notImplemented()
            }
        }

        // Widget Actions Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            widgetChannelName
        ).setMethodCallHandler { call, result ->
            if (call.method == "getWidgetAction") {
                if (shouldOpenShopping) {
                    result.success("open_shopping")
                    shouldOpenShopping = false
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun handleIntent(intent: Intent?) {
        val action = intent?.getStringExtra("notification_action")
        if (!action.isNullOrBlank()) {
            pendingAction = action
        }

        if (intent?.getBooleanExtra("open_shopping", false) == true) {
            shouldOpenShopping = true
        }
    }
}
