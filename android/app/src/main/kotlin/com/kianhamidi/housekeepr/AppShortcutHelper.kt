package com.kianhamidi.housekeepr

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.Rect
import android.net.Uri
import androidx.core.content.ContextCompat
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import java.io.File

object AppShortcutHelper {
    private const val SHORTCUT_ID_SHOPPING = "quick_add_shopping"
    private const val SHORTCUT_ID_TASK = "quick_add_task"
    private const val SHORTCUT_ID_OPEN_GYM = "open_gym"
    private const val SHORTCUT_ID_NEXT_WORKOUT = "open_gym_next_workout"
    private const val SHORTCUT_ID_MEDICATIONS = "medications"

    const val SHARE_CATEGORY_SHOPPING = "com.kianhamidi.housekeepr.category.SHARE_SHOPPING"
    const val SHARE_CATEGORY_TASK = "com.kianhamidi.housekeepr.category.SHARE_TASK"

    private const val PREFS_NAME = "housekeepr_shortcuts"
    private const val FG_ICON_FILE = "open_gym_next_workout_fg.png"

    private const val KEY_HAS_NEXT_WORKOUT = "has_next_workout"
    private const val KEY_SHORT_LABEL = "short_label"
    private const val KEY_LONG_LABEL = "long_label"
    private const val KEY_HAS_FG_BITMAP = "has_fg_bitmap"
    private const val KEY_THEME_MODE = "theme_mode"
    private const val KEY_LIGHT_PRIMARY = "light_primary"
    private const val KEY_LIGHT_BACKGROUND = "light_background"
    private const val KEY_DARK_PRIMARY = "dark_primary"
    private const val KEY_DARK_BACKGROUND = "dark_background"

    const val DEFAULT_LIGHT_PRIMARY: Int = 0xFFC65102.toInt()
    const val DEFAULT_LIGHT_BACKGROUND: Int = 0xFFFFFFFF.toInt()
    const val DEFAULT_DARK_PRIMARY: Int = 0xFFFFAB40.toInt()
    const val DEFAULT_DARK_BACKGROUND: Int = 0xFF121212.toInt()

    fun updateNextWorkoutShortcut(
        context: Context,
        shortLabel: String,
        longLabel: String,
        iconBytes: ByteArray?,
        iconColor: Int?,
        backgroundColor: Int?,
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val fgFile = File(context.noBackupFilesDir, FG_ICON_FILE)
        val hasFgBitmap = iconBytes != null
        if (iconBytes != null) {
            runCatching { fgFile.writeBytes(iconBytes) }
        } else if (fgFile.exists()) {
            runCatching { fgFile.delete() }
        }

        prefs.edit()
            .putBoolean(KEY_HAS_NEXT_WORKOUT, true)
            .putString(KEY_SHORT_LABEL, shortLabel)
            .putString(KEY_LONG_LABEL, longLabel)
            .putBoolean(KEY_HAS_FG_BITMAP, hasFgBitmap)
            .apply()

        val colorOverride = if (iconColor != null && backgroundColor != null) {
            iconColor to backgroundColor
        } else {
            null
        }
        refreshDynamicShortcuts(context, nextWorkoutColorsOverride = colorOverride)
    }

    fun updateShortcutTheme(
        context: Context,
        themeMode: String,
        lightPrimary: Int,
        lightBackground: Int,
        darkPrimary: Int,
        darkBackground: Int,
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_THEME_MODE, themeMode)
            .putInt(KEY_LIGHT_PRIMARY, lightPrimary)
            .putInt(KEY_LIGHT_BACKGROUND, lightBackground)
            .putInt(KEY_DARK_PRIMARY, darkPrimary)
            .putInt(KEY_DARK_BACKGROUND, darkBackground)
            .apply()

