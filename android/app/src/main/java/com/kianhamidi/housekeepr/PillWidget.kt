package com.kianhamidi.housekeepr

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * 2x2 Android Home-Screen Widget for Medication Reminders.
 *
 * Visual layout:
 * - Top-left header: "Pillen" / "Pills", tapping opens Medication Reminders Tool page.
 * - Row 1: Sun icon + Switch component for Daytime / Morning doses.
 * - Row 2: Crescent moon icon + Switch component for Evening / Night doses.
 */
class PillWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE_SLOT = "com.kianhamidi.housekeepr.ACTION_TOGGLE_PILL_SLOT"
        const val EXTRA_SLOT = "extra_slot"
        const val EXTRA_CURRENT_STATE = "extra_current_state"

        private const val PREFS = "HomeWidgetPreferences"
        private const val DATA_KEY = "pill_widget_data"
        private const val PENDING_TOGGLES_KEY = "pill_pending_toggles"

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, PillWidget::class.java)
            val ids = manager.getAppWidgetIds(component)
            for (id in ids) {
                updateAppWidget(context, manager, id)
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.pill_widget)
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val rawJson = prefs.getString(DATA_KEY, null)

            var title = "Pillen"
            var hasMorning = false
            var morningTaken = false
            var hasEvening = false
            var eveningTaken = false

            if (!rawJson.isNullOrBlank()) {
                try {
                    val data = JSONObject(rawJson)
                    title = data.optString("title", "Pillen")
                    hasMorning = data.optBoolean("hasMorning", false)
                    morningTaken = data.optBoolean("morningTaken", false)
                    hasEvening = data.optBoolean("hasEvening", false)
                    eveningTaken = data.optBoolean("eveningTaken", false)
                } catch (_: Exception) {
                    // Fall back to defaults
                }
            }

            // Set Header
            views.setTextViewText(R.id.pill_widget_title, title)

            // Morning Switch: Set state & enabled status
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setCompoundButtonChecked(R.id.switch_morning, morningTaken)
            } else {
                views.setBoolean(R.id.switch_morning, "setChecked", morningTaken)
            }
            views.setBoolean(R.id.switch_morning, "setEnabled", hasMorning)

            val morningToggleIntent = Intent(context, PillWidget::class.java).apply {
                action = ACTION_TOGGLE_SLOT
                putExtra(EXTRA_SLOT, "morning")
                putExtra(EXTRA_CURRENT_STATE, morningTaken)
            }
            val morningPendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId * 10 + 1,
                morningToggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setOnCheckedChangeResponse(
                    R.id.switch_morning,
                    RemoteViews.RemoteResponse.fromPendingIntent(morningPendingIntent)
                )
            } else {
                views.setOnClickPendingIntent(R.id.switch_morning, morningPendingIntent)
            }

            // Evening Switch: Set state & enabled status
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setCompoundButtonChecked(R.id.switch_evening, eveningTaken)
            } else {
                views.setBoolean(R.id.switch_evening, "setChecked", eveningTaken)
            }
            views.setBoolean(R.id.switch_evening, "setEnabled", hasEvening)

            val eveningToggleIntent = Intent(context, PillWidget::class.java).apply {
                action = ACTION_TOGGLE_SLOT
                putExtra(EXTRA_SLOT, "evening")
                putExtra(EXTRA_CURRENT_STATE, eveningTaken)
            }
            val eveningPendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId * 10 + 2,
                eveningToggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setOnCheckedChangeResponse(
                    R.id.switch_evening,
                    RemoteViews.RemoteResponse.fromPendingIntent(eveningPendingIntent)
                )
            } else {
                views.setOnClickPendingIntent(R.id.switch_evening, eveningPendingIntent)
            }

            // Tapping header / card background opens the Medication Reminders Tool
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("housekeepr://medications")
                putExtra("open_medications", true)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 3,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.pill_widget_title, openAppPendingIntent)
            views.setOnClickPendingIntent(R.id.pill_widget_root, openAppPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_TOGGLE_SLOT) {
            val slot = intent.getStringExtra(EXTRA_SLOT) ?: return
            val wasTaken = intent.getBooleanExtra(EXTRA_CURRENT_STATE, false)
            // On Android 12+, RemoteViews sends the new checked state via RemoteViews.EXTRA_CHECKED
            val newTaken = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && intent.hasExtra(RemoteViews.EXTRA_CHECKED)) {
                intent.getBooleanExtra(RemoteViews.EXTRA_CHECKED, !wasTaken)
            } else {
                !wasTaken
            }

            // 1. Instantly update SharedPreferences for local responsiveness
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val rawJson = prefs.getString(DATA_KEY, null)
            if (!rawJson.isNullOrBlank()) {
                try {
                    val data = JSONObject(rawJson)
                    if (slot == "morning") {
                        data.put("morningTaken", newTaken)
                    } else if (slot == "evening") {
                        data.put("eveningTaken", newTaken)
                    }
                    prefs.edit().putString(DATA_KEY, data.toString()).apply()
                } catch (_: Exception) {}
            }

            // 2. Queue pending toggle action for Flutter to reconcile
            val existingQueue = prefs.getString(PENDING_TOGGLES_KEY, "") ?: ""
            val entry = "$slot:$newTaken"
            val newQueue = if (existingQueue.isEmpty()) entry else "$existingQueue,$entry"
            prefs.edit().putString(PENDING_TOGGLES_KEY, newQueue).apply()

            // 3. Immediately refresh widget views
            refresh(context)
        }
    }
}
