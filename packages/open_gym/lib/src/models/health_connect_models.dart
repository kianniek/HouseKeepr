import 'package:health_keepr/health_keepr.dart';

/// Availability of Android Health Connect on the current device.
enum HealthConnectSdkStatus {
  available,
  providerUpdateRequired,
  unavailable,
}

/// User-configured Health Connect sync preferences stored locally in OpenGym.
class HealthConnectSettings {
  const HealthConnectSettings({
    this.enabled = false,
    this.writeWorkouts = true,
    this.syncBodyMetrics = true,
    this.readExternalActivity = true,
    this.lastSyncedAt,
  });

  factory HealthConnectSettings.fromJson(Map<String, dynamic> json) {
    return HealthConnectSettings(
      enabled: (json['enabled'] as bool?) ?? false,
      writeWorkouts: (json['writeWorkouts'] as bool?) ?? true,
      syncBodyMetrics: (json['syncBodyMetrics'] as bool?) ?? true,
      readExternalActivity: (json['readExternalActivity'] as bool?) ?? true,
      lastSyncedAt: json['lastSyncedAt'] as String?,
    );
  }

  final bool enabled;
  final bool writeWorkouts;
  final bool syncBodyMetrics;
  final bool readExternalActivity;
  final String? lastSyncedAt;

  HealthConnectSettings copyWith({
    bool? enabled,
    bool? writeWorkouts,
    bool? syncBodyMetrics,
    bool? readExternalActivity,
    String? lastSyncedAt,
  }) {
    return HealthConnectSettings(
      enabled: enabled ?? this.enabled,
      writeWorkouts: writeWorkouts ?? this.writeWorkouts,
      syncBodyMetrics: syncBodyMetrics ?? this.syncBodyMetrics,
      readExternalActivity: readExternalActivity ?? this.readExternalActivity,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'writeWorkouts': writeWorkouts,
        'syncBodyMetrics': syncBodyMetrics,
        'readExternalActivity': readExternalActivity,
        if (lastSyncedAt != null) 'lastSyncedAt': lastSyncedAt,
      };
}

/// An external workout session imported from another app via Health Connect.
class ExternalWorkoutSummary with HealthRecordMetadata {
  const ExternalWorkoutSummary({
    required this.id,
    required this.title,
    required this.exerciseType,
    required this.startedAt,
    required this.finishedAt,
    required this.durationSeconds,
    required this.sourcePackage,
    this.caloriesKcal,
    this.avgHeartRateBpm,
    this.maxHeartRateBpm,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory ExternalWorkoutSummary.fromJson(Map<String, dynamic> json) {
    return ExternalWorkoutSummary(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      title: (json['title'] as String?) ?? 'External Workout',
      exerciseType: (json['exerciseType'] as num?)?.toInt() ?? 0,
      startedAt:
          (json['startedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      finishedAt:
          (json['finishedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      sourcePackage: (json['sourcePackage'] as String?) ?? 'health_connect',
      caloriesKcal: (json['caloriesKcal'] as num?)?.toDouble(),
      avgHeartRateBpm: (json['avgHeartRateBpm'] as num?)?.toInt(),
      maxHeartRateBpm: (json['maxHeartRateBpm'] as num?)?.toInt(),
      updatedAt:
          (json['updatedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      isSynced: (json['isSynced'] as bool?) ?? false,
    );
  }

  @override
  final String id;
  final String title;
  final int exerciseType;
  final String startedAt;
  final String finishedAt;
  final int durationSeconds;
  final String sourcePackage;
  final double? caloriesKcal;
  final int? avgHeartRateBpm;
  final int? maxHeartRateBpm;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        'title': title,
        'exerciseType': exerciseType,
        'startedAt': startedAt,
        'finishedAt': finishedAt,
        'durationSeconds': durationSeconds,
        'sourcePackage': sourcePackage,
        if (caloriesKcal != null) 'caloriesKcal': caloriesKcal,
        if (avgHeartRateBpm != null) 'avgHeartRateBpm': avgHeartRateBpm,
        if (maxHeartRateBpm != null) 'maxHeartRateBpm': maxHeartRateBpm,
      };
}

/// Daily aggregated calories & heart rate read from Health Connect.
class DailyHealthMetrics with HealthRecordMetadata {
  const DailyHealthMetrics({
    required this.id,
    required this.date,
    this.activeCaloriesKcal = 0,
    this.totalCaloriesKcal = 0,
    this.avgHeartRateBpm,
    this.minHeartRateBpm,
    this.maxHeartRateBpm,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory DailyHealthMetrics.fromJson(Map<String, dynamic> json) {
    return DailyHealthMetrics(
      id: (json['id'] as String?) ?? (json['date'] as String?) ?? '',
      date: (json['date'] as String?) ?? '',
      activeCaloriesKcal:
          (json['activeCaloriesKcal'] as num?)?.toDouble() ?? 0,
      totalCaloriesKcal: (json['totalCaloriesKcal'] as num?)?.toDouble() ?? 0,
      avgHeartRateBpm: (json['avgHeartRateBpm'] as num?)?.toInt(),
      minHeartRateBpm: (json['minHeartRateBpm'] as num?)?.toInt(),
      maxHeartRateBpm: (json['maxHeartRateBpm'] as num?)?.toInt(),
      updatedAt:
          (json['updatedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      isSynced: (json['isSynced'] as bool?) ?? false,
    );
  }

  @override
  final String id;

  /// Calendar date in `YYYY-MM-DD` format.
  final String date;
  final double activeCaloriesKcal;
  final double totalCaloriesKcal;
  final int? avgHeartRateBpm;
  final int? minHeartRateBpm;
  final int? maxHeartRateBpm;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        'date': date,
        'activeCaloriesKcal': activeCaloriesKcal,
        'totalCaloriesKcal': totalCaloriesKcal,
        if (avgHeartRateBpm != null) 'avgHeartRateBpm': avgHeartRateBpm,
        if (minHeartRateBpm != null) 'minHeartRateBpm': minHeartRateBpm,
        if (maxHeartRateBpm != null) 'maxHeartRateBpm': maxHeartRateBpm,
      };
}

/// Summary of a Health Connect sync pass.
class HealthConnectSyncResult {
  const HealthConnectSyncResult({
    required this.importedWeighIns,
    required this.importedBodyFats,
    required this.externalWorkouts,
    required this.enrichedWorkouts,
    required this.syncedAt,
  });

  final int importedWeighIns;
  final int importedBodyFats;
  final int externalWorkouts;
  final int enrichedWorkouts;
  final String syncedAt;
}
