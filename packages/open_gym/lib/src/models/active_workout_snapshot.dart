import 'package:health_keepr/health_keepr.dart';

import '../state/personal_record_service.dart';
import 'workout_log.dart';

/// Persisted snapshot of an in-progress workout session and its UI state.
class ActiveWorkoutSnapshot {
  const ActiveWorkoutSnapshot({
    required this.workout,
    required this.workoutStartedAt,
    this.pausedAt,
    this.accumulatedPausedMs = 0,
    this.isPaused = false,
    this.restEndsAt,
    this.restTotalSeconds = 0,
    this.sessionPrs = const <String, List<RecordKind>>{},
    this.selectedEntryIndex = 0,
    this.isInActiveWorkoutScreen = true,
    required this.updatedAt,
  });

  static const String recordId = 'current_workout';

  final WorkoutLog workout;
  final String workoutStartedAt;
  final String? pausedAt;
  final int accumulatedPausedMs;
  final bool isPaused;
  final String? restEndsAt;
  final int restTotalSeconds;
  final Map<String, List<RecordKind>> sessionPrs;
  final int selectedEntryIndex;
  final bool isInActiveWorkoutScreen;
  final String updatedAt;

  factory ActiveWorkoutSnapshot.fromJson(Map<String, dynamic> json) {
    final rawPrs = json['sessionPrs'] as Map<dynamic, dynamic>? ?? const {};
    final parsedPrs = <String, List<RecordKind>>{};
    for (final entry in rawPrs.entries) {
      final key = entry.key.toString();
      final rawList = entry.value as List<dynamic>? ?? const [];
      final kinds = rawList
          .map(
            (name) => RecordKind.values.where((k) => k.name == name).firstOrNull,
          )
          .whereType<RecordKind>()
          .toList();
      if (kinds.isNotEmpty) {
        parsedPrs[key] = kinds;
      }
    }

    return ActiveWorkoutSnapshot(
      workout: WorkoutLog.fromJson(
        Map<String, dynamic>.from(json['workout'] as Map),
      ),
      workoutStartedAt: (json['workoutStartedAt'] as String?) ??
          HealthRecordMetadata.nowUtcIso(),
      pausedAt: json['pausedAt'] as String?,
      accumulatedPausedMs: (json['accumulatedPausedMs'] as num?)?.toInt() ?? 0,
      isPaused: (json['isPaused'] as bool?) ?? false,
      restEndsAt: json['restEndsAt'] as String?,
      restTotalSeconds: (json['restTotalSeconds'] as num?)?.toInt() ?? 0,
      sessionPrs: parsedPrs,
      selectedEntryIndex: (json['selectedEntryIndex'] as num?)?.toInt() ?? 0,
      isInActiveWorkoutScreen:
          (json['isInActiveWorkoutScreen'] as bool?) ?? true,
      updatedAt:
          (json['updatedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': recordId,
        'workout': workout.toJson(),
        'workoutStartedAt': workoutStartedAt,
        if (pausedAt != null) 'pausedAt': pausedAt,
        'accumulatedPausedMs': accumulatedPausedMs,
        'isPaused': isPaused,
        if (restEndsAt != null) 'restEndsAt': restEndsAt,
        'restTotalSeconds': restTotalSeconds,
        'sessionPrs': <String, List<String>>{
          for (final entry in sessionPrs.entries)
            entry.key: entry.value.map((k) => k.name).toList(),
        },
        'selectedEntryIndex': selectedEntryIndex,
        'isInActiveWorkoutScreen': isInActiveWorkoutScreen,
        'updatedAt': updatedAt,
      };
}
