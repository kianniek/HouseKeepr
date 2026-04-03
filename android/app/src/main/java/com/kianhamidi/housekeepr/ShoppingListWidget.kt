package com.kianhamidi.housekeepr

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.RemoteViews
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/**
 * Shopping list widget showing a flat list of grocery items with tickmark checkboxes.
 * Supports one-tap toggle on checkbox to check/uncheck items.
 * Clicking empty space, header, or item name opens the shopping list page in the app.
 * Coalesces rapid refresh requests to the latest update.
 */
class ShoppingListWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE_ITEM = "com.kianhamidi.housekeepr.ACTION_TOGGLE_ITEM"
        const val ACTION_OPEN_APP = "com.kianhamidi.housekeepr.ACTION_OPEN_SHOPPING"
        const val EXTRA_ITEM_ID = "extra_item_id"
        const val EXTRA_ITEM_CHECKED = "extra_item_checked"

        // Coalesce guard: minimum interval between widget updates (ms)
        private const val COALESCE_INTERVAL_MS = 250L
        private var lastUpdateTime = 0L
        private val handler = Handler(Looper.getMainLooper())
        private var pendingUpdateRunnable: Runnable? = null

        /**
         * Trigger a coalesced widget update from anywhere (e.g. after toggling an item).
         * Drops intermediate requests and only applies the latest within the window.
         */
        fun requestUpdate(context: Context) {
            val now = System.currentTimeMillis()
            val elapsed = now - lastUpdateTime

            // Cancel any pending update
            pendingUpdateRunnable?.let { handler.removeCallbacks(it) }

            val runnable = Runnable {
                lastUpdateTime = System.currentTimeMillis()
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(
                    ComponentName(context, ShoppingListWidget::class.java)
                )
                // Notify the factory to reload data
                manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
                // Also update the chrome (empty state, title, etc.)
                for (id in ids) {
                    updateAppWidget(context, manager, id)
                }
            }

            if (elapsed < COALESCE_INTERVAL_MS) {
                // Schedule for later (coalesce)
                pendingUpdateRunnable = runnable
                handler.postDelayed(runnable, COALESCE_INTERVAL_MS - elapsed)
            } else {
                // Run immediately
                pendingUpdateRunnable = null
                runnable.run()
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_TOGGLE_ITEM -> {
                val itemId = intent.getStringExtra(EXTRA_ITEM_ID) ?: return
                val wasChecked = intent.getBooleanExtra(EXTRA_ITEM_CHECKED, false)

                // Toggle the item in SharedPreferences directly for immediate feedback
                toggleItemInPrefs(context, itemId, wasChecked)

                // Request a coalesced widget update
                requestUpdate(context)

                // Notify Flutter of the toggle via pending toggles queue
                notifyFlutterOfToggle(context, itemId)
            }
            ACTION_OPEN_APP -> {
                // Launch MainActivity which will route to the shopping page
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("open_shopping", true)
                }
                context.startActivity(launchIntent)
            }
        }
    }

    override fun onEnabled(context: Context) {
        // First widget placed
    }

    override fun onDisabled(context: Context) {
        // Last widget removed
    }

    /**
     * Toggle an item's checked state directly in SharedPreferences for instant widget feedback.
     */
    private fun toggleItemInPrefs(context: Context, itemId: String, wasChecked: Boolean) {
        try {
            val prefs = context.getSharedPreferences(
                "HomeWidgetPreferences", Context.MODE_PRIVATE
            )
            val json = prefs.getString("shopping_list_data", null) ?: return
            val gson = Gson()
            val type = object : TypeToken<List<MutableMap<String, Any>>>() {}.type
            val items: List<MutableMap<String, Any>> = gson.fromJson(json, type)

            for (item in items) {
                if (item["id"] == itemId) {
                    item["checked"] = !wasChecked
                    if (!wasChecked) {
                        // Was unchecked, now checking — set checkedAt
                        item["checkedAt"] = java.time.Instant.now().toString()
                    } else {
                        // Was checked, now unchecking — clear checkedAt
                        item.remove("checkedAt")
                    }
                    break
                }
            }

            prefs.edit().putString("shopping_list_data", gson.toJson(items)).apply()
        } catch (e: Exception) {
            // Gracefully ignore; Flutter will reconcile on next sync
        }
    }

    /**
     * Send an intent to Flutter (via pending toggles queue)
     * so the GroceryRepository can be updated.
     */
    private fun notifyFlutterOfToggle(context: Context, itemId: String) {
        // Store the toggle request for Flutter to pick up on next resume
        val prefs = context.getSharedPreferences(
            "HomeWidgetPreferences", Context.MODE_PRIVATE
        )
        // Append to a pending-toggles list
        val existing = prefs.getString("pending_toggles", "") ?: ""
        val updated = if (existing.isNotEmpty()) "$existing,$itemId" else itemId
        prefs.edit().putString("pending_toggles", updated).apply()
    }
}

internal fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    val views = RemoteViews(context.packageName, R.layout.shopping_list_widget)

    // Check if list is empty for empty-state display
    val prefs = context.getSharedPreferences(
        "HomeWidgetPreferences", Context.MODE_PRIVATE
    )
    val json = prefs.getString("shopping_list_data", null)
    val isEmpty = json.isNullOrBlank() || json == "[]"

    if (isEmpty) {
        views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)
        views.setViewVisibility(R.id.widget_list, View.GONE)
    } else {
        views.setViewVisibility(R.id.widget_empty_text, View.GONE)
        views.setViewVisibility(R.id.widget_list, View.VISIBLE)
    }

    // Set up the RemoteViews adapter (list data source)
    val serviceIntent = Intent(context, ShoppingListRemoteViewsService::class.java).apply {
        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        // Unique data URI so the system doesn't reuse old factories
        data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
    }
    views.setRemoteAdapter(R.id.widget_list, serviceIntent)
    views.setEmptyView(R.id.widget_list, R.id.widget_empty_text)

    // Set up a PendingIntent template for item checkbox clicks (toggle action)
    val toggleIntent = Intent(context, ShoppingListWidget::class.java).apply {
        action = ShoppingListWidget.ACTION_TOGGLE_ITEM
    }
    val togglePendingIntent = PendingIntent.getBroadcast(
        context, 0, toggleIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
    )
    views.setPendingIntentTemplate(R.id.widget_list, togglePendingIntent)

    // Set up a PendingIntent for opening the app (header and empty state clicks)
    val openAppIntent = Intent(context, ShoppingListWidget::class.java).apply {
        action = ShoppingListWidget.ACTION_OPEN_APP
    }
    val openAppPendingIntent = PendingIntent.getBroadcast(
        context, 1, openAppIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
    )
    views.setOnClickPendingIntent(R.id.widget_title, openAppPendingIntent)
    views.setOnClickPendingIntent(R.id.widget_empty_text, openAppPendingIntent)

    appWidgetManager.updateAppWidget(appWidgetId, views)
}