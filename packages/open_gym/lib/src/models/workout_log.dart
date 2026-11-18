import 'package:health_keepr/health_keepr.dart';

import 'exercise_set.dart';

/// An exercise entry inside a [WorkoutLog] containing its logged [sets].
class WorkoutEntry {
  const WorkoutEntry({
    required this.exerciseId,
    required this.exerciseName,
    required this.bodyPart,
    required this.equipment,
    this.mode = ExerciseMode.reps,
    required this.sets,
    this.restSeconds = 90,
    this.notes,
    this.countForProgression = true,
    this.supersetId,
    this.progressionMode = 'linear',
  });

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>? ?? const <dynamic>[];
    final modeName = json['mode'] as String?;
    final parsedMode = ExerciseMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => ExerciseMode.reps,
    );
    return WorkoutEntry(
      exerciseId: (json['exerciseId'] as String?) ?? '',
      exerciseName: (json['exerciseName'] as String?) ?? '',
      bodyPart: (json['bodyPart'] as String?) ?? 'full body',
      equipment: (json['equipment'] as String?) ?? 'body weight',
      mode: parsedMode,
      sets: rawSets
          .map((e) => ExerciseSet.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 90,
      notes: json['notes'] as String?,
      countForProgression: (json['countForProgression'] as bool?) ?? true,
      supersetId: json['supersetId'] as String?,
      progressionMode: (json['progressionMode'] as String?) ?? 'linear',
    );
  }

  final String exerciseId;
  final String exerciseName;
  final String bodyPart;
  final String equipment;
  final ExerciseMode mode;
  final List<ExerciseSet> sets;
  final int restSeconds;
  final String? notes;
  final bool countForProgression;
  final String? supersetId;
  final String progressionMode;

  double get totalVolume => sets
      .where((s) => s.isCompleted)
      .fold<double>(0, (sum, s) => sum + s.volume);

  WorkoutEntry copyWith({
    String? exerciseId,
    String? exerciseName,
    String? bodyPart,
    String? equipment,
    ExerciseMode? mode,
    List<ExerciseSet>? sets,
    int? restSeconds,
    String? notes,
    bool clearNotes = false,
    bool? countForProgression,
    String? supersetId,
    bool clearSuperset = false,
    String? progressionMode,
  }) {
    return WorkoutEntry(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      bodyPart: bodyPart ?? this.bodyPart,
      equipment: equipment ?? this.equipment,
      mode: mode ?? this.mode,
      sets: sets ?? this.sets,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: clearNotes ? null : (notes ?? this.notes),
      countForProgression: countForProgression ?? this.countForProgression,
      supersetId: clearSuperset ? null : (supersetId ?? this.supersetId),
      progressionMode: progressionMode ?? this.progressionMode,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'bodyPart': bodyPart,
        'equipment': equipment,
        if (mode != ExerciseMode.reps) 'mode': mode.name,
        'sets': sets.map((s) => s.toJson()).toList(),
        'restSeconds': restSeconds,
        if (notes != null) 'notes': notes,
        if (!countForProgression) 'countForProgression': false,
        if (supersetId != null) 'supersetId': supersetId,
        if (progressionMode != 'linear') 'progressionMode': progressionMode,
      };
}

/// A completed or active workout session persisted locally.
class WorkoutLog with HealthRecordMetadata {
  const WorkoutLog({
    required this.id,
    this.templateId,
    required this.title,
    required this.startedAt,
    this.finishedAt,
    this.durationSeconds = 0,
    required this.entries,
    this.notes,
    this.countForProgression = true,
    this.healthConnectId,
    this.caloriesKcal,
    this.avgHeartRateBpm,
    this.maxHeartRateBpm,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory WorkoutLog.create({
    String? templateId,
    required String title,
    List<WorkoutEntry> entries = const <WorkoutEntry>[],
    String? notes,
    bool countForProgression = true,
  }) {
    final now = HealthRecordMetadata.nowUtcIso();
    return WorkoutLog(
      id: HealthRecordMetadata.generateId(),
      templateId: templateId,
      title: title,
      startedAt: now,
      entries: entries,
      notes: notes,
      countForProgression: countForProgression,
      updatedAt: now,
      isSynced: false,
    );
  }

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? const <dynamic>[];
    return WorkoutLog(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      templateId: json['templateId'] as String?,
      title: (json['title'] as String?) ?? 'Workout',
      startedAt:
          (json['startedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      finishedAt: json['finishedAt'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      entries: rawEntries
          .map(
            (e) => WorkoutEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      notes: json['notes'] as String?,
      countForProgression: (json['countForProgression'] as bool?) ?? true,
      healthConnectId: json['healthConnectId'] as String?,
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
  final String? templateId;
  final String title;
  final String startedAt;
  final String? finishedAt;
  final int durationSeconds;
  final List<WorkoutEntry> entries;
  final String? notes;
  final bool countForProgression;
  final String? healthConnectId;
  final double? caloriesKcal;
  final int? avgHeartRateBpm;
  final int? maxHeartRateBpm;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  double get totalVolume =>
      entries.fold<double>(0, (sum, entry) => sum + entry.totalVolume);

  int get completedSetsCount => entries.fold<int>(
        0,
        (sum, e) => sum + e.sets.where((s) => s.isCompleted).length,
      );

  int get totalSetsCount =>
      entries.fold<int>(0, (sum, e) => sum + e.sets.length);

  WorkoutLog copyWith({
    String? title,
    String? finishedAt,
    int? durationSeconds,
    List<WorkoutEntry>? entries,
    String? notes,
    bool? countForProgression,
    String? healthConnectId,
    double? caloriesKcal,
    int? avgHeartRateBpm,
    int? maxHeartRateBpm,
  }) {
    return WorkoutLog(
      id: id,
      templateId: templateId,
      title: title ?? this.title,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      entries: entries ?? this.entries,
      notes: notes ?? this.notes,
      countForProgression: countForProgression ?? this.countForProgression,
      healthConnectId: healthConnectId ?? this.healthConnectId,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
      avgHeartRateBpm: avgHeartRateBpm ?? this.avgHeartRateBpm,
      maxHeartRateBpm: maxHeartRateBpm ?? this.maxHeartRateBpm,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        if (templateId != null) 'templateId': templateId,
        'title': title,
        'startedAt': startedAt,
        if (finishedAt != null) 'finishedAt': finishedAt,
        'durationSeconds': durationSeconds,
        'entries': entries.map((e) => e.toJson()).toList(),
        if (notes != null) 'notes': notes,
        if (!countForProgression) 'countForProgression': false,
        if (healthConnectId != null) 'healthConnectId': healthConnectId,
        if (caloriesKcal != null) 'caloriesKcal': caloriesKcal,
        if (avgHeartRateBpm != null) 'avgHeartRateBpm': avgHeartRateBpm,
        if (maxHeartRateBpm != null) 'maxHeartRateBpm': maxHeartRateBpm,
      };
}
