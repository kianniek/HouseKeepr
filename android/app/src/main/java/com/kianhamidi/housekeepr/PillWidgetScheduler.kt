package com.kianhamidi.housekeepr

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * Handles midnight reset scheduling and on-device daily data resolution for [PillWidget]
 * so the widget resets accurately at midnight (and on date/time/boot changes) even when
 * the Flutter app is closed.
 */
object PillWidgetScheduler {
    private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val DATA_KEY = "pill_widget_data"
    private const val MEDS_KEY = "flutter.personal_medications_list"
    private const val DOSE_RECORDS_KEY = "flutter.personal_dose_records_map"
    private const val MIDNIGHT_REQUEST_CODE = 4401

    fun todayDateKey(): String =
        LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE)

    /**
     * Schedules an alarm for the next local midnight (00:00:00) if at least one [PillWidget]
     * is currently placed on the home screen.
     */
    fun scheduleNextMidnightReset(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, PillWidget::class.java))
        if (ids.isEmpty()) {
            cancelMidnightReset(context)
            return
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val nextMidnightMillis = LocalDate.now()
            .plusDays(1)
            .atStartOfDay(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()

        val pendingIntent = buildMidnightPendingIntent(context)
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
        if (canExact) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                nextMidnightMillis,
                pendingIntent,
            )
        } else {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                nextMidnightMillis,
                pendingIntent,
            )
        }
    }

    /**
     * Cancels any pending midnight reset alarm (called when the last [PillWidget] is removed).
     */
    fun cancelMidnightReset(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarmManager.cancel(buildMidnightPendingIntent(context))
    }

    /**
     * Returns today's pill widget JSON payload. If the cached `pill_widget_data` belongs to a
     * different `dateKey`, recomputes today's schedule and dose status from Flutter's persisted
     * medication data (or falls back to resetting taken flags to `false`) and persists it.
     */
    fun resolveTodayData(context: Context): JSONObject {
        val homePrefs = context.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE)
        val rawJson = homePrefs.getString(DATA_KEY, null)
        val today = LocalDate.now()
        val todayKey = today.format(DateTimeFormatter.ISO_LOCAL_DATE)

        val existing = parseJsonObject(rawJson)
        if (existing != null && existing.optString("dateKey") == todayKey) {
            return existing
        }

        val defaultTitle = context.getString(R.string.pills)
        val title = existing?.optString("title", defaultTitle)?.ifBlank { defaultTitle } ?: defaultTitle
        val recomputed = computeFromFlutterPrefs(context, today, todayKey, title)
            ?: resetExistingFallback(existing, todayKey, title)

        homePrefs.edit().putString(DATA_KEY, recomputed.toString()).apply()
        return recomputed
    }

    private fun buildMidnightPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, PillWidget::class.java).apply {
            action = PillWidget.ACTION_MIDNIGHT_RESET
        }
        return PendingIntent.getBroadcast(
            context,
            MIDNIGHT_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun parseJsonObject(raw: String?): JSONObject? {
        if (raw.isNullOrBlank()) return null
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            null
        }
    }

    private fun resetExistingFallback(
        existing: JSONObject?,
        todayKey: String,
        title: String,
    ): JSONObject {
        return JSONObject().apply {
            put("title", title)
            put("dateKey", todayKey)
            put("hasMorning", existing?.optBoolean("hasMorning", false) ?: false)
            put("morningTaken", false)
            put("hasEvening", existing?.optBoolean("hasEvening", false) ?: false)
            put("eveningTaken", false)
            put("morningCount", existing?.optInt("morningCount", 0) ?: 0)
            put("eveningCount", existing?.optInt("eveningCount", 0) ?: 0)
        }
    }

    private fun computeFromFlutterPrefs(
        context: Context,
        today: LocalDate,
        todayKey: String,
        title: String,
    ): JSONObject? {
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val medsJson = flutterPrefs.getString(MEDS_KEY, null) ?: return null
        if (medsJson.isBlank()) return null

        return try {
            val meds = JSONArray(medsJson)
            val recordsRaw = flutterPrefs.getString(DOSE_RECORDS_KEY, null)
            val records = parseJsonObject(recordsRaw) ?: JSONObject()

            var morningCount = 0
            var morningTakenCount = 0
            var eveningCount = 0
            var eveningTakenCount = 0

            for (i in 0 until meds.length()) {
                val med = meds.optJSONObject(i) ?: continue
                if (!isMedicationScheduledForDate(med, today)) continue

                val medId = med.optString("id", "")
                if (medId.isEmpty()) continue

                val times = med.optJSONArray("notificationTimes") ?: continue
                for (j in 0 until times.length()) {
                    val timeObj = times.optJSONObject(j) ?: continue
                    val hour = timeObj.optInt("hour", 8)
                    val minute = timeObj.optInt("minute", 0)
                    val slotName = timeObj.optString("slot", "").ifEmpty {
                        if (hour < 17) "morning" else "evening"
                    }

                    val hh = hour.toString().padStart(2, '0')
                    val mm = minute.toString().padStart(2, '0')
                    val doseId = "${medId}_${todayKey}_$hh$mm"
                    val record = records.optJSONObject(doseId)
                    val isTaken = record?.optString("status") == "taken"

                    if (slotName == "evening") {
                        eveningCount++
                        if (isTaken) eveningTakenCount++
                    } else {
                        morningCount++
                        if (isTaken) morningTakenCount++
                    }
                }
            }

            val hasMorning = morningCount > 0
            val hasEvening = eveningCount > 0
            JSONObject().apply {
                put("title", title)
                put("dateKey", todayKey)
                put("hasMorning", hasMorning)
                put("morningTaken", hasMorning && morningTakenCount == morningCount)
                put("hasEvening", hasEvening)
                put("eveningTaken", hasEvening && eveningTakenCount == eveningCount)
                put("morningCount", morningCount)
                put("eveningCount", eveningCount)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun isMedicationScheduledForDate(med: JSONObject, targetDate: LocalDate): Boolean {
        if (!med.optBoolean("isActive", true)) return false

        val startDate = parseLocalDatePrefix(med.optString("startDate", "")) ?: targetDate
        if (targetDate.isBefore(startDate)) return false

        val endRaw = med.optString("endDate", "")
        if (endRaw.isNotEmpty() && endRaw != "null") {
            val endDate = parseLocalDatePrefix(endRaw)
            if (endDate != null && targetDate.isAfter(endDate)) return false
        }

        return when (med.optString("recurrenceType", "daily")) {
            "daily" -> true
            "specificDaysOfWeek" -> {
                val days = med.optJSONArray("daysOfWeek") ?: return false
                val targetWeekday = targetDate.dayOfWeek.value // 1 = Monday .. 7 = Sunday
                var matched = false
                for (i in 0 until days.length()) {
                    if (days.optInt(i) == targetWeekday) {
                        matched = true
                        break
                    }
                }
                matched
            }
            "intervalDays" -> {
                val interval = med.optInt("intervalDays", 1)
                val diff = ChronoUnit.DAYS.between(startDate, targetDate)
                diff >= 0 && interval > 0 && (diff % interval == 0L)
            }
            else -> true
        }
    }

    private fun parseLocalDatePrefix(isoString: String): LocalDate? {
        if (isoString.length < 10) return null
        return try {
            LocalDate.parse(isoString.substring(0, 10), DateTimeFormatter.ISO_LOCAL_DATE)
        } catch (_: Exception) {
            null
        }
    }
}
