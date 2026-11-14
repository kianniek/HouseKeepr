package com.kianhamidi.housekeepr

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * Configuration activity for Android AppWidgets (initial placement and
 * reconfigurable "Widget settings" from home-screen long-press).
 *
 * Confirms placement with [Activity.RESULT_OK] + [AppWidgetManager.EXTRA_APPWIDGET_ID],
 * triggers an initial widget render, and forwards to [MainActivity] without
 * [Intent.FLAG_ACTIVITY_NEW_TASK] so the user returns cleanly to the launcher
 * after saving.
 */
class WidgetConfigureActivity : Activity() {
    companion object {
        const val EXTRA_IS_WIDGET_CONFIG = "extra_is_widget_config"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        val appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val appWidgetManager = AppWidgetManager.getInstance(this)
        val providerClass = appWidgetManager
            .getAppWidgetInfo(appWidgetId)
            ?.provider
            ?.className
            ?: ""

        // Android skips onUpdate() when android:configure is declared, so trigger
        // an initial render immediately.
        when {
            providerClass.endsWith("PillWidget") -> {
                PillWidget.updateAppWidget(this, appWidgetManager, appWidgetId)
            }
            providerClass.endsWith("ShoppingListWidget") -> {
                appWidgetManager.notifyAppWidgetViewDataChanged(
                    intArrayOf(appWidgetId),
                    R.id.widget_list,
                )
                updateAppWidget(this, appWidgetManager, appWidgetId)
            }
            providerClass.endsWith("CoffeeWidget") -> {
                CoffeeWidget.updateAppWidget(this, appWidgetManager, appWidgetId)
            }
        }

        val resultIntent = Intent().putExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            appWidgetId,
        )
        setResult(RESULT_OK, resultIntent)

        val baseUri = when {
            providerClass.endsWith("PillWidget") -> "housekeepr://widget-settings/pill"
            providerClass.endsWith("ShoppingListWidget") -> "housekeepr://widget-settings/shopping"
            providerClass.endsWith("CoffeeWidget") -> "housekeepr://widget-settings/coffee"
            else -> "housekeepr://widget-settings"
        }
        val targetUri = Uri.parse(baseUri).buildUpon()
            .appendQueryParameter("appWidgetId", appWidgetId.toString())
            .build()

        val launchIntent = Intent(Intent.ACTION_VIEW, targetUri).apply {
            setClass(this@WidgetConfigureActivity, MainActivity::class.java)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            putExtra(EXTRA_IS_WIDGET_CONFIG, true)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(launchIntent)
        finish()
    }
}
