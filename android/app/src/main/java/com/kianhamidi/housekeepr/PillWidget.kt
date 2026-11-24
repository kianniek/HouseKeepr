package com.kianhamidi.housekeepr

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
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
        const val ACTION_MIDNIGHT_RESET = "com.kianhamidi.housekeepr.ACTION_MIDNIGHT_RESET"
        const val EXTRA_SLOT = "extra_slot"
        const val EXTRA_CURRENT_STATE = "extra_current_state"

        private const val PREFS = "HomeWidgetPreferences"
        private const val DATA_KEY = "pill_widget_data"
        private const val PENDING_TOGGLES_KEY = "pill_pending_toggles"
        private const val HIDE_UNUSED_KEY = "pill_hide_unused_toggles_v1"
        private const val TITLE_KEY = "pill_widget_title_v1"
        private const val SHOW_DOSE_COUNT_KEY = "pill_show_dose_count_v1"

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, PillWidget::class.java)
            val ids = manager.getAppWidgetIds(component)
            for (id in ids) {
                updateAppWidget(context, manager, id)
            }
            WidgetPreviewHelper.updatePillPreview(context)
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val v1x1 = buildPillRemoteViews(
                    context = context,
                    appWidgetId = appWidgetId,
                    isCompactHeight = true,
                    isCompactWidth = true,
                    isHeightTooShortForTitle = true,
                )
                val vNx1Short = buildPillRemoteViews(
                    context = context,
                    appWidgetId = appWidgetId,
                    isCompactHeight = true,
                    isCompactWidth = false,
                    isHeightTooShortForTitle = true,
                )
                val vNx1 = buildPillRemoteViews(
                    context = context,
                    appWidgetId = appWidgetId,
                    isCompactHeight = true,
                    isCompactWidth = false,
                    isHeightTooShortForTitle = false,
                )
                val v1xN = buildPillRemoteViews(
                    context = context,
                    appWidgetId = appWidgetId,
                    isCompactHeight = false,
                    isCompactWidth = true,
                    isHeightTooShortForTitle = false,
                )
                val vFull = buildPillRemoteViews(
                    context = context,
                    appWidgetId = appWidgetId,
                    isCompactHeight = false,
                    isCompactWidth = false,
                    isHeightTooShortForTitle = false,
                )
                val responsive = RemoteViews(
                    mapOf(
                        SizeF(50f, 50f) to v1x1,
                        SizeF(102f, 50f) to vNx1Short,
                        SizeF(102f, 80f) to vNx1,
                        SizeF(50f, 110f) to v1xN,
                        SizeF(102f, 110f) to vFull,
                    )
                )
                appWidgetManager.updateAppWidget(appWidgetId, responsive)
                return
            }

            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            val isCompactHeight = minHeight in 1 until 102
            val isCompactWidth = minWidth in 1 until 102
            val isHeightTooShortForTitle = minHeight in 1 until 80
            val views = buildPillRemoteViews(
                context = context,
                appWidgetId = appWidgetId,
                isCompactHeight = isCompactHeight,
                isCompactWidth = isCompactWidth,
                isHeightTooShortForTitle = isHeightTooShortForTitle,
            )
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun buildPillRemoteViews(
            context: Context,
            appWidgetId: Int,
            isCompactHeight: Boolean,
            isCompactWidth: Boolean,
            isHeightTooShortForTitle: Boolean,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.pill_widget)
            val palette = WidgetThemeHelper.resolve(context)
            WidgetThemeHelper.applyRoundedBackground(views, R.id.pill_widget_root, palette.surface)
            views.setTextColor(R.id.pill_widget_title, palette.onSurface)
            views.setTextColor(R.id.pill_empty_text, palette.onSurfaceVariant)
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val widgetData = PillWidgetScheduler.resolveTodayData(context)

            val defaultTitle = context.getString(R.string.pills)
            val title = widgetData.optString("title", defaultTitle)
            val hasMorning = widgetData.optBoolean("hasMorning", false)
            val morningTaken = widgetData.optBoolean("morningTaken", false)
            val hasEvening = widgetData.optBoolean("hasEvening", false)
            val eveningTaken = widgetData.optBoolean("eveningTaken", false)
            val morningCount = widgetData.optInt("morningCount", 0)
            val eveningCount = widgetData.optInt("eveningCount", 0)

            val hideUnused = prefs.getBoolean(HIDE_UNUSED_KEY, false)
            val customTitle = prefs.getString(TITLE_KEY, null)
            val resolvedTitle = customTitle ?: title
            val showDoseCount = prefs.getBoolean(SHOW_DOSE_COUNT_KEY, false)

            // Set Header: hide only when blank, 1-cell wide, or height isn't enough for title + 1 row
            if (resolvedTitle.isBlank() || isCompactWidth || isHeightTooShortForTitle) {
                views.setViewVisibility(R.id.pill_widget_title, View.GONE)
            } else {
                views.setViewVisibility(R.id.pill_widget_title, View.VISIBLE)
                views.setTextViewText(R.id.pill_widget_title, resolvedTitle)
            }

            val effectiveHideUnused = hideUnused || isCompactHeight
            val canShowMorning = !effectiveHideUnused || hasMorning
            val canShowEvening = !effectiveHideUnused || hasEvening
            val showMorningRow = if (isCompactHeight) {
                canShowMorning && (!morningTaken || !canShowEvening)
            } else {
                canShowMorning
            }
            val showEveningRow = if (isCompactHeight) {
                canShowEvening && !showMorningRow
            } else {
                canShowEvening
            }
            views.setViewVisibility(
                R.id.row_morning,
                if (showMorningRow) View.VISIBLE else View.GONE
            )
            views.setViewVisibility(
                R.id.row_evening,
                if (showEveningRow) View.VISIBLE else View.GONE
            )
            if (!showMorningRow && !showEveningRow) {
                views.setTextViewText(
                    R.id.pill_empty_text,
                    context.getString(
                        if (hasMorning || hasEvening) R.string.all_doses_taken_today
                        else R.string.no_doses_today
                    )
                )
                views.setViewVisibility(R.id.pill_empty_text, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.pill_empty_text, View.GONE)
            }

            // Morning Switch: Set state & enabled status
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setCompoundButtonChecked(R.id.switch_morning, morningTaken)
            } else {
                views.setBoolean(R.id.switch_morning, "setChecked", morningTaken)
            }
            views.setBoolean(R.id.switch_morning, "setEnabled", hasMorning)
            views.setTextViewText(
                R.id.switch_morning,
                if (showDoseCount && hasMorning && !isCompactWidth) "$morningCount" else ""
            )

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
            views.setTextViewText(
                R.id.switch_evening,
                if (showDoseCount && hasEvening && !isCompactWidth) "$eveningCount" else ""
            )

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
            return views
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
        WidgetPreviewHelper.updatePillPreview(context)
        PillWidgetScheduler.scheduleNextMidnightReset(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        PillWidgetScheduler.scheduleNextMidnightReset(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        PillWidgetScheduler.cancelMidnightReset(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_MIDNIGHT_RESET,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                refresh(context)
                PillWidgetScheduler.scheduleNextMidnightReset(context)
            }

            ACTION_TOGGLE_SLOT -> {
                val slot = intent.getStringExtra(EXTRA_SLOT) ?: return
                val wasTaken = intent.getBooleanExtra(EXTRA_CURRENT_STATE, false)
                // On Android 12+, RemoteViews sends the new checked state via RemoteViews.EXTRA_CHECKED
                val newTaken = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && intent.hasExtra(RemoteViews.EXTRA_CHECKED)) {
                    intent.getBooleanExtra(RemoteViews.EXTRA_CHECKED, !wasTaken)
                } else {
                    !wasTaken
                }

                // 1. Ensure data is resolved for today, then update SharedPreferences for local responsiveness
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val todayKey = PillWidgetScheduler.todayDateKey()
                val data = PillWidgetScheduler.resolveTodayData(context)
                if (slot == "morning") {
                    data.put("morningTaken", newTaken)
                } else if (slot == "evening") {
                    data.put("eveningTaken", newTaken)
                }
                prefs.edit().putString(DATA_KEY, data.toString()).apply()

                // 2. Queue date-stamped pending toggle action for Flutter to reconcile
                val existingQueue = prefs.getString(PENDING_TOGGLES_KEY, "") ?: ""
                val entry = "$slot:$newTaken:$todayKey"
                val newQueue = if (existingQueue.isEmpty()) entry else "$existingQueue,$entry"
                prefs.edit().putString(PENDING_TOGGLES_KEY, newQueue).apply()

                // 3. Immediately refresh widget views
                refresh(context)
            }
        }
    }
}
