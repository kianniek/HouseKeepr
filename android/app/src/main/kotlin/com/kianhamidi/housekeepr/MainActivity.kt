package com.kianhamidi.housekeepr

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.app.Activity
import android.app.LocaleManager
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.LocaleList
import android.os.Looper
import android.provider.Settings
import android.view.View
import android.view.animation.DecelerateInterpolator
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "housekeepr/notification_intents"
    private val widgetChannelName = "housekeepr/widget_actions"
    private val healthConnectChannelName = "housekeepr/health_connect"
    private val deferredProgressChannelName = "housekeepr/deferred_component_progress"
    private val deferredActionsChannelName = "housekeepr/deferred_component_actions"
    private val shortcutsChannelName = "housekeepr/shortcuts"
    private val localeChannelName = "housekeepr/locale"
    private val shareIntentsChannelName = "housekeepr/share_intents"

    private lateinit var healthConnectBridge: HealthConnectBridge
    private var localeChannel: MethodChannel? = null
    private var shareIntentsChannel: MethodChannel? = null

    private var pendingAction: String? = null
    private var shouldOpenShopping = false
    private var shouldOpenMedications = false
    private var hasPendingWidgetConfig = false
    private var configuringAppWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var configuringSection: String? = null
    private var pendingSharePayload: Map<String, Any?>? = null
    private var launchedFromOnNewIntent = false
    private var isFlutterUiReady = false
    private var activeFlutterEngine: FlutterEngine? = null
    private var flutterUiDisplayListener: FlutterUiDisplayListener? = null
    private val splashTimeoutHandler = Handler(Looper.getMainLooper())
    private val splashTimeoutRunnable = Runnable { isFlutterUiReady = true }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        splashTimeoutHandler.postDelayed(splashTimeoutRunnable, 1500L)
        splashScreen.setKeepOnScreenCondition { !isFlutterUiReady }
        splashScreen.setOnExitAnimationListener { splashScreenView ->
            val animScale = Settings.Global.getFloat(
                contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f,
            )
            if (animScale == 0f) {
                splashScreenView.remove()
                return@setOnExitAnimationListener
            }

            runCatching {
                val containerView = splashScreenView.view
                val fadeOut = ObjectAnimator.ofFloat(containerView, View.ALPHA, 1f, 0f)
                val iconView = runCatching { splashScreenView.iconView }.getOrNull()
                val iconAnim = iconView?.let { icon ->
                    ObjectAnimator.ofPropertyValuesHolder(
                        icon,
                        PropertyValuesHolder.ofFloat(View.SCALE_X, 1f, 1.12f),
                        PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f, 1.12f),
                        PropertyValuesHolder.ofFloat(View.ALPHA, 1f, 0f),
                    )
                }
                AnimatorSet().apply {
                    if (iconAnim != null) {
                        playTogether(fadeOut, iconAnim)
                    } else {
                        play(fadeOut)
                    }
                    duration = 220L
                    interpolator = DecelerateInterpolator()
                    addListener(object : AnimatorListenerAdapter() {
                        override fun onAnimationEnd(animation: Animator) {
                            splashScreenView.remove()
                        }

                        override fun onAnimationCancel(animation: Animator) {
                            splashScreenView.remove()
                        }
                    })
                    start()
                }
            }.onFailure {
                splashScreenView.remove()
            }
        }
        healthConnectBridge = HealthConnectBridge(this)
        launchedFromOnNewIntent = false
        handleIntent(intent)
        WidgetPreviewHelper.updateAll(this)
        AppShortcutHelper.refreshDynamicShortcutIfPresent(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchedFromOnNewIntent = true
        handleIntent(intent)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        AppShortcutHelper.refreshDynamicShortcuts(this)
        refreshAllWidgets()
        WidgetPreviewHelper.updateAll(this)
        localeChannel?.invokeMethod("onSystemLocaleChanged", getCurrentAppLocaleLanguage())
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

        // Semantic Haptics Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HapticsBridge.CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            HapticsBridge.onMethodCall(this, call, result)
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

        // App Shortcuts Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shortcutsChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateNextWorkoutShortcut" -> {
                    val shortLabel = call.argument<String>("shortLabel")
                        ?.takeIf { it.isNotBlank() }
                        ?: "Next Workout"
                    val longLabel = call.argument<String>("longLabel")
                        ?.takeIf { it.isNotBlank() }
                        ?: shortLabel
                    val iconBytes = call.argument<ByteArray>("iconBytes")
                    val iconColor = call.argument<Number>("iconColor")?.toInt()
                    val backgroundColor = call.argument<Number>("backgroundColor")?.toInt()
                    AppShortcutHelper.updateNextWorkoutShortcut(
                        context = this,
                        shortLabel = shortLabel,
                        longLabel = longLabel,
                        iconBytes = iconBytes,
                        iconColor = iconColor,
                        backgroundColor = backgroundColor,
                    )
                    result.success(true)
                }
                "updateShortcutTheme" -> {
                    val themeMode = call.argument<String>("themeMode") ?: "system"
                    val lightPrimary = call.argument<Number>("lightPrimary")?.toInt()
                        ?: AppShortcutHelper.DEFAULT_LIGHT_PRIMARY
                    val lightBackground = call.argument<Number>("lightBackground")?.toInt()
                        ?: AppShortcutHelper.DEFAULT_LIGHT_BACKGROUND
                    val darkPrimary = call.argument<Number>("darkPrimary")?.toInt()
                        ?: AppShortcutHelper.DEFAULT_DARK_PRIMARY
                    val darkBackground = call.argument<Number>("darkBackground")?.toInt()
                        ?: AppShortcutHelper.DEFAULT_DARK_BACKGROUND
                    AppShortcutHelper.updateShortcutTheme(
                        context = this,
                        themeMode = themeMode,
                        lightPrimary = lightPrimary,
                        lightBackground = lightBackground,
                        darkPrimary = darkPrimary,
                        darkBackground = darkBackground,
                    )
                    result.success(true)
                }
                "clearNextWorkoutShortcut" -> {
                    AppShortcutHelper.clearNextWorkoutShortcut(this)
                    result.success(true)
                }
                "canPinShortcuts" -> {
                    result.success(AppShortcutHelper.canPinShortcuts(this))
                }
                "pinShortcut" -> {
                    val id = call.argument<String>("id")
                    val shortLabel = call.argument<String>("shortLabel")
                    val longLabel = call.argument<String>("longLabel") ?: shortLabel
                    val uri = call.argument<String>("uri")
                    val iconKey = call.argument<String>("iconKey") ?: "open_gym"
                    if (id.isNullOrBlank() || shortLabel.isNullOrBlank() || uri.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "id, shortLabel, and uri are required", null)
                    } else {
                        result.success(
                            AppShortcutHelper.pinShortcut(
                                context = this,
                                id = id,
                                shortLabel = shortLabel,
                                longLabel = longLabel ?: shortLabel,
                                uriString = uri,
                                iconKey = iconKey,
                            )
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Per-App Locale Channel
        localeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            localeChannelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppLocale" -> {
                        val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                        result.success(
                            mapOf(
                                "supported" to supported,
                                "languageCode" to getCurrentAppLocaleLanguage(),
                            )
                        )
                    }
                    "setAppLocale" -> {
                        val code = call.argument<String>("languageCode")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val localeManager = getSystemService(LocaleManager::class.java)
                            localeManager?.applicationLocales = if (code.isNullOrBlank()) {
                                LocaleList.getEmptyLocaleList()
                            } else {
                                LocaleList.forLanguageTags(code)
                            }
                        }
                        AppShortcutHelper.refreshDynamicShortcuts(this)
                        refreshAllWidgets()
                        WidgetPreviewHelper.updateAll(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Inbound Share Intents Channel
        shareIntentsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareIntentsChannelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingShare" -> {
                        result.success(pendingSharePayload)
                        pendingSharePayload = null
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // OpenGym Live Workout Notifications Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OpenGymLiveWorkoutBridge.METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            OpenGymLiveWorkoutBridge.onMethodCall(this, call, result)
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OpenGymLiveWorkoutBridge.EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                OpenGymLiveWorkoutBridge.setEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                OpenGymLiveWorkoutBridge.setEventSink(null)
            }
        })

        activeFlutterEngine = flutterEngine
        if (flutterEngine.renderer.isDisplayingFlutterUi) {
            isFlutterUiReady = true
            splashTimeoutHandler.removeCallbacks(splashTimeoutRunnable)
        } else {
            val listener = object : FlutterUiDisplayListener {
                override fun onFlutterUiDisplayed() {
                    isFlutterUiReady = true
                    splashTimeoutHandler.removeCallbacks(splashTimeoutRunnable)
                    flutterEngine.renderer.removeIsDisplayingFlutterUiListener(this)
                    if (flutterUiDisplayListener === this) {
                        flutterUiDisplayListener = null
                    }
                }

                override fun onFlutterUiNoLongerDisplayed() = Unit
            }
            flutterUiDisplayListener = listener
            flutterEngine.renderer.addIsDisplayingFlutterUiListener(listener)
        }
    }

    override fun onDestroy() {
        splashTimeoutHandler.removeCallbacks(splashTimeoutRunnable)
        flutterUiDisplayListener?.let { listener ->
            activeFlutterEngine?.renderer?.removeIsDisplayingFlutterUiListener(listener)
        }
        flutterUiDisplayListener = null
        activeFlutterEngine = null
        localeChannel?.setMethodCallHandler(null)
        localeChannel = null
        shareIntentsChannel?.setMethodCallHandler(null)
        shareIntentsChannel = null
        OpenGymLiveWorkoutBridge.setEventSink(null)
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

    private fun getCurrentAppLocaleLanguage(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return null
        val localeManager = getSystemService(LocaleManager::class.java) ?: return null
        val locales = localeManager.applicationLocales
        return if (!locales.isEmpty) locales[0]?.language else null
    }

    private fun refreshAllWidgets() {
        PillWidget.refresh(this)
        ShoppingListWidget.requestUpdate(this)
        CoffeeWidget.refresh(this)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
            if (!sharedText.isNullOrEmpty()) {
                val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim()
                val shortcutId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    intent.getStringExtra(Intent.EXTRA_SHORTCUT_ID)
                } else {
                    intent.getStringExtra("android.intent.extra.shortcut.ID")
                }
                val payload = mapOf<String, Any?>(
                    "text" to sharedText,
                    "subject" to subject,
                    "shortcutId" to shortcutId,
                )
                if (launchedFromOnNewIntent && shareIntentsChannel != null) {
                    shareIntentsChannel?.invokeMethod("onShareReceived", payload)
                } else {
                    pendingSharePayload = payload
                }
            }
        }

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
