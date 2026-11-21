package com.kianhamidi.housekeepr

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class NextSetPreview(
    val exerciseName: String,
    val setSummary: String,
) {
    fun toJsonObject(): JSONObject = JSONObject().apply {
        put("exerciseName", exerciseName)
        put("setSummary", setSummary)
    }

    companion object {
        fun fromMap(map: Map<*, *>): NextSetPreview? {
            val exerciseName = (map["exerciseName"] as? String)?.trim().orEmpty()
            val setSummary = (map["setSummary"] as? String)?.trim().orEmpty()
            if (exerciseName.isEmpty() && setSummary.isEmpty()) return null
            return NextSetPreview(exerciseName = exerciseName, setSummary = setSummary)
        }

        fun fromJsonObject(obj: JSONObject): NextSetPreview = NextSetPreview(
            exerciseName = obj.optString("exerciseName", ""),
            setSummary = obj.optString("setSummary", ""),
        )
    }
}

data class OpenGymLiveWorkoutState(
    val workoutTitle: String,
    val exerciseName: String,
    val setSummary: String,
    val completedSets: Int,
    val totalSets: Int,
    val workoutStartedAtMs: Long,
    val elapsedSecondsAtUpdate: Int,
    val isPaused: Boolean,
    val pausedAtMs: Long,
    val restEndsAtMs: Long,
    val restTotalSeconds: Int,
    val hasNextIncompleteSet: Boolean,
    val nextSetsQueue: List<NextSetPreview>,
    val accentColor: Int = DEFAULT_ACCENT_COLOR,
) {
    fun toJson(): String {
        val queueArray = JSONArray()
        for (item in nextSetsQueue) {
            queueArray.put(item.toJsonObject())
        }
        return JSONObject().apply {
            put("workoutTitle", workoutTitle)
            put("exerciseName", exerciseName)
            put("setSummary", setSummary)
            put("completedSets", completedSets)
            put("totalSets", totalSets)
            put("workoutStartedAtMs", workoutStartedAtMs)
            put("elapsedSecondsAtUpdate", elapsedSecondsAtUpdate)
            put("isPaused", isPaused)
            put("pausedAtMs", pausedAtMs)
            put("restEndsAtMs", restEndsAtMs)
            put("restTotalSeconds", restTotalSeconds)
            put("hasNextIncompleteSet", hasNextIncompleteSet)
            put("nextSetsQueue", queueArray)
            put("accentColor", accentColor)
        }.toString()
    }

    companion object {
        const val DEFAULT_ACCENT_COLOR: Int = 0xFFC65102.toInt()

        fun fromMap(map: Map<*, *>): OpenGymLiveWorkoutState {
            val rawQueue = map["nextSetsQueue"] as? List<*> ?: emptyList<Any?>()
            val parsedQueue = rawQueue.mapNotNull { item ->
                (item as? Map<*, *>)?.let { NextSetPreview.fromMap(it) }
            }
            return OpenGymLiveWorkoutState(
                workoutTitle = (map["workoutTitle"] as? String)?.takeIf { it.isNotBlank() } ?: "Workout",
                exerciseName = (map["exerciseName"] as? String).orEmpty(),
                setSummary = (map["setSummary"] as? String).orEmpty(),
                completedSets = (map["completedSets"] as? Number)?.toInt()?.coerceAtLeast(0) ?: 0,
                totalSets = (map["totalSets"] as? Number)?.toInt()?.coerceAtLeast(0) ?: 0,
                workoutStartedAtMs = (map["workoutStartedAtMs"] as? Number)?.toLong() ?: 0L,
                elapsedSecondsAtUpdate = (map["elapsedSecondsAtUpdate"] as? Number)?.toInt()?.coerceAtLeast(0) ?: 0,
                isPaused = (map["isPaused"] as? Boolean) ?: false,
                pausedAtMs = (map["pausedAtMs"] as? Number)?.toLong() ?: 0L,
                restEndsAtMs = (map["restEndsAtMs"] as? Number)?.toLong() ?: 0L,
                restTotalSeconds = (map["restTotalSeconds"] as? Number)?.toInt()?.coerceAtLeast(0) ?: 0,
                hasNextIncompleteSet = (map["hasNextIncompleteSet"] as? Boolean) ?: false,
                nextSetsQueue = parsedQueue,
                accentColor = (map["accentColor"] as? Number)?.toInt() ?: DEFAULT_ACCENT_COLOR,
            )
        }

        fun fromJson(json: String): OpenGymLiveWorkoutState? {
            return runCatching {
                val obj = JSONObject(json)
                val queueArray = obj.optJSONArray("nextSetsQueue") ?: JSONArray()
                val queue = mutableListOf<NextSetPreview>()
                for (i in 0 until queueArray.length()) {
                    val item = queueArray.optJSONObject(i) ?: continue
                    queue.add(NextSetPreview.fromJsonObject(item))
                }
                OpenGymLiveWorkoutState(
                    workoutTitle = obj.optString("workoutTitle", "Workout").ifBlank { "Workout" },
                    exerciseName = obj.optString("exerciseName", ""),
                    setSummary = obj.optString("setSummary", ""),
                    completedSets = obj.optInt("completedSets", 0).coerceAtLeast(0),
                    totalSets = obj.optInt("totalSets", 0).coerceAtLeast(0),
                    workoutStartedAtMs = obj.optLong("workoutStartedAtMs", 0L),
                    elapsedSecondsAtUpdate = obj.optInt("elapsedSecondsAtUpdate", 0).coerceAtLeast(0),
                    isPaused = obj.optBoolean("isPaused", false),
                    pausedAtMs = obj.optLong("pausedAtMs", 0L),
                    restEndsAtMs = obj.optLong("restEndsAtMs", 0L),
                    restTotalSeconds = obj.optInt("restTotalSeconds", 0).coerceAtLeast(0),
                    hasNextIncompleteSet = obj.optBoolean("hasNextIncompleteSet", false),
                    nextSetsQueue = queue,
                    accentColor = obj.optInt("accentColor", DEFAULT_ACCENT_COLOR),
                )
            }.getOrNull()
        }
    }
}

