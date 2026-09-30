package com.kianhamidi.housekeepr

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/**
 * Shopping list widget showing a flat list of grocery items with tickmark checkboxes.
 * Supports one-tap toggle on checkbox to check/uncheck items.
 * Clicking empty space, header, or item name opens the shopping list page in the app.
 * Coalesces rapid refresh requests to the latest update.
 * Supports responsive layouts matching 1x1, 1xn, nx1, or full configurations dynamically.
 */
open class ShoppingListWidget : AppWidgetProvider() {

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
        // Notify the factory to reload data in the list
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list)

        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
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
            ACTION_TOGGLE_ITEM -> {
                val itemId = intent.getStringExtra(EXTRA_ITEM_ID)
                if (itemId != null) {
                    val wasChecked = intent.getBooleanExtra(EXTRA_ITEM_CHECKED, false)

                    // Toggle the item in SharedPreferences directly for immediate feedback
                    toggleItemInPrefs(context, itemId, wasChecked)

                    // Request a coalesced widget update
                    requestUpdate(context)

                    // Notify Flutter of the toggle via pending toggles queue
                    notifyFlutterOfToggle(context, itemId)
                } else if (intent.getBooleanExtra("open_shopping", false)) {
                    // Open MainActivity when tapping item_content_area in ListView
                    val launchIntent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra("open_shopping", true)
                    }
                    context.startActivity(launchIntent)
                }
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
            // Gracefully ignore; Flutter handles structural synchronization
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

class ShoppingListWidget1x1 : ShoppingListWidget()
class ShoppingListWidget1xN : ShoppingListWidget()
class ShoppingListWidgetNx1 : ShoppingListWidget()

internal fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
    val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
    val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)

    // https://developer.android.com/develop/ui/views/appwidgets/layouts
    val isWidth1 = minWidth < 102
    val isHeight1 = minHeight < 102

    // Load data once for all layout permutations
    val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    val json = prefs.getString("shopping_list_data", null)

    var itemsCount = 0
    var nextUncheckedItemName = "All done!"

    try {
        if (json != null) {
            val type = object : TypeToken<List<Map<String, Any>>>() {}.type
            val rawList: List<Map<String, Any>>? = Gson().fromJson(json, type)
            itemsCount = rawList?.size ?: 0

            // Match the sorting logic (unchecked first, then matching name)
            nextUncheckedItemName = rawList?.firstOrNull {
                (it["checked"] as? Boolean) == false
            }?.get("name") as? String ?: "All done!"
        }
    } catch (e: Exception) {
        // Fallback safely retains defaults
    }

    // Build sub-views configurations explicitly to support runtime transitions flawlessly
    val views1x1 = RemoteViews(context.packageName, R.layout.widget_1x1).apply {
        setTextViewText(R.id.item_count, itemsCount.toString())
    }

    val views1xn = RemoteViews(context.packageName, R.layout.widget_1xn).apply {
        setTextViewText(R.id.item_count, itemsCount.toString())
    }

    val viewsNx1 = RemoteViews(context.packageName, R.layout.widget_nx1).apply {
        // 1. Fix the syntax error by closing the parenthesis properly
        setTextViewText(R.id.next_item_text, nextUncheckedItemName)

        // 2. Properly handle visibility and text updates based on items count
        if (itemsCount > 0) {
            val itemsLeftText = if (itemsCount == 1) "1 item to go" else "$itemsCount items to go"
            setTextViewText(R.id.amount_items_left, itemsLeftText)

            setViewVisibility(R.id.amount_items_left, android.view.View.VISIBLE)
            setViewVisibility(R.id.widget_empty_text, android.view.View.GONE)
        } else {
            setViewVisibility(R.id.amount_items_left, android.view.View.GONE)
            setViewVisibility(R.id.widget_empty_text, android.view.View.VISIBLE)
        }

        // --- ADD THE FIX HERE ---
        // 3. Find the exact item ID to toggle (we pull the first unchecked item)
        val nextUncheckedItemId = try {
            if (json != null) {
                val type = object : TypeToken<List<Map<String, Any>>>() {}.type
                val rawList: List<Map<String, Any>>? = Gson().fromJson(json, type)
                rawList?.firstOrNull { (it["checked"] as? Boolean) == false }?.get("id") as? String
            } else null
        } catch (e: Exception) {
            null
        }

        if (nextUncheckedItemId != null) {
            // Create the toggle intent targeted at the specific item ID
            val toggleIntent = Intent(context, ShoppingListWidget::class.java).apply {
                action = ShoppingListWidget.ACTION_TOGGLE_ITEM
                putExtra(ShoppingListWidget.EXTRA_ITEM_ID, nextUncheckedItemId)
                putExtra(
                    ShoppingListWidget.EXTRA_ITEM_CHECKED,
                    false
                ) // It's unchecked, so passing false
            }

            val togglePendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId + 1, // Unique request code to prevent overwriting the open-app intent
                toggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )

            // Bind the intent specifically to the checkbox hitboxes
            setOnClickPendingIntent(R.id.item_checkbox_area, togglePendingIntent)
        }
        // -------------------------
    }

    val viewsNormal = RemoteViews(context.packageName, R.layout.shopping_list_widget).apply {
        val serviceIntent = Intent(context, ShoppingListRemoteViewsService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        setRemoteAdapter(R.id.widget_list, serviceIntent)
        setEmptyView(R.id.widget_list, R.id.widget_empty_text)

        val templateIntent = Intent(context, ShoppingListWidget::class.java).apply {
            action = ShoppingListWidget.ACTION_TOGGLE_ITEM
        }
        val templatePendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            templateIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        setPendingIntentTemplate(R.id.widget_list, templatePendingIntent)
    }

    // Assign click action setup to all sub-view variants safely
    val openAppIntent = Intent(context, MainActivity::class.java).apply {
        action = Intent.ACTION_VIEW // Standard practice
        putExtra("open_shopping", true)
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }

    val pendingIntent = PendingIntent.getActivity(
        context,
        appWidgetId,
        openAppIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

        // 1x1 & 1xN use the container as the main target
    views1x1.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
    views1xn.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

    // Nx1 has specific containers
    viewsNx1.setOnClickPendingIntent(R.id.widget_container_1, pendingIntent)
    viewsNx1.setOnClickPendingIntent(R.id.widget_container_2, pendingIntent)

    // Normal/List view: target the header and empty text only
    viewsNormal.setOnClickPendingIntent(R.id.widget_title, pendingIntent)
    viewsNormal.setOnClickPendingIntent(R.id.widget_empty_text, pendingIntent)

    // Select target view configuration safely based on calculated grid cells 
    val chosenViews = when {
        isWidth1 && isHeight1 -> views1x1
        isWidth1 && !isHeight1 -> views1xn
        !isWidth1 && isHeight1 -> viewsNx1
        else -> viewsNormal
    }

    appWidgetManager.updateAppWidget(appWidgetId, chosenViews)
}