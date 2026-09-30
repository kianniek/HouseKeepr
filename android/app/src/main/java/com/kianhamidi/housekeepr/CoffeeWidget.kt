in package com.kianhamidi.housekeepr

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONObject

class CoffeeWidget : AppWidgetProvider() {
    companion object {
        private const val RECIPE_KEY = "coffee_recipe_data"
        private const val ACTION_SPIN = "com.kianhamidi.housekeepr.ACTION_COFFEE_SPIN"
        private const val PREFS = "HomeWidgetPreferences"

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, CoffeeWidget::class.java)
            CoffeeWidget().onUpdate(context, manager, manager.getAppWidgetIds(component))
        }

        private fun recipe(context: Context): JSONObject {
            val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(RECIPE_KEY, null)
            return try {
                if (stored.isNullOrBlank()) defaultRecipe() else JSONObject(stored)
            } catch (_: Exception) {
                defaultRecipe()
            }
        }

        private fun defaultRecipe() = JSONObject().apply {
            put("name", "Latte")
            put("id", "latte")
            put("layers", org.json.JSONArray())
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val data = recipe(context)
            val views = RemoteViews(context.packageName, R.layout.coffee_widget).apply {
                setTextViewText(R.id.coffee_title, data.optString("name", "Latte"))

                val spinIntent = Intent(context, CoffeeWidget::class.java).setAction(ACTION_SPIN)
                setOnClickPendingIntent(
                    R.id.coffee_spin,
                    PendingIntent.getBroadcast(context, id, spinIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE),
                )

                val openIntent = Intent(Intent.ACTION_VIEW, Uri.parse("housekeepr://coffee/recipe/${data.optString("id", "latte")}"))
                    .setClass(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                setOnClickPendingIntent(
                    R.id.coffee_root,
                    PendingIntent.getActivity(context, id + 1000, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE),
                )

                val layers = data.optJSONArray("layers")
                if (layers != null && layers.length() > 0) {
                    val first = layers.optJSONObject(0)
                    if (first != null) setTextViewText(R.id.coffee_espresso, first.optString("unit", "1x Espresso"))
                    if (layers.length() > 1) setTextViewText(R.id.coffee_milk, layers.optJSONObject(1)?.optString("unit", "3x Milk"))
                    if (layers.length() > 2) setTextViewText(R.id.coffee_foam, layers.optJSONObject(2)?.optString("unit", "0.5x Foam"))
                }
            }
            manager.updateAppWidget(id, views)
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_SPIN) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val data = recipe(context)
            val nextId = if (data.optString("id") == "latte") "cappuccino" else "latte"
            data.put("id", nextId).put("name", if (nextId == "latte") "Latte" else "Cappuccino")
            prefs.edit().putString(RECIPE_KEY, data.toString()).apply()
            refresh(context)
        }
    }
}