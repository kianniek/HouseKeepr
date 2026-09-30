package com.kianhamidi.housekeepr

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.SharedPreferences
import android.os.SystemClock
import android.preference.PreferenceManager
import org.json.JSONArray
import org.json.JSONObject
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.ZoneId
import java.util.*

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
                // Read persisted reminders from SharedPreferences used by Flutter
                // Try the FlutterSharedPreferences file first, fallback to default
                val prefsNames = listOf(
                    "FlutterSharedPreferences",
                    context.packageName + "_preferences"
                )
                val keys = listOf(
                    "flutter.scheduled_reminders_v1",
                    "scheduled_reminders_v1"
                )
                var remindersJson: String? = null
                for (name in prefsNames) {
                    try {
                        val sp = context.getSharedPreferences(name, Context.MODE_PRIVATE)
                        for (key in keys) {
                            if (sp.contains(key)) {
                                remindersJson = sp.getString(key, null)
                                break
                            }
                        }
                        if (remindersJson != null) break
                    } catch (e: Exception) {
                        // ignore
                    }
                }

                if (remindersJson == null) return

                val arr = try {
                    JSONArray(remindersJson)
                } catch (e: Exception) {
                    JSONArray()
                }
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

                for (i in 0 until arr.length()) {
                    try {
                        val obj = arr.getString(i)
                        val m = JSONObject(obj)
                        val taskId = m.optString("taskId", null) ?: continue
                        val atStr = m.optString("at", null) ?: continue
                        val title = m.optString("title", "Reminder")
                        val body = m.optString("body", "")
                        // parse ISO time in UTC and convert to local
                        val zdt = ZonedDateTime.parse(atStr, DateTimeFormatter.ISO_DATE_TIME).withZoneSameInstant(ZoneId.systemDefault())
                        val epochMillis = zdt.toInstant().toEpochMilli()

                        // If the time is still in future schedule an alarm
                        val now = System.currentTimeMillis()
                        if (epochMillis <= now) continue

                        val notifId = hashId(taskId)
                        val pi = buildPendingIntent(context, notifId, title, body)

                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis, pi)
                    } catch (e: Exception) {
                        // ignore malformed entry
                    }
                }
            }
        } catch (e: Exception) {
            // ignore
        }
    }

    private fun buildPendingIntent(context: Context, id: Int, title: String, body: String): PendingIntent {
        val intent = Intent(context, NotificationPublisher::class.java)
        intent.putExtra("title", title)
        intent.putExtra("body", body)
        intent.putExtra("notif_id", id)
        return PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun hashId(s: String): Int {
        var h = 0
        for (c in s) {
            h = ((h shl 5) - h) + c.code
            h = h and 0x7fffffff
        }
        return if (h == 0) 1 else (h % 0x7fffffff)
    }
}
