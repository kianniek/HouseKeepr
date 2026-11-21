package com.kianhamidi.housekeepr

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationChannelGroup
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt

class OpenGymLiveWorkoutService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var isForegroundStarted = false

    private val restTickRunnable = object : Runnable {
        override fun run() {
            val current = OpenGymLiveWorkoutStateStore.loadState(this@OpenGymLiveWorkoutService)
            if (current == null) {
                stopRestTicker()
                return
            }
            val nowMs = System.currentTimeMillis()
            if (!current.isPaused && current.restEndsAtMs > nowMs) {
                postNotificationUpdate(current, nowMs)
                val remainingMs = current.restEndsAtMs - nowMs
                val delayMs = ((remainingMs - 1L) % 1000L + 1L).coerceIn(250L, 1000L)
                handler.postDelayed(this, delayMs)
            } else if (!current.isPaused && current.restEndsAtMs > 0L) {
                val cleared = current.copy(restEndsAtMs = 0L, restTotalSeconds = 0)
                OpenGymLiveWorkoutStateStore.saveState(this@OpenGymLiveWorkoutService, cleared)
                stopRestTicker()
                postNotificationUpdate(cleared, nowMs)
            } else {
                stopRestTicker()
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START_OR_UPDATE
        when (action) {
            ACTION_STOP -> {
                stopLiveService()
                return START_NOT_STICKY
            }
            ACTION_START_OR_UPDATE -> {
                val stateJson = intent?.getStringExtra(EXTRA_STATE_JSON)
                val state = stateJson?.let { OpenGymLiveWorkoutState.fromJson(it) }
                    ?: OpenGymLiveWorkoutStateStore.loadState(this)
                if (state == null) {
                    stopLiveService()
                    return START_NOT_STICKY
                }
                OpenGymLiveWorkoutStateStore.saveState(this, state)
                applyAndShowState(state)
            }
            ACTION_SKIP_REST -> handleSkipRest()
            ACTION_ADD_REST_30 -> handleAddRest30()
            ACTION_TOGGLE_PAUSE -> handleTogglePause()
            ACTION_COMPLETE_NEXT_SET -> handleCompleteNextSet()
            else -> {
                val state = OpenGymLiveWorkoutStateStore.loadState(this)
                if (state != null) {
                    applyAndShowState(state)
                } else {
                    stopLiveService()
                    return START_NOT_STICKY
                }
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopRestTicker()
        if (isForegroundStarted) {
            runCatching {
                ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            }
            isForegroundStarted = false
        }
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
        super.onDestroy()
    }

    private fun applyAndShowState(state: OpenGymLiveWorkoutState) {
        val nowMs = System.currentTimeMillis()
        val notification = buildNotification(this, state, nowMs)
        if (!isForegroundStarted) {
            startForegroundSafely(notification)
        } else {
            notifySafely(this, notification)
        }
        if (!state.isPaused && state.restEndsAtMs > nowMs) {
            startRestTicker()
        } else {
            stopRestTicker()
        }
    }

    private fun postNotificationUpdate(state: OpenGymLiveWorkoutState, nowMs: Long) {
        val notification = buildNotification(this, state, nowMs)
        if (!isForegroundStarted) {
            startForegroundSafely(notification)
        } else {
            notifySafely(this, notification)
        }
    }

    private fun startForegroundSafely(notification: Notification) {
        createChannelIfNeeded(this)
        val fgType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
        } else {
            0
        }
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, fgType)
            isForegroundStarted = true
        } catch (_: Throwable) {
            isForegroundStarted = false
            notifySafely(this, notification)
            stopSelf()
        }
    }

    private fun stopLiveService() {
        stopRestTicker()
        OpenGymLiveWorkoutStateStore.clearState(this)
        if (isForegroundStarted) {
            runCatching {
                ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            }
            isForegroundStarted = false
        }
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
        stopSelf()
    }

    private fun startRestTicker() {
        handler.removeCallbacks(restTickRunnable)
        handler.postDelayed(restTickRunnable, 1000L)
    }

    private fun stopRestTicker() {
        handler.removeCallbacks(restTickRunnable)
    }

    private fun handleSkipRest() {
        val current = OpenGymLiveWorkoutStateStore.loadState(this) ?: return
        val updated = current.copy(restEndsAtMs = 0L, restTotalSeconds = 0)
        OpenGymLiveWorkoutStateStore.saveState(this, updated)
        NotificationManagerCompat.from(this).cancel(REST_ALERT_NOTIFICATION_ID)
        applyAndShowState(updated)
        OpenGymLiveWorkoutBridge.emitAction(this, "skip_rest")
    }

    private fun handleAddRest30() {
        val current = OpenGymLiveWorkoutStateStore.loadState(this) ?: return
        val nowMs = System.currentTimeMillis()
        val baseEnd = max(nowMs, current.restEndsAtMs)
        val nextEndsAtMs = baseEnd + 30_000L
        val nextRemainingSec = ceil((nextEndsAtMs - nowMs) / 1000.0).toInt().coerceAtLeast(1)
        val nextTotal = max(current.restTotalSeconds, nextRemainingSec)
        val updated = current.copy(
            restEndsAtMs = nextEndsAtMs,
            restTotalSeconds = nextTotal,
        )
        OpenGymLiveWorkoutStateStore.saveState(this, updated)
        applyAndShowState(updated)
        OpenGymLiveWorkoutBridge.emitAction(this, "add_rest", deltaSeconds = 30)
    }

    private fun handleTogglePause() {
        val current = OpenGymLiveWorkoutStateStore.loadState(this) ?: return
        val nowMs = System.currentTimeMillis()
        val updated = if (!current.isPaused) {
            NotificationManagerCompat.from(this).cancel(REST_ALERT_NOTIFICATION_ID)
            val elapsed = computeElapsedSeconds(current, nowMs)
            current.copy(
                isPaused = true,
                pausedAtMs = nowMs,
                elapsedSecondsAtUpdate = elapsed,
            )
        } else {
            val pauseSpanMs = if (current.pausedAtMs > 0L) {
                (nowMs - current.pausedAtMs).coerceAtLeast(0L)
            } else {
                0L
            }
            val nextStartMs = if (current.workoutStartedAtMs > 0L) {
                current.workoutStartedAtMs + pauseSpanMs
            } else {
                0L
            }
            val nextRestEndMs = if (current.restEndsAtMs > 0L) {
                current.restEndsAtMs + pauseSpanMs
            } else {
                0L
            }
            current.copy(
                isPaused = false,
                pausedAtMs = 0L,
                workoutStartedAtMs = nextStartMs,
                restEndsAtMs = nextRestEndMs,
            )
        }
        OpenGymLiveWorkoutStateStore.saveState(this, updated)
        applyAndShowState(updated)
        OpenGymLiveWorkoutBridge.emitAction(this, "toggle_pause")
    }

    private fun handleCompleteNextSet() {
        val current = OpenGymLiveWorkoutStateStore.loadState(this) ?: return
        if (!current.hasNextIncompleteSet && current.totalSets > 0 && current.completedSets >= current.totalSets) {
            applyAndShowState(current)
            return
        }
        val remainingQueue = if (current.nextSetsQueue.isNotEmpty()) {
            current.nextSetsQueue.drop(1)
        } else {
            emptyList()
        }
        val nextPreview = remainingQueue.firstOrNull()
        val nextCompleted = if (current.totalSets > 0) {
            (current.completedSets + 1).coerceAtMost(current.totalSets)
        } else {
            current.completedSets + 1
        }
        val hasMoreSets = nextPreview != null ||
            (current.totalSets > 0 && nextCompleted < current.totalSets)
        val updated = current.copy(
            completedSets = nextCompleted,
            exerciseName = nextPreview?.exerciseName ?: current.exerciseName,
            setSummary = nextPreview?.setSummary ?: if (!hasMoreSets) "All sets complete" else current.setSummary,
            hasNextIncompleteSet = hasMoreSets,
            nextSetsQueue = remainingQueue,
        )
        OpenGymLiveWorkoutStateStore.saveState(this, updated)
        applyAndShowState(updated)
        OpenGymLiveWorkoutBridge.emitAction(this, "complete_next_set")
    }

    companion object {
        const val CHANNEL_ID = "housekeepr_opengym_live"
        const val CHANNEL_NAME = "OpenGym Live Workout"
        const val NOTIFICATION_ID = 2002
        const val REST_ALERT_NOTIFICATION_ID = 2001

        const val ACTION_START_OR_UPDATE = "com.kianhamidi.housekeepr.OPENGYM_LIVE_UPDATE"
        const val ACTION_STOP = "com.kianhamidi.housekeepr.OPENGYM_LIVE_STOP"
        const val ACTION_SKIP_REST = "com.kianhamidi.housekeepr.OPENGYM_SKIP_REST"
        const val ACTION_ADD_REST_30 = "com.kianhamidi.housekeepr.OPENGYM_ADD_REST_30"
        const val ACTION_TOGGLE_PAUSE = "com.kianhamidi.housekeepr.OPENGYM_TOGGLE_PAUSE"
        const val ACTION_COMPLETE_NEXT_SET = "com.kianhamidi.housekeepr.OPENGYM_COMPLETE_NEXT_SET"

        private const val EXTRA_STATE_JSON = "extra_state_json"

        private const val REQ_CODE_SKIP_REST = 2101
        private const val REQ_CODE_ADD_REST = 2102
        private const val REQ_CODE_TOGGLE_PAUSE = 2103
        private const val REQ_CODE_COMPLETE_SET = 2104

        fun startOrUpdate(context: Context, state: OpenGymLiveWorkoutState) {
            val appCtx = context.applicationContext
            createChannelIfNeeded(appCtx)
            val intent = Intent(appCtx, OpenGymLiveWorkoutService::class.java).apply {
                action = ACTION_START_OR_UPDATE
                putExtra(EXTRA_STATE_JSON, state.toJson())
            }
            try {
                ContextCompat.startForegroundService(appCtx, intent)
            } catch (_: Throwable) {
                postFallbackNotification(appCtx, state)
            }
        }

        fun stop(context: Context) {
            val appCtx = context.applicationContext
            runCatching {
                appCtx.stopService(Intent(appCtx, OpenGymLiveWorkoutService::class.java))
            }
            NotificationManagerCompat.from(appCtx).cancel(NOTIFICATION_ID)
        }

        fun postFallbackNotification(context: Context, state: OpenGymLiveWorkoutState) {
            val appCtx = context.applicationContext
            createChannelIfNeeded(appCtx)
            val notification = buildNotification(appCtx, state, System.currentTimeMillis())
            notifySafely(appCtx, notification)
        }

        private fun notifySafely(context: Context, notification: Notification) {
            runCatching {
                NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
            }
        }

        fun createChannelIfNeeded(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannelGroup(
                NotificationChannelGroup("group_opengym", "OpenGym Fitness")
            )
            val existing = nm.getNotificationChannel(CHANNEL_ID)
            if (existing != null &&
                existing.importance >= NotificationManager.IMPORTANCE_DEFAULT &&
                existing.group == "group_opengym"
            ) {
                return
            }
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                existing?.importance?.coerceAtLeast(NotificationManager.IMPORTANCE_DEFAULT)
                    ?: NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Live workout progress and rest timer status chip for OpenGym"
                group = "group_opengym"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(channel)
        }

        fun buildNotification(
            context: Context,
            state: OpenGymLiveWorkoutState,
            nowMs: Long,
        ): Notification {
            val isResting = !state.isPaused && state.restEndsAtMs > nowMs
            val restRemainingSec = if (isResting) {
                ceil((state.restEndsAtMs - nowMs) / 1000.0).toInt().coerceAtLeast(1)
            } else {
                0
            }

            val shortChipText = when {
                state.isPaused -> "PAUSED"
                isResting -> formatShortChipDuration(restRemainingSec)
                state.totalSets > 0 -> {
                    val ratio = "${state.completedSets}/${state.totalSets}"
                    if (ratio.length <= 7) ratio else "${state.completedSets}s"
                }
                state.completedSets > 0 -> {
                    val label = "${state.completedSets} sets"
                    if (label.length <= 7) label else "${state.completedSets}s"
                }
                else -> "LIVE"
            }

            val contentTitle = when {
                state.isPaused -> "${state.workoutTitle} • Paused"
                isResting -> "Rest ${formatShortChipDuration(restRemainingSec)} • ${state.workoutTitle}"
                else -> state.workoutTitle
            }

            val contentText = when {
                state.exerciseName.isNotBlank() && state.setSummary.isNotBlank() ->
                    "${state.exerciseName} • ${state.setSummary}"
                state.exerciseName.isNotBlank() -> state.exerciseName
                state.totalSets > 0 -> "${state.completedSets}/${state.totalSets} sets completed"
                else -> "Workout in progress"
            }

            val elapsedSec = computeElapsedSeconds(state, nowMs)
            val elapsedFormatted = formatElapsedDuration(elapsedSec)
            val subText = if (state.totalSets > 0) {
                "$elapsedFormatted • ${state.completedSets}/${state.totalSets} sets"
            } else {
                elapsedFormatted
            }

            val tapIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("housekeepr://opengym/active"),
                context,
                MainActivity::class.java,
            ).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP,
                )
            }
            val tapPendingIntent = PendingIntent.getActivity(
                context,
                NOTIFICATION_ID,
                tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_open_gym)
                .setContentTitle(contentTitle)
                .setContentText(contentText)
                .setSubText(subText)
                .setContentIntent(tapPendingIntent)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setColorized(false)
                .setCategory(NotificationCompat.CATEGORY_WORKOUT)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                .setRequestPromotedOngoing(true)
                .setShortCriticalText(shortChipText)

            when {
                isResting -> {
                    builder
                        .setUsesChronometer(true)
                        .setChronometerCountDown(true)
                        .setWhen(state.restEndsAtMs)
                        .setShowWhen(true)
                }
                !state.isPaused && state.workoutStartedAtMs > 0L -> {
                    builder
                        .setUsesChronometer(true)
                        .setChronometerCountDown(false)
                        .setWhen(state.workoutStartedAtMs)
                        .setShowWhen(true)
                }
                else -> {
                    builder
                        .setUsesChronometer(false)
                        .setShowWhen(false)
                }
            }

            val progressMax: Int
            val progressCurrent: Int
            if (isResting) {
                progressMax = state.restTotalSeconds.coerceAtLeast(restRemainingSec).coerceAtLeast(1)
                progressCurrent = (progressMax - restRemainingSec).coerceIn(0, progressMax)
            } else {
                progressMax = state.totalSets.coerceAtLeast(0)
                progressCurrent = state.completedSets.coerceIn(0, progressMax)
            }

            if (progressMax > 0) {
                if (Build.VERSION.SDK_INT >= 36) {
                    val maxUnits = 100
                    val currentUnits =
                        ((progressCurrent.toFloat() / progressMax.toFloat()) * maxUnits)
                            .roundToInt()
                            .coerceIn(0, maxUnits)
                    val segment = NotificationCompat.ProgressStyle.Segment(maxUnits)
                        .setColor(state.accentColor)
                    val progressStyle = NotificationCompat.ProgressStyle()
                        .setProgressSegments(listOf(segment))
                        .setProgress(currentUnits)
                        .setStyledByProgress(true)
                    builder.setStyle(progressStyle)
                } else {
                    builder.setProgress(progressMax, progressCurrent, false)
                }
            }

            if (isResting) {
                builder.addAction(
                    0,
                    "Skip Rest",
                    serviceActionPendingIntent(context, ACTION_SKIP_REST, REQ_CODE_SKIP_REST),
                )
                builder.addAction(
                    0,
                    "+30s",
                    serviceActionPendingIntent(context, ACTION_ADD_REST_30, REQ_CODE_ADD_REST),
                )
            } else {
                builder.addAction(
                    0,
                    if (state.isPaused) "Resume" else "Pause",
                    serviceActionPendingIntent(context, ACTION_TOGGLE_PAUSE, REQ_CODE_TOGGLE_PAUSE),
                )
                if (state.hasNextIncompleteSet) {
                    builder.addAction(
                        0,
                        "Complete Next Set",
                        serviceActionPendingIntent(
                            context,
                            ACTION_COMPLETE_NEXT_SET,
                            REQ_CODE_COMPLETE_SET,
                        ),
                    )
                }
            }

            return builder.build()
        }

        private fun serviceActionPendingIntent(
            context: Context,
            action: String,
            requestCode: Int,
        ): PendingIntent {
            val intent = Intent(context, OpenGymLiveWorkoutService::class.java).apply {
                this.action = action
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PendingIntent.getForegroundService(context, requestCode, intent, flags)
            } else {
                PendingIntent.getService(context, requestCode, intent, flags)
            }
        }

        private fun computeElapsedSeconds(state: OpenGymLiveWorkoutState, nowMs: Long): Int {
            if (state.isPaused) {
                if (state.pausedAtMs > 0L && state.workoutStartedAtMs > 0L) {
                    return ((state.pausedAtMs - state.workoutStartedAtMs) / 1000L)
                        .toInt()
                        .coerceAtLeast(0)
                }
                return state.elapsedSecondsAtUpdate.coerceAtLeast(0)
            }
            if (state.workoutStartedAtMs > 0L) {
                return ((nowMs - state.workoutStartedAtMs) / 1000L)
                    .toInt()
                    .coerceAtLeast(0)
            }
            return state.elapsedSecondsAtUpdate.coerceAtLeast(0)
        }

        private fun formatShortChipDuration(totalSeconds: Int): String {
            val clamped = totalSeconds.coerceAtLeast(0)
            if (clamped >= 3600) {
                val mins = ceil(clamped / 60.0).toInt()
                return "${mins}m"
            }
            val mins = clamped / 60
            val secs = clamped % 60
            return "$mins:${secs.toString().padStart(2, '0')}"
        }

        private fun formatElapsedDuration(totalSeconds: Int): String {
            val clamped = totalSeconds.coerceAtLeast(0)
            val hours = clamped / 3600
            val minutes = (clamped % 3600) / 60
            val seconds = clamped % 60
            val mm = minutes.toString().padStart(2, '0')
            val ss = seconds.toString().padStart(2, '0')
            return if (hours > 0) "$hours:$mm:$ss" else "$minutes:$ss"
        }
    }
}
