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
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

class CoffeeWidget : AppWidgetProvider() {
    companion object {
        private val layerIds = intArrayOf(
            R.id.coffee_layer_0,
            R.id.coffee_layer_1,
            R.id.coffee_layer_2,
            R.id.coffee_layer_3,
        )
        private const val RECIPE_KEY = "coffee_recipe_data"
        private const val ACTION_SPIN = "com.kianhamidi.housekeepr.ACTION_COFFEE_SPIN"
        private const val ACTION_RESET = "com.kianhamidi.housekeepr.ACTION_COFFEE_RESET"
        private const val PREFS = "HomeWidgetPreferences"
        private const val STATE_KEY = "coffee_widget_state"
        private const val STATE_IDLE = "idle"
        private const val STATE_SPINNING = "spinning"
        private const val STATE_RECIPE = "recipe"
        private const val SPIN_STEP_DEGREES = 30f
        private val handler = Handler(Looper.getMainLooper())

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

        private fun recipes(context: Context): JSONArray {
            val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(RECIPE_KEY, null)
            return try {
                val data = if (stored.isNullOrBlank()) defaultRecipe() else JSONObject(stored)
                val available = data.optJSONArray("recipes")
                if (available == null || available.length() == 0) {
                    JSONArray().put(data)
                } else {
                    available
                }
            } catch (_: Exception) {
                JSONArray().put(defaultRecipe())
            }
        }

        private fun defaultRecipe() = JSONObject().apply {
            put("name", "Latte")
            put("description", "")
            put("id", "latte")
            put("layers", org.json.JSONArray())
        }

        private fun completeSpin(context: Context) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val data = recipe(context)
            val available = recipes(context)
            val options = (0 until available.length())
                .mapNotNull { available.optJSONObject(it) }
            val selected = options
                .filter { it.optString("id") != data.optString("id") }
                .ifEmpty { options }
                .randomOrNull()
                ?: defaultRecipe()
            data.put("id", selected.optString("id", "latte"))
                .put("displayName", selected.optString("displayName", selected.optString("name", "Latte")))
                .put("name", selected.optString("displayName", selected.optString("name", "Latte")))
                .put("description", selected.optString("description", ""))
                .put("layers", selected.optJSONArray("layers") ?: JSONArray())
                .put("brewSteps", selected.optJSONArray("brewSteps") ?: JSONArray())
            prefs.edit()
                .putString(RECIPE_KEY, data.toString())
                .putString(STATE_KEY, STATE_RECIPE)
                .apply()
            refresh(context)
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val data = recipe(context)
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val state = prefs.getString(STATE_KEY, STATE_IDLE) ?: STATE_IDLE
            val views = RemoteViews(context.packageName, R.layout.coffee_widget).apply {
                setViewVisibility(
                    R.id.coffee_idle_state,
                    if (state == STATE_RECIPE) android.view.View.GONE else android.view.View.VISIBLE,
                )
                setViewVisibility(
                    R.id.coffee_recipe_state,
                    if (state == STATE_RECIPE) android.view.View.VISIBLE else android.view.View.GONE,
                )
                setTextViewText(
                    R.id.coffee_spin_status,
                    if (state == STATE_SPINNING) "SPINNING..." else "TAP TO SPIN",
                )
                setFloat(R.id.coffee_spinner, "setRotation", 0f)

                val spinIntent = Intent(context, CoffeeWidget::class.java).setAction(ACTION_SPIN)
                setOnClickPendingIntent(
                    R.id.coffee_spinner,
                    PendingIntent.getBroadcast(
                        context,
                        id,
                        spinIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    ),
                )
                setOnClickPendingIntent(
                    R.id.coffee_spin_status,
                    PendingIntent.getBroadcast(
                        context,
                        id,
                        spinIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    ),
                )

                val openIntent =
                    Intent(Intent.ACTION_VIEW, Uri.parse("housekeepr://coffee/recipe/${data.optString("id", "latte")}"))
                        .setClass(context, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                if (state == STATE_RECIPE) {
                    setTextViewText(
                        R.id.coffee_recipe_title,
                        data.optString(
                            "displayName",
                            data.optString("name", "Latte"),
                        ),
                    )
                    val description = data.optString(
                        "description",
                        data.optString("description", "Latte"),
                    )
                    setTextViewText(
                        R.id.coffee_recipe_subtitle,
                        if (description.isEmpty() || description.isNullOrBlank()) {
                            "Tap for recipe"
                        } else {
                            description
                        },
                    )
                    setOnClickPendingIntent(
                        R.id.coffee_root,
                        PendingIntent.getActivity(
                            context,
                            id + 1000,
                            openIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        ),
                    )
                }

                val resetIntent = Intent(context, CoffeeWidget::class.java).setAction(ACTION_RESET)
                setOnClickPendingIntent(
                    R.id.coffee_reset,
                    PendingIntent.getBroadcast(
                        context,
                        id + 2000,
                        resetIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    ),
                )

                layerIds.forEach { layerId ->
                    setViewVisibility(layerId, android.view.View.GONE)
                }
                val layers = data.optJSONArray("layers") ?: JSONArray()
                val count = minOf(layers.length(), layerIds.size)
                for (index in 0 until count) {
                    val layer = layers.optJSONObject(index) ?: continue
                    val layerId = layerIds[index]
                    val ratio = layer.optDouble("partsRatio", 1.0)
                    val label = layer.optString(
                        "unitLabel",
                        "${ratio}x ${layer.optString("name", "Layer")}",
                    )
                    val color = layer.optInt("color", 0xFF9E9E9E.toInt())
                    setViewVisibility(layerId, android.view.View.VISIBLE)
                    setTextViewText(layerId, label)
                    setInt(layerId, "setBackgroundColor", color)
                    setInt(
                        layerId,
                        "setTextColor",
                        if (isLightColor(color)) android.graphics.Color.DKGRAY
                        else android.graphics.Color.WHITE,
                    )
                }
            }
            manager.updateAppWidget(id, views)
        }

        private fun isLightColor(color: Int): Boolean {
            val luminance =
                (0.299 * android.graphics.Color.red(color)) +
                    (0.587 * android.graphics.Color.green(color)) +
                    (0.114 * android.graphics.Color.blue(color))
            return luminance > 160
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_SPIN) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (prefs.getString(STATE_KEY, STATE_IDLE) == STATE_SPINNING) return
            prefs.edit().putString(STATE_KEY, STATE_SPINNING).apply()
            refresh(context)

            var currentRotation = 0f
            var currentVelocity = 45f
            val friction = 0.93f
            val animation = object : Runnable {
                override fun run() {
                    if (prefs.getString(STATE_KEY, STATE_IDLE) != STATE_SPINNING) return

                    currentVelocity *= friction

                    if (currentVelocity < 0.5f) {
                        completeSpin(context)
                        return
                    }

                    val manager = AppWidgetManager.getInstance(context)
                    val component = ComponentName(context, CoffeeWidget::class.java)

                    manager.getAppWidgetIds(component).forEach { id ->
                        val views = RemoteViews(context.packageName, R.layout.coffee_widget)
                        currentRotation += currentVelocity
                        views.setFloat(R.id.coffee_spinner, "setRotation", currentRotation)
                        manager.partiallyUpdateAppWidget(id, views)
                    }

                    handler.postDelayed(this, 30L)
                }
            }
            handler.post(animation)
        } else if (intent.action == ACTION_RESET) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(STATE_KEY, STATE_IDLE).apply()
            refresh(context)
        } else if (intent.action == AppWidgetManager.ACTION_APPWIDGET_ENABLED) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(STATE_KEY, STATE_IDLE).apply()
        }
    }
}