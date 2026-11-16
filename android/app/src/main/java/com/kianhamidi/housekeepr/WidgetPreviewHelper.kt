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
    }

    fun updatePillPreview(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return
        val palette = WidgetThemeHelper.resolve(context)
        val views = RemoteViews(context.packageName, R.layout.pill_widget).apply {
            setInt(R.id.pill_widget_root, "setBackgroundColor", palette.surface)
            setTextColor(R.id.pill_widget_title, palette.onSurface)
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
            setInt(R.id.preview_root, "setBackgroundColor", palette.surface)
            setTextColor(R.id.preview_title, palette.onSurface)
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
}