        refreshDynamicShortcuts(context)
    }

    fun refreshDynamicShortcutIfPresent(context: Context) {
        refreshDynamicShortcuts(context)
    }

    fun refreshDynamicShortcuts(
        context: Context,
        nextWorkoutColorsOverride: Pair<Int, Int>? = null,
    ) {
        val (primary, background) = resolveThemeColors(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val shoppingShortcut = ShortcutInfoCompat.Builder(context, SHORTCUT_ID_SHOPPING)
            .setShortLabel(context.getString(R.string.shortcut_shopping_short))
            .setLongLabel(context.getString(R.string.shortcut_shopping_long))
            .setIcon(
                buildAdaptiveShortcutIcon(
                    context = context,
                    fgBitmap = null,
                    defaultDrawableRes = R.drawable.ic_shortcut_shopping_fg,
                    primaryColor = primary,
                    backgroundColor = background,
                )
            )
            .setIntent(
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("housekeepr://shopping/quick-add"),
                    context,
                    MainActivity::class.java,
                )
            )
            .setLongLived(true)
            .setCategories(setOf(SHARE_CATEGORY_SHOPPING))
            .setRank(0)
            .build()

        val taskShortcut = ShortcutInfoCompat.Builder(context, SHORTCUT_ID_TASK)
            .setShortLabel(context.getString(R.string.shortcut_task_short))
            .setLongLabel(context.getString(R.string.shortcut_task_long))
            .setIcon(
                buildAdaptiveShortcutIcon(
                    context = context,
                    fgBitmap = null,
                    defaultDrawableRes = R.drawable.ic_shortcut_task_fg,
                    primaryColor = primary,
                    backgroundColor = background,
                )
            )
            .setIntent(
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("housekeepr://tasks/new"),
                    context,
                    MainActivity::class.java,
                )
            )
            .setLongLived(true)
            .setCategories(setOf(SHARE_CATEGORY_TASK))
            .setRank(1)
            .build()

        val openGymShortcut = ShortcutInfoCompat.Builder(context, SHORTCUT_ID_OPEN_GYM)
            .setShortLabel(context.getString(R.string.shortcut_open_gym_short))
            .setLongLabel(context.getString(R.string.shortcut_open_gym_long))
            .setIcon(
                buildAdaptiveShortcutIcon(
                    context = context,
                    fgBitmap = null,
                    defaultDrawableRes = R.drawable.ic_shortcut_open_gym_fg,
                    primaryColor = primary,
                    backgroundColor = background,
                )
            )
            .setIntent(
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("housekeepr://opengym"),
                    context,
                    MainActivity::class.java,
                )
            )
            .setRank(2)
            .build()

        val fourthSlotShortcut = if (prefs.getBoolean(KEY_HAS_NEXT_WORKOUT, false)) {
            val shortLabel = prefs.getString(KEY_SHORT_LABEL, null)
                ?.takeIf { it.isNotBlank() }
                ?: context.getString(R.string.shortcut_next_workout_short)
            val longLabel = prefs.getString(KEY_LONG_LABEL, null)
                ?.takeIf { it.isNotBlank() }
                ?: shortLabel
            val hasFgBitmap = prefs.getBoolean(KEY_HAS_FG_BITMAP, false)
            val fgBitmap = if (hasFgBitmap) {
                val fgFile = File(context.noBackupFilesDir, FG_ICON_FILE)
                if (fgFile.exists()) BitmapFactory.decodeFile(fgFile.absolutePath) else null
            } else {
                null
            }
            val (nextPrimary, nextBg) = nextWorkoutColorsOverride ?: (primary to background)

            ShortcutInfoCompat.Builder(context, SHORTCUT_ID_NEXT_WORKOUT)
                .setShortLabel(shortLabel)
                .setLongLabel(longLabel)
                .setIcon(
                    buildAdaptiveShortcutIcon(
                        context = context,
                        fgBitmap = fgBitmap,
                        defaultDrawableRes = R.drawable.ic_shortcut_next_workout_fg,
                        primaryColor = nextPrimary,
                        backgroundColor = nextBg,
                    )
                )
                .setIntent(
                    Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse("housekeepr://opengym/start-next"),
                        context,
                        MainActivity::class.java,
                    )
                )
                .setRank(3)
                .build()
        } else {
            ShortcutInfoCompat.Builder(context, SHORTCUT_ID_MEDICATIONS)
                .setShortLabel(context.getString(R.string.shortcut_medications_short))
                .setLongLabel(context.getString(R.string.shortcut_medications_long))
                .setIcon(
                    buildAdaptiveShortcutIcon(
                        context = context,
                        fgBitmap = null,
                        defaultDrawableRes = R.drawable.ic_shortcut_medications_fg,
                        primaryColor = primary,
                        backgroundColor = background,
                    )
                )
                .setIntent(
                    Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse("housekeepr://medications"),
                        context,
                        MainActivity::class.java,
                    )
                )
                .setRank(3)
                .build()
        }

        runCatching {
            ShortcutManagerCompat.setDynamicShortcuts(
                context,
                listOf(shoppingShortcut, taskShortcut, openGymShortcut, fourthSlotShortcut),
            )
        }
    }

    fun clearNextWorkoutShortcut(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val fgFile = File(context.noBackupFilesDir, FG_ICON_FILE)
        if (fgFile.exists()) {
            runCatching { fgFile.delete() }
        }
        prefs.edit()
            .putBoolean(KEY_HAS_NEXT_WORKOUT, false)
            .putBoolean(KEY_HAS_FG_BITMAP, false)
            .apply()
        refreshDynamicShortcuts(context)
    }

    fun canPinShortcuts(context: Context): Boolean =
        ShortcutManagerCompat.isRequestPinShortcutSupported(context)

    fun pinShortcut(
        context: Context,
        id: String,
        shortLabel: String,
        longLabel: String,
        uriString: String,
        iconKey: String,
    ): Boolean {
        if (!canPinShortcuts(context)) return false
        val (primary, background) = resolveThemeColors(context)
        val drawableRes = when (iconKey) {
            "shopping" -> R.drawable.ic_shortcut_shopping_fg
            "task" -> R.drawable.ic_shortcut_task_fg
            "medications" -> R.drawable.ic_shortcut_medications_fg
            "coffee" -> R.drawable.ic_shortcut_coffee_fg
            "open_gym" -> R.drawable.ic_shortcut_open_gym_fg
            else -> R.drawable.ic_shortcut_open_gym_fg
        }
        val shortcut = ShortcutInfoCompat.Builder(context, "pinned_$id")
            .setShortLabel(shortLabel)
            .setLongLabel(longLabel)
            .setIcon(
                buildAdaptiveShortcutIcon(
                    context = context,
                    fgBitmap = null,
                    defaultDrawableRes = drawableRes,
                    primaryColor = primary,
                    backgroundColor = background,
                )
            )
            .setIntent(
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse(uriString),
                    context,
                    MainActivity::class.java,
                )
            )
            .build()
        return ShortcutManagerCompat.requestPinShortcut(context, shortcut, null)
    }

    private fun resolveThemeColors(context: Context): Pair<Int, Int> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val themeMode = prefs.getString(KEY_THEME_MODE, "system") ?: "system"
        val isDark = when (themeMode) {
            "dark" -> true
            "light" -> false
            else -> (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }

        return if (isDark) {
            val primary = prefs.getInt(KEY_DARK_PRIMARY, DEFAULT_DARK_PRIMARY)
            val background = prefs.getInt(KEY_DARK_BACKGROUND, DEFAULT_DARK_BACKGROUND)
            primary to background
        } else {
            val primary = prefs.getInt(KEY_LIGHT_PRIMARY, DEFAULT_LIGHT_PRIMARY)
            val background = prefs.getInt(KEY_LIGHT_BACKGROUND, DEFAULT_LIGHT_BACKGROUND)
            primary to background
        }
    }

    private fun buildAdaptiveShortcutIcon(
        context: Context,
        fgBitmap: Bitmap?,
        defaultDrawableRes: Int,
        primaryColor: Int,
        backgroundColor: Int,
    ): IconCompat {
        val size = 108
        val adaptive = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(adaptive)
        canvas.drawColor(backgroundColor)

        val inset = 24
        val dest = Rect(inset, inset, size - inset, size - inset)
        if (fgBitmap != null) {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
                colorFilter = PorterDuffColorFilter(primaryColor, PorterDuff.Mode.SRC_IN)
            }
            canvas.drawBitmap(fgBitmap, null, dest, paint)
        } else {
            val fgDrawable = ContextCompat.getDrawable(
                context,
                defaultDrawableRes,
            )?.mutate()
            if (fgDrawable != null) {
                fgDrawable.setTint(primaryColor)
                fgDrawable.bounds = dest
                fgDrawable.draw(canvas)
            }
        }
        return IconCompat.createWithAdaptiveBitmap(adaptive)
    }
}