object OpenGymLiveWorkoutStateStore {
    private const val PREFS_NAME = "open_gym_live_workout_prefs"
    private const val KEY_STATE = "live_state_json"
    private const val KEY_PENDING_ACTIONS = "pending_actions_json"

    @Synchronized
    fun saveState(context: Context, state: OpenGymLiveWorkoutState) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_STATE, state.toJson()).apply()
    }

    @Synchronized
    fun loadState(context: Context): OpenGymLiveWorkoutState? {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_STATE, null) ?: return null
        return OpenGymLiveWorkoutState.fromJson(raw)
    }

    @Synchronized
    fun clearState(context: Context) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY_STATE).apply()
    }

    @Synchronized
    fun enqueuePendingAction(context: Context, actionMap: Map<String, Any>) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existingRaw = prefs.getString(KEY_PENDING_ACTIONS, null)
        val array = runCatching {
            if (existingRaw != null) JSONArray(existingRaw) else JSONArray()
        }.getOrElse { JSONArray() }

        val obj = JSONObject()
        for ((k, v) in actionMap) {
            obj.put(k, v)
        }
        array.put(obj)
        prefs.edit().putString(KEY_PENDING_ACTIONS, array.toString()).apply()
    }

    @Synchronized
    fun consumePendingActions(context: Context): List<Map<String, Any>> {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING_ACTIONS, null)
        if (raw.isNullOrBlank()) return emptyList()
        prefs.edit().remove(KEY_PENDING_ACTIONS).apply()

        val out = mutableListOf<Map<String, Any>>()
        val array = runCatching { JSONArray(raw) }.getOrNull() ?: return emptyList()
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            val map = mutableMapOf<String, Any>()
            val action = obj.optString("action", "")
            if (action.isEmpty()) continue
            map["action"] = action
            map["timestampMs"] = obj.optLong("timestampMs", System.currentTimeMillis())
            if (obj.has("deltaSeconds")) {
                map["deltaSeconds"] = obj.optInt("deltaSeconds", 0)
            }
            out.add(map)
        }
        return out
    }

    @Synchronized
    fun clearPendingActions(context: Context) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY_PENDING_ACTIONS).apply()
    }
}
