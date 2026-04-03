package com.kianhamidi.housekeepr

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Paint
import android.os.Bundle
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
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<WidgetGroceryItem> = emptyList()
    private val gson = Gson()

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
        try {
            val prefs = context.getSharedPreferences(
                "HomeWidgetPreferences", Context.MODE_PRIVATE
            )
            val json = prefs.getString("shopping_list_data", null)
            if (json != null) {
                val type = object : TypeToken<List<WidgetGroceryItem>>() {}.type
                val rawItems: List<WidgetGroceryItem> = gson.fromJson(json, type)
                items = sortItems(rawItems)
            } else {
                items = emptyList()
            }
        } catch (e: Exception) {
            items = emptyList()
        }
    }

    /**
     * Sort: unchecked first, then checked.
     * Within each group, sort by checkedAt (nulls last) then createdAt ascending.
     */
    private fun sortItems(rawItems: List<WidgetGroceryItem>): List<WidgetGroceryItem> {
        val unchecked = rawItems.filter { !it.checked }
            .sortedBy { it.createdAt ?: "" }
        val checked = rawItems.filter { it.checked }
            .sortedByDescending { it.checkedAt ?: "" }
        return unchecked + checked
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.shopping_list_item)

        if (position < 0 || position >= items.size) {
            return views
        }

        val item = items[position]

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
            val extras = Bundle()
            extras.putString(ShoppingListWidget.EXTRA_ITEM_ID, item.id)
            extras.putBoolean(ShoppingListWidget.EXTRA_ITEM_CHECKED, item.checked)
            putExtras(extras)
        }
        views.setOnClickFillInIntent(R.id.item_checkbox_area, toggleFillInIntent)

        // Set up fill-in intent for content area click (open app action)
        val openAppFillInIntent = Intent().apply {
            action = ShoppingListWidget.ACTION_OPEN_APP
        }
        views.setOnClickFillInIntent(R.id.item_content_area, openAppFillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long {
        if (position < 0 || position >= items.size) return position.toLong()
        return items[position].id.hashCode().toLong()
    }

    override fun hasStableIds(): Boolean = true
}
