package com.kianhamidi.housekeepr

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "housekeepr/notification_intents"
    private val widgetChannelName = "housekeepr/widget_actions"
    private val healthConnectChannelName = "housekeepr/health_connect"
    private val deferredProgressChannelName = "housekeepr/deferred_component_progress"
    private val deferredActionsChannelName = "housekeepr/deferred_component_actions"

    private lateinit var healthConnectBridge: HealthConnectBridge

    private var pendingAction: String? = null
    private var shouldOpenShopping = false
    private var shouldOpenMedications = false
    private var hasPendingWidgetConfig = false
    private var configuringAppWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var configuringSection: String? = null
    private var launchedFromOnNewIntent = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        healthConnectBridge = HealthConnectBridge(this)
        launchedFromOnNewIntent = false
        handleIntent(intent)
        WidgetPreviewHelper.updateAll(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchedFromOnNewIntent = true
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
            when (call.method) {
                "getWidgetAction" -> {
                    if (shouldOpenShopping) {
                        result.success("open_shopping")
                        shouldOpenShopping = false
                    } else if (shouldOpenMedications) {
                        result.success("open_medications")
                        shouldOpenMedications = false
                    } else {
                        result.success(null)
                    }
                }
                "getWidgetConfigContext" -> {
                    if (hasPendingWidgetConfig &&
                        configuringAppWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID
                    ) {
                        hasPendingWidgetConfig = false
                        result.success(
                            mapOf(
                                "isWidgetConfig" to true,
                                "appWidgetId" to configuringAppWidgetId,
                                "section" to configuringSection,
                            )
                        )
                    } else {
                        result.success(null)
                    }
                }
                "finishWidgetConfiguration" -> {
                    val requestedId = call.argument<Int>("appWidgetId")
                    val targetId = if (requestedId != null &&
                        requestedId != AppWidgetManager.INVALID_APPWIDGET_ID
                    ) {
                        requestedId
                    } else {
                        configuringAppWidgetId
                    }

                    if (targetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                        refreshAppWidgetById(targetId, sendBroadcast = true)
                        setResult(
                            Activity.RESULT_OK,
                            Intent().putExtra(
                                AppWidgetManager.EXTRA_APPWIDGET_ID,
                                targetId,
                            ),
                        )
                    }

                    hasPendingWidgetConfig = false
                    configuringAppWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
                    configuringSection = null
                    result.success(true)

                    if (launchedFromOnNewIntent && !isTaskRoot) {
                        moveTaskToBack(true)
                    } else {
                        finish()
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Health Connect Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            healthConnectChannelName
        ).setMethodCallHandler { call, result ->
            healthConnectBridge.onMethodCall(call, result)
        }

        // Deferred Component Progress & Actions Channels
        val deferredManager = FlutterInjector.instance()
            .deferredComponentManager() as? FeatureDeliveryDeferredComponentManager
        deferredManager?.setActivity(this)
        val engineJni = runCatching {
            val field = FlutterEngine::class.java.getDeclaredField("flutterJNI")
            field.isAccessible = true
            field.get(flutterEngine) as? FlutterJNI
        }.getOrNull()
        if (engineJni != null) {
            deferredManager?.setJNI(engineJni)
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deferredProgressChannelName
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                deferredManager?.setProgressSink(events)
            }

            override fun onCancel(arguments: Any?) {
                deferredManager?.setProgressSink(null)
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deferredActionsChannelName
        ).setMethodCallHandler { call, result ->
            val moduleName = call.argument<String>("moduleName")
            when (call.method) {
                "getInstallState" -> {
                    if (moduleName.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "moduleName is required", null)
                    } else {
                        result.success(deferredManager?.getLatestProgress(moduleName))
                    }
                }
                "cancelInstall" -> {
                    if (moduleName.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "moduleName is required", null)
                    } else {
                        result.success(deferredManager?.cancelInstall(moduleName) ?: false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        val deferredManager = FlutterInjector.instance()
            .deferredComponentManager() as? FeatureDeliveryDeferredComponentManager
        deferredManager?.setActivity(null)
        deferredManager?.setProgressSink(null)
        super.onDestroy()
    }

    private fun refreshAppWidgetById(
        appWidgetId: Int,
        sendBroadcast: Boolean = false,
    ) {
        val manager = AppWidgetManager.getInstance(this)
        val provider = manager.getAppWidgetInfo(appWidgetId)?.provider
        val className = provider?.className ?: ""

        when {
            className.endsWith("PillWidget") -> {
                PillWidget.updateAppWidget(this, manager, appWidgetId)
            }
            className.endsWith("ShoppingListWidget") -> {
                manager.notifyAppWidgetViewDataChanged(
                    intArrayOf(appWidgetId),
                    R.id.widget_list,
                )
                updateAppWidget(this, manager, appWidgetId)
            }
            className.endsWith("CoffeeWidget") -> {
                CoffeeWidget.updateAppWidget(this, manager, appWidgetId)
            }
        }

        if (sendBroadcast && provider != null) {
            val updateIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                component = provider
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
            }
            sendBroadcast(updateIntent)
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
        if (intent?.getBooleanExtra("open_medications", false) == true) {
            shouldOpenMedications = true
        }

        if (intent?.action == AppWidgetManager.ACTION_APPWIDGET_CONFIGURE) {
            setResult(Activity.RESULT_CANCELED)
            val appWidgetId = intent.extras?.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

            if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
                finish()
                return
            }

            // Android skips onUpdate() when android:configure is declared, so
            // render the initial RemoteViews immediately.
            refreshAppWidgetById(appWidgetId, sendBroadcast = false)

            val providerClass = AppWidgetManager.getInstance(this)
                .getAppWidgetInfo(appWidgetId)
                ?.provider
                ?.className
                ?: ""

            configuringSection = when {
                providerClass.endsWith("PillWidget") -> "pill"
                providerClass.endsWith("ShoppingListWidget") -> "shopping"
                providerClass.endsWith("CoffeeWidget") -> "coffee"
                else -> null
            }
            configuringAppWidgetId = appWidgetId
            hasPendingWidgetConfig = true
        }
    }
}
