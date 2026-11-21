package com.kianhamidi.housekeepr

import android.app.Activity
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object OpenGymLiveWorkoutBridge {
    const val METHOD_CHANNEL = "housekeepr/opengym_live"
    const val EVENT_CHANNEL = "housekeepr/opengym_live_events"

    @Volatile
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun emitAction(context: Context, action: String, deltaSeconds: Int? = null) {
        val appContext = context.applicationContext
        val payload = mutableMapOf<String, Any>(
            "action" to action,
            "timestampMs" to System.currentTimeMillis(),
        )
        if (deltaSeconds != null) {
            payload["deltaSeconds"] = deltaSeconds
        }

        if (eventSink != null) {
            mainHandler.post {
                val activeSink = eventSink
                if (activeSink != null) {
                    activeSink.success(payload)
                } else {
                    OpenGymLiveWorkoutStateStore.enqueuePendingAction(appContext, payload)
                }
            }
        } else {
            OpenGymLiveWorkoutStateStore.enqueuePendingAction(appContext, payload)
        }
    }

    fun onMethodCall(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateLiveWorkout" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("INVALID_ARGS", "Expected workout state map", null)
                    return
                }
                val state = OpenGymLiveWorkoutState.fromMap(args)
                OpenGymLiveWorkoutStateStore.saveState(context, state)
                OpenGymLiveWorkoutService.startOrUpdate(context, state)
                result.success(true)
            }
            "stopLiveWorkout" -> {
                OpenGymLiveWorkoutStateStore.clearState(context)
                OpenGymLiveWorkoutStateStore.clearPendingActions(context)
                OpenGymLiveWorkoutService.stop(context)
                result.success(true)
            }
            "consumePendingActions" -> {
                result.success(OpenGymLiveWorkoutStateStore.consumePendingActions(context))
            }
            "getLiveUpdateStatus" -> {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val supported = Build.VERSION.SDK_INT >= 36
                val canPostPromoted = if (supported) {
                    runCatching { nm.canPostPromotedNotifications() }.getOrDefault(false)
                } else {
                    false
                }
                val notificationsEnabled =
                    runCatching { NotificationManagerCompat.from(context).areNotificationsEnabled() }
                        .getOrDefault(true)
                result.success(
                    mapOf(
                        "supported" to supported,
                        "canPostPromotedNotifications" to canPostPromoted,
                        "notificationsEnabled" to notificationsEnabled,
                    )
                )
            }
            "openLiveUpdateSettings" -> {
                openLiveUpdateSettings(context)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun openLiveUpdateSettings(context: Context) {
        val intents = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= 36) {
            intents.add(
                Intent(Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                }
            )
        }
        intents.add(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            }
        )
        intents.add(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", context.packageName, null),
            )
        )

        for (intent in intents) {
            if (context !is Activity) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                context.startActivity(intent)
                return
            } catch (_: ActivityNotFoundException) {
                // Try fallback intent
            } catch (_: SecurityException) {
                // Try fallback intent
            }
        }
    }
}
