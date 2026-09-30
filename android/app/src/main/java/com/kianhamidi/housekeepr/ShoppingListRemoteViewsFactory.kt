package com.kianhamidi.housekeepr

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Paint
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/**
 * Data class for a grocery item in the widget.
 */
data class WidgetGroceryItem(
    val id: String,
    val name: String,
    val quantity: Int,
    val checked: Boolean,
    val createdAt: String?,
    val checkedAt: String?
)

/**
 * Factory that provides data for each row in the shopping list widget's ListView.
 * Reads items from SharedPreferences (written by Flutter via home_widget),
 * sorts unchecked first then checked, each group sorted by checkedAt then createdAt.
 */
class ShoppingListRemoteViewsFactory(
    private val context: Context,
    private val intent: Intent? = null
) : RemoteViewsService.RemoteViewsFactory {

    companion object {
        private const val TAG = "ShoppingListRVFactory"
    }

    private val lock = Any()
    private var items: List<WidgetGroceryItem> = emptyList()
    private val gson = Gson()
    private val itemType = object : TypeToken<List<WidgetGroceryItem>>() {}.type

    // Unique non-colliding ID mapping to prevent flickering
    private val idMap = mutableMapOf<String, Long>()
    private var nextId = 1L

    private val isDarkMode: Boolean
        get() {
            val nightModeFlags = context.resources.configuration.uiMode and
                    Configuration.UI_MODE_NIGHT_MASK
            return nightModeFlags == Configuration.UI_MODE_NIGHT_YES
        }

    /** Normal text color, theme-aware. */
    private val normalTextColor: Int
        get() = if (isDarkMode) 0xFFFFFFFF.toInt() else 0xFF000000.toInt()

    /** Checked/lighter text color, theme-aware. */
    private val checkedTextColor: Int
        get() = if (isDarkMode) 0x80FFFFFF.toInt() else 0x80000000.toInt()

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    private fun loadData() {
        synchronized(lock) {
            try {
                val prefs = context.getSharedPreferences(
                    "HomeWidgetPreferences", Context.MODE_PRIVATE
                )
                val json = prefs.getString("shopping_list_data", null)
                if (json != null) {
                    val rawItems: List<WidgetGroceryItem> = gson.fromJson(json, itemType)
                    items = rawItems
                } else {
                    items = emptyList()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error loading shopping list widget data from SharedPreferences", e)
                items = emptyList()
            }
        }
    }

    override fun onDestroy() {
        synchronized(lock) {
            items = emptyList()
        }
        synchronized(idMap) {
            idMap.clear()
        }
    }

    override fun getCount(): Int {
        synchronized(lock) {
            return items.size
        }
    }

    override fun getViewAt(position: Int): RemoteViews {
        val currentItems = synchronized(lock) { items }

        if (position < 0 || position >= currentItems.size) {
            val fallbackViews = RemoteViews(context.packageName, R.layout.shopping_list_item)
            fallbackViews.setViewVisibility(R.id.item_root, View.GONE)
            return fallbackViews
        }

        val item = currentItems[position]
        val views = RemoteViews(context.packageName, R.layout.shopping_list_item)

        // Set item name
        views.setTextViewText(R.id.item_name, item.name)

        // Apply checked styling: lighter text + strikethrough
        if (item.checked) {
            views.setImageViewResource(
                R.id.item_tick,
                R.drawable.ic_checkbox_checked
            )
            // Lighter text color for checked items
            views.setTextColor(R.id.item_name, checkedTextColor)
            // Strikethrough via paint flags
            views.setInt(
                R.id.item_name, "setPaintFlags",
                Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG
            )
        } else {
            views.setImageViewResource(
                R.id.item_tick,
                R.drawable.ic_checkbox_unchecked
            )
            // Normal text color
            views.setTextColor(R.id.item_name, normalTextColor)
            // Clear strikethrough
            views.setInt(
                R.id.item_name, "setPaintFlags",
                Paint.ANTI_ALIAS_FLAG
            )
        }

        // Quantity badge: hidden when qty <= 1, shown otherwise
        if (item.quantity > 1) {
            views.setViewVisibility(R.id.item_quantity_badge, View.VISIBLE)
            views.setTextViewText(R.id.item_quantity_badge, item.quantity.toString())
        } else {
            views.setViewVisibility(R.id.item_quantity_badge, View.GONE)
        }

        // Set up fill-in intent for checkbox click (toggle action)
        val toggleFillInIntent = Intent().apply {
            putExtra(ShoppingListWidget.EXTRA_ITEM_ID, item.id)
            putExtra(ShoppingListWidget.EXTRA_ITEM_CHECKED, item.checked)
        }
        views.setOnClickFillInIntent(R.id.item_checkbox_area, toggleFillInIntent)

        // Set up fill-in intent for content area click (open app action)
        val openAppFillInIntent = Intent().apply {
    putExtra("open_shopping", true) // Ensure MainActivity handles this extra
}
views.setOnClickFillInIntent(R.id.item_content_area, openAppFillInIntent)   

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long {
        val currentItems = synchronized(lock) { items }
        if (position < 0 || position >= currentItems.size) return position.toLong()
        val stringId = currentItems[position].id
        return synchronized(idMap) {
            idMap.getOrPut(stringId) { nextId++ }
        }
    }

    override fun hasStableIds(): Boolean = true
}
