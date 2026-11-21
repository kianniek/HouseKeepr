package com.kianhamidi.housekeepr

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.widget.RemoteViews

/**
 * Updates dynamic widget picker previews on Android 15+ (API 35+) so the
 * launcher's widget picker reflects the app's current [WidgetThemePalette].
 * On API < 35, the launcher uses the static `android:previewLayout` XML.
 */
object WidgetPreviewHelper {
    private val previewUncheckedItemIds = intArrayOf(
        R.id.preview_item_1,
        R.id.preview_item_2,
        R.id.preview_item_3,
        R.id.preview_item_4,
    )

    fun updateAll(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return
        updatePillPreview(context)
        updateShoppingListPreview(context)
        updateCoffeePreview(context)
    }

    fun updatePillPreview(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return
        val palette = WidgetThemeHelper.resolve(context)
        val views = RemoteViews(context.packageName, R.layout.pill_widget).apply {
            WidgetThemeHelper.applyRoundedBackground(this, R.id.pill_widget_root, palette.surface)
            setTextColor(R.id.pill_widget_title, palette.onSurface)
            setTextViewText(R.id.pill_widget_title, context.getString(R.string.pills))
            setTextColor(R.id.pill_empty_text, palette.onSurfaceVariant)
        }
        AppWidgetManager.getInstance(context).setWidgetPreview(
            ComponentName(context, PillWidget::class.java),
            AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN,
            views,
        )
    }

    fun updateShoppingListPreview(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return
        val palette = WidgetThemeHelper.resolve(context)
        val checkedColor = (palette.onSurfaceVariant and 0x00FFFFFF) or (0x80 shl 24)
        val views = RemoteViews(context.packageName, R.layout.shopping_list_widget_preview).apply {
            WidgetThemeHelper.applyRoundedBackground(this, R.id.preview_root, palette.surface)
            setTextColor(R.id.preview_title, palette.onSurface)
            setTextViewText(R.id.preview_title, context.getString(R.string.shopping_list))
            for (itemId in previewUncheckedItemIds) {
                setTextColor(itemId, palette.onSurface)
            }
            setTextColor(R.id.preview_item_5, checkedColor)
        }
        AppWidgetManager.getInstance(context).setWidgetPreview(
            ComponentName(context, ShoppingListWidget::class.java),
            AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN,
            views,
        )
    }

    fun updateCoffeePreview(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return
        val palette = WidgetThemeHelper.resolve(context)
        val views = RemoteViews(context.packageName, R.layout.coffee_widget).apply {
            WidgetThemeHelper.applyRoundedBackground(this, R.id.coffee_root, palette.surface)
            setTextColor(R.id.coffee_title, palette.onSurfaceVariant)
            setTextViewText(R.id.coffee_title, context.getString(R.string.coffee_what_to_brew))
            setTextColor(R.id.coffee_arrow, palette.primary)
            WidgetThemeHelper.applyRoundedBackground(this, R.id.coffee_spin_status, palette.primary)
            setTextColor(R.id.coffee_spin_status, palette.onPrimary)
            setTextViewText(R.id.coffee_spin_status, context.getString(R.string.coffee_tap_to_spin))
            setViewVisibility(R.id.coffee_idle_state, android.view.View.VISIBLE)
            setViewVisibility(R.id.coffee_recipe_state, android.view.View.GONE)
        }
        AppWidgetManager.getInstance(context).setWidgetPreview(
            ComponentName(context, CoffeeWidget::class.java),
            AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN,
            views,
        )
    }
}
