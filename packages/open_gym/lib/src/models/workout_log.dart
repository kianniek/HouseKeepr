import 'package:health_keepr/health_keepr.dart';

import 'exercise_set.dart';

/// An exercise entry inside a [WorkoutLog] containing its logged [sets].
class WorkoutEntry {
  const WorkoutEntry({
    required this.exerciseId,
    required this.exerciseName,
    required this.bodyPart,
    required this.equipment,
    required this.sets,
    this.restSeconds = 90,
    this.notes,
  });

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>? ?? const <dynamic>[];
    return WorkoutEntry(
      exerciseId: (json['exerciseId'] as String?) ?? '',
      exerciseName: (json['exerciseName'] as String?) ?? '',
      bodyPart: (json['bodyPart'] as String?) ?? 'full body',
      equipment: (json['equipment'] as String?) ?? 'body weight',
      sets: rawSets
          .map((e) => ExerciseSet.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 90,
      notes: json['notes'] as String?,
    );
  }

  final String exerciseId;
  final String exerciseName;
  final String bodyPart;
  final String equipment;
  final List<ExerciseSet> sets;
  final int restSeconds;
  final String? notes;

  double get totalVolume => sets
      .where((s) => s.isCompleted)
      .fold<double>(0, (sum, s) => sum + s.volume);

  WorkoutEntry copyWith({
    List<ExerciseSet>? sets,
    int? restSeconds,
    String? notes,
  }) {
    return WorkoutEntry(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      bodyPart: bodyPart,
      equipment: equipment,
      sets: sets ?? this.sets,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'bodyPart': bodyPart,
        'equipment': equipment,
        'sets': sets.map((s) => s.toJson()).toList(),
        'restSeconds': restSeconds,
        if (notes != null) 'notes': notes,
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
    required this.updatedAt,
    this.isSynced = false,
  });

  factory WorkoutLog.create({
    String? templateId,
    required String title,
    List<WorkoutEntry> entries = const <WorkoutEntry>[],
    String? notes,
  }) {
    final now = HealthRecordMetadata.nowUtcIso();
    return WorkoutLog(
      id: HealthRecordMetadata.generateId(),
      templateId: templateId,
      title: title,
      startedAt: now,
      entries: entries,
      notes: notes,
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
      };
}
