package com.kianhamidi.housekeepr

import android.content.Context
import android.content.res.Configuration
import org.json.JSONObject

data class WidgetThemePalette(
    val isDark: Boolean,
    val surface: Int,
    val surfaceContainer: Int,
    val onSurface: Int,
    val onSurfaceVariant: Int,
    val primary: Int,
    val onPrimary: Int,
    val primaryContainer: Int,
    val onPrimaryContainer: Int,
    val outline: Int,
)

object WidgetThemeHelper {
    private const val PREFS = "HomeWidgetPreferences"
    private const val MODE_KEY = "widget_theme_mode"
    private const val LIGHT_COLORS_KEY = "widget_theme_colors_light"
    private const val DARK_COLORS_KEY = "widget_theme_colors_dark"

    fun resolve(context: Context): WidgetThemePalette {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val mode = prefs.getString(MODE_KEY, "system") ?: "system"
        val isDark = when (mode) {
            "dark" -> true
            "light" -> false
            else -> {
                val nightFlags = context.resources.configuration.uiMode and
                    Configuration.UI_MODE_NIGHT_MASK
                nightFlags == Configuration.UI_MODE_NIGHT_YES
            }
        }

        val jsonStr = prefs.getString(if (isDark) DARK_COLORS_KEY else LIGHT_COLORS_KEY, null)
        if (!jsonStr.isNullOrBlank()) {
            try {
                val obj = JSONObject(jsonStr)
                return WidgetThemePalette(
                    isDark = isDark,
                    surface = obj.colorInt("surface", defaultSurface(isDark)),
                    surfaceContainer = obj.colorInt("surfaceContainer", defaultSurfaceContainer(isDark)),
                    onSurface = obj.colorInt("onSurface", defaultOnSurface(isDark)),
                    onSurfaceVariant = obj.colorInt("onSurfaceVariant", defaultOnSurfaceVariant(isDark)),
                    primary = obj.colorInt("primary", defaultPrimary(isDark)),
                    onPrimary = obj.colorInt("onPrimary", defaultOnPrimary(isDark)),
                    primaryContainer = obj.colorInt("primaryContainer", defaultPrimaryContainer(isDark)),
                    onPrimaryContainer = obj.colorInt("onPrimaryContainer", defaultOnPrimaryContainer(isDark)),
                    outline = obj.colorInt("outline", defaultOutline(isDark)),
                )
            } catch (_: Exception) {
                // Fall back to defaults
            }
        }

        return WidgetThemePalette(
            isDark = isDark,
            surface = defaultSurface(isDark),
            surfaceContainer = defaultSurfaceContainer(isDark),
            onSurface = defaultOnSurface(isDark),
            onSurfaceVariant = defaultOnSurfaceVariant(isDark),
            primary = defaultPrimary(isDark),
            onPrimary = defaultOnPrimary(isDark),
            primaryContainer = defaultPrimaryContainer(isDark),
            onPrimaryContainer = defaultOnPrimaryContainer(isDark),
            outline = defaultOutline(isDark),
        )
    }

    private fun JSONObject.colorInt(key: String, fallback: Int): Int =
        if (has(key) && !isNull(key)) optLong(key, fallback.toLong()).toInt() else fallback

    private fun defaultSurface(isDark: Boolean) =
        if (isDark) 0xFF121212.toInt() else 0xFFFFFFFF.toInt()

    private fun defaultSurfaceContainer(isDark: Boolean) =
        if (isDark) 0xFF1E1E1E.toInt() else 0xFFF5F5F5.toInt()

    private fun defaultOnSurface(isDark: Boolean) =
        if (isDark) 0xFFECECEC.toInt() else 0xFF1F1F1F.toInt()

    private fun defaultOnSurfaceVariant(isDark: Boolean) =
        if (isDark) 0xFFB0B0B0.toInt() else 0xFF616161.toInt()

    private fun defaultPrimary(isDark: Boolean) =
        if (isDark) 0xFFFFAB40.toInt() else 0xFFC65102.toInt()

    private fun defaultOnPrimary(isDark: Boolean) =
        if (isDark) 0xFF000000.toInt() else 0xFFFFFFFF.toInt()

    private fun defaultPrimaryContainer(isDark: Boolean) =
        if (isDark) 0xFF6E3200.toInt() else 0xFFFFE0B2.toInt()

    private fun defaultOnPrimaryContainer(isDark: Boolean) =
        if (isDark) 0xFFFFE0B2.toInt() else 0xFF3E1700.toInt()

    private fun defaultOutline(isDark: Boolean) =
        if (isDark) 0xFF333333.toInt() else 0xFFBDBDBD.toInt()
}
