package com.kianhamidi.housekeepr

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Percentage
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneOffset
import kotlin.reflect.KClass

class HealthConnectBridge(private val activity: FlutterFragmentActivity) {

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var requestedPermissionSet: Set<String> = emptySet()

    private val permissionLauncher: ActivityResultLauncher<Set<String>> =
        activity.registerForActivityResult(
            PermissionController.createRequestPermissionResultContract()
        ) { granted ->
            val result = pendingPermissionResult
            pendingPermissionResult = null
            if (result != null) {
                val allGranted = granted.containsAll(requestedPermissionSet)
                result.success(
                    mapOf(
                        "granted" to allGranted,
                        "grantedPermissions" to granted.toList(),
                    )
                )
            }
        }

    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            when (call.method) {
                "getSdkStatus" -> result.success("unavailable")
                "hasPermissions" -> result.success(false)
                else -> result.error(
                    "UNSUPPORTED_SDK",
                    "Health Connect requires Android 8.0 (API 26) or higher.",
                    null,
                )
            }
            return
        }

        when (call.method) {
            "getSdkStatus" -> result.success(getSdkStatusString())
            "openHealthConnectSettings" -> {
                openHealthConnectSettings()
                result.success(true)
            }
            "hasPermissions" -> handleHasPermissions(call, result)
            "requestPermissions" -> handleRequestPermissions(call, result)
            "writeExerciseSession" -> handleWriteExerciseSession(call, result)
            "writeWeight" -> handleWriteWeight(call, result)
            "writeBodyFat" -> handleWriteBodyFat(call, result)
            "readRecords" -> handleReadRecords(call, result)
            else -> result.notImplemented()
        }
    }

    private fun getSdkStatusString(): String {
        val status = HealthConnectClient.getSdkStatus(activity, PROVIDER_PACKAGE)
        return when (status) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "providerUpdateRequired"
            else -> "unavailable"
        }
    }

    private fun getClientOrNull(): HealthConnectClient? {
        if (HealthConnectClient.getSdkStatus(activity, PROVIDER_PACKAGE) !=
            HealthConnectClient.SDK_AVAILABLE
        ) {
            return null
        }
        return HealthConnectClient.getOrCreate(activity)
    }

    private fun openHealthConnectSettings() {
        val status = HealthConnectClient.getSdkStatus(activity, PROVIDER_PACKAGE)
        if (status == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
            val uri = Uri.parse(
                "market://details?id=$PROVIDER_PACKAGE&url=healthconnect%3A%2F%2Fonboarding"
            )
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                setPackage("com.android.vending")
                putExtra("overlay", true)
                putExtra("callerId", activity.packageName)
            }
            runCatching { activity.startActivity(intent) }
            return
        }
        val settingsIntent = Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
        runCatching { activity.startActivity(settingsIntent) }
    }

    private fun mapPermissionStrings(keys: List<String>?): Set<String> {
        val out = mutableSetOf<String>()
        for (key in keys.orEmpty()) {
            when (key) {
                "read_exercise" -> out.add(HealthPermission.getReadPermission(ExerciseSessionRecord::class))
                "write_exercise" -> out.add(HealthPermission.getWritePermission(ExerciseSessionRecord::class))
                "read_weight" -> out.add(HealthPermission.getReadPermission(WeightRecord::class))
                "write_weight" -> out.add(HealthPermission.getWritePermission(WeightRecord::class))
                "read_body_fat" -> out.add(HealthPermission.getReadPermission(BodyFatRecord::class))
                "write_body_fat" -> out.add(HealthPermission.getWritePermission(BodyFatRecord::class))
                "read_active_calories" -> out.add(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class))
                "read_total_calories" -> out.add(HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class))
                "read_heart_rate" -> out.add(HealthPermission.getReadPermission(HeartRateRecord::class))
            }
        }
        return out
    }

    private fun handleHasPermissions(call: MethodCall, result: MethodChannel.Result) {
        val client = getClientOrNull()
        if (client == null) {
            result.success(false)
            return
        }
        val requested = mapPermissionStrings(call.argument<List<String>>("permissions"))
        if (requested.isEmpty()) {
            result.success(true)
            return
        }
        activity.lifecycleScope.launch {
            try {
                val granted = client.permissionController.getGrantedPermissions()
                result.success(granted.containsAll(requested))
            } catch (e: Exception) {
                result.error("PERMISSION_CHECK_FAILED", e.message, null)
            }
        }
    }

    private fun handleRequestPermissions(call: MethodCall, result: MethodChannel.Result) {
        val client = getClientOrNull()
        if (client == null) {
            result.error("HC_UNAVAILABLE", "Health Connect is not available.", null)
            return
        }
        val requested = mapPermissionStrings(call.argument<List<String>>("permissions"))
        if (requested.isEmpty()) {
            result.success(mapOf("granted" to true, "grantedPermissions" to emptyList<String>()))
            return
        }
        if (pendingPermissionResult != null) {
            result.error("PERMISSION_IN_PROGRESS", "A permission request is already active.", null)
            return
        }
        activity.lifecycleScope.launch {
            try {
                val alreadyGranted = client.permissionController.getGrantedPermissions()
                if (alreadyGranted.containsAll(requested)) {
                    result.success(
                        mapOf(
                            "granted" to true,
                            "grantedPermissions" to alreadyGranted.toList(),
                        )
                    )
                    return@launch
                }
                requestedPermissionSet = requested
                pendingPermissionResult = result
                permissionLauncher.launch(requested)
            } catch (e: Exception) {
                pendingPermissionResult = null
                result.error("PERMISSION_REQUEST_FAILED", e.message, null)
            }
        }
    }

    private fun handleWriteExerciseSession(call: MethodCall, result: MethodChannel.Result) {
        val client = getClientOrNull() ?: return result.error("HC_UNAVAILABLE", "Health Connect unavailable.", null)
        val id = call.argument<String>("id") ?: return result.error("INVALID_ARGS", "Missing id", null)
        val title = call.argument<String>("title") ?: "Workout"
        val startIso = call.argument<String>("startIso") ?: return result.error("INVALID_ARGS", "Missing startIso", null)
        val endIso = call.argument<String>("endIso") ?: return result.error("INVALID_ARGS", "Missing endIso", null)
        val notes = call.argument<String>("notes")

        activity.lifecycleScope.launch {
            try {
                val startTime = Instant.parse(startIso)
                var endTime = Instant.parse(endIso)
                if (!endTime.isAfter(startTime)) {
                    endTime = startTime.plusSeconds(60)
                }
                val record = ExerciseSessionRecord(
                    startTime = startTime,
                    startZoneOffset = ZoneOffset.UTC,
                    endTime = endTime,
                    endZoneOffset = ZoneOffset.UTC,
                    exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING,
                    title = title,
                    notes = notes,
                    metadata = Metadata.manualEntry(
                        clientRecordId = "opengym_workout_$id",
                        device = Device(type = Device.TYPE_PHONE),
                    ),
                )
                val response = client.insertRecords(listOf(record))
                result.success(response.recordIdsList.firstOrNull() ?: id)
            } catch (e: Exception) {
                result.error("WRITE_EXERCISE_FAILED", e.message, null)
            }
        }
    }

    private fun handleWriteWeight(call: MethodCall, result: MethodChannel.Result) {
        val client = getClientOrNull() ?: return result.error("HC_UNAVAILABLE", "Health Connect unavailable.", null)
        val id = call.argument<String>("id") ?: return result.error("INVALID_ARGS", "Missing id", null)
        val weightKg = call.argument<Double>("weightKg") ?: return result.error("INVALID_ARGS", "Missing weightKg", null)
        val timeIso = call.argument<String>("timeIso") ?: return result.error("INVALID_ARGS", "Missing timeIso", null)

        activity.lifecycleScope.launch {
            try {
                val time = Instant.parse(timeIso)
                val record = WeightRecord(
                    time = time,
                    zoneOffset = ZoneOffset.UTC,
                    weight = Mass.kilograms(weightKg),
                    metadata = Metadata.manualEntry(clientRecordId = "opengym_weight_$id"),
                )
                val response = client.insertRecords(listOf(record))
                result.success(response.recordIdsList.firstOrNull() ?: id)
            } catch (e: Exception) {
                result.error("WRITE_WEIGHT_FAILED", e.message, null)
            }
        }
    }

    private fun handleWriteBodyFat(call: MethodCall, result: MethodChannel.Result) {
        val client = getClientOrNull() ?: return result.error("HC_UNAVAILABLE", "Health Connect unavailable.", null)
        val id = call.argument<String>("id") ?: return result.error("INVALID_ARGS", "Missing id", null)
        val percentage = call.argument<Double>("percentage") ?: return result.error("INVALID_ARGS", "Missing percentage", null)
        val timeIso = call.argument<String>("timeIso") ?: return result.error("INVALID_ARGS", "Missing timeIso", null)

        activity.lifecycleScope.launch {
            try {
                val time = Instant.parse(timeIso)
                val record = BodyFatRecord(
                    time = time,
                    zoneOffset = ZoneOffset.UTC,
                    percentage = Percentage(percentage.coerceIn(0.0, 100.0)),
                    metadata = Metadata.manualEntry(clientRecordId = "opengym_bodyfat_$id"),
                )
                val response = client.insertRecords(listOf(record))
                result.success(response.recordIdsList.firstOrNull() ?: id)
            } catch (e: Exception) {
                result.error("WRITE_BODY_FAT_FAILED", e.message, null)
            }
        }
    }

    private fun handleReadRecords(call: MethodCall, result: MethodChannel.Result) {
        val client = getClientOrNull() ?: return result.error("HC_UNAVAILABLE", "Health Connect unavailable.", null)
        val startIso = call.argument<String>("startIso") ?: return result.error("INVALID_ARGS", "Missing startIso", null)
        val endIso = call.argument<String>("endIso") ?: return result.error("INVALID_ARGS", "Missing endIso", null)

        activity.lifecycleScope.launch {
            try {
                val startTime = Instant.parse(startIso)
                val endTime = Instant.parse(endIso)
                val filter = TimeRangeFilter.between(startTime, endTime)
                val granted = client.permissionController.getGrantedPermissions()

                val exercises = if (granted.contains(HealthPermission.getReadPermission(ExerciseSessionRecord::class))) {
                    readAll(client, ExerciseSessionRecord::class, filter).map { rec ->
                        mapOf(
                            "id" to rec.metadata.id,
                            "title" to (rec.title ?: "Workout"),
                            "exerciseType" to rec.exerciseType,
                            "startIso" to rec.startTime.toString(),
                            "endIso" to rec.endTime.toString(),
                            "sourcePackage" to rec.metadata.dataOrigin.packageName,
                            "isExternal" to (rec.metadata.dataOrigin.packageName != activity.packageName),
                        )
                    }
                } else {
                    emptyList()
                }

                val weights = if (granted.contains(HealthPermission.getReadPermission(WeightRecord::class))) {
                    readAll(client, WeightRecord::class, filter).map { rec ->
                        mapOf(
                            "id" to rec.metadata.id,
                            "weightKg" to rec.weight.inKilograms,
                            "timeIso" to rec.time.toString(),
                            "sourcePackage" to rec.metadata.dataOrigin.packageName,
                        )
                    }
                } else {
                    emptyList()
                }

                val bodyFats = if (granted.contains(HealthPermission.getReadPermission(BodyFatRecord::class))) {
                    readAll(client, BodyFatRecord::class, filter).map { rec ->
                        mapOf(
                            "id" to rec.metadata.id,
                            "percentage" to rec.percentage.value,
                            "timeIso" to rec.time.toString(),
                            "sourcePackage" to rec.metadata.dataOrigin.packageName,
                        )
                    }
                } else {
                    emptyList()
                }

                val activeCalories = if (granted.contains(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class))) {
                    readAll(client, ActiveCaloriesBurnedRecord::class, filter).map { rec ->
                        mapOf(
                            "kcal" to rec.energy.inKilocalories,
                            "startIso" to rec.startTime.toString(),
                            "endIso" to rec.endTime.toString(),
                        )
                    }
                } else {
                    emptyList()
                }

                val totalCalories = if (granted.contains(HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class))) {
                    readAll(client, TotalCaloriesBurnedRecord::class, filter).map { rec ->
                        mapOf(
                            "kcal" to rec.energy.inKilocalories,
                            "startIso" to rec.startTime.toString(),
                            "endIso" to rec.endTime.toString(),
                        )
                    }
                } else {
                    emptyList()
                }

                val heartRateSamples = if (granted.contains(HealthPermission.getReadPermission(HeartRateRecord::class))) {
                    readAll(client, HeartRateRecord::class, filter).flatMap { rec ->
                        rec.samples.map { sample ->
                            mapOf(
                                "bpm" to sample.beatsPerMinute.toInt(),
                                "timeIso" to sample.time.toString(),
                            )
                        }
                    }
                } else {
                    emptyList()
                }

                result.success(
                    mapOf(
                        "exercises" to exercises,
                        "weights" to weights,
                        "bodyFats" to bodyFats,
                        "activeCalories" to activeCalories,
                        "totalCalories" to totalCalories,
                        "heartRateSamples" to heartRateSamples,
                    )
                )
            } catch (e: Exception) {
                result.error("READ_RECORDS_FAILED", e.message, null)
            }
        }
    }

    private suspend fun <T : Record> readAll(
        client: HealthConnectClient,
        recordType: KClass<T>,
        filter: TimeRangeFilter,
    ): List<T> {
        val collected = mutableListOf<T>()
        var pageToken: String? = null
        do {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = recordType,
                    timeRangeFilter = filter,
                    pageToken = pageToken,
                )
            )
            collected.addAll(response.records)
            pageToken = response.pageToken
        } while (pageToken != null)
        return collected
    }

    companion object {
        private const val PROVIDER_PACKAGE = "com.google.android.apps.healthdata"
    }
}
