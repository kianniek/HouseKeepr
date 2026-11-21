package com.kianhamidi.housekeepr

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationChannelGroup
import android.app.PendingIntent
import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class NotificationPublisher : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val title = intent.getStringExtra("title") ?: "Reminder"
            val body = intent.getStringExtra("body") ?: ""
            val id = intent.getIntExtra("notif_id", 0)

            val tapIntent = Intent(context, MainActivity::class.java)
            tapIntent.putExtra("notification_action", "open_tasks")
            tapIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val tapPendingIntent = PendingIntent.getActivity(
                context,
                id,
                tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Ensure channel exists (channel creation is idempotent)
            createNotificationChannelIfNeeded(context)

            val builder = NotificationCompat.Builder(context, "housekeepr_task_reminders")
                .setSmallIcon(R.drawable.ic_launcher_monochrome)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(tapPendingIntent)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)

            with(NotificationManagerCompat.from(context)) {
                notify(id, builder.build())
            }
        } catch (e: Exception) {
            // swallow
        }
    }

    private fun createNotificationChannelIfNeeded(context: Context) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                nm.createNotificationChannelGroup(
                    NotificationChannelGroup(
                        "group_household_tasks",
                        "Household & Tasks"
                    )
                )
                val channel = android.app.NotificationChannel(
                    "housekeepr_task_reminders",
                    "Task Reminders",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Scheduled alerts for tasks with a specific reminder time"
                    group = "group_household_tasks"
                }
                nm.createNotificationChannel(channel)
            }
        } catch (e: Exception) {
            // ignore
        }
    }
}
