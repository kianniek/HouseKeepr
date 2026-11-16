import 'package:health_keepr/health_keepr.dart';

/// Planned exercise prescription inside a [WorkoutTemplate].
class WorkoutTemplateEntry {
  const WorkoutTemplateEntry({
    required this.exerciseId,
    required this.exerciseName,
    this.bodyPart = 'full body',
    this.equipment = 'body weight',
    this.targetSets = 3,
    this.targetReps = 10,
    this.defaultWeight = 0,
    this.restSeconds = 90,
  });

  factory WorkoutTemplateEntry.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplateEntry(
      exerciseId: (json['exerciseId'] as String?) ?? '',
      exerciseName: (json['exerciseName'] as String?) ?? '',
      bodyPart: (json['bodyPart'] as String?) ?? 'full body',
      equipment: (json['equipment'] as String?) ?? 'body weight',
      targetSets: (json['targetSets'] as num?)?.toInt() ?? 3,
      targetReps: (json['targetReps'] as num?)?.toInt() ?? 10,
      defaultWeight: (json['defaultWeight'] as num?)?.toDouble() ?? 0,
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 90,
    );
  }

  final String exerciseId;
  final String exerciseName;
  final String bodyPart;
  final String equipment;
  final int targetSets;
  final int targetReps;
  final double defaultWeight;
  final int restSeconds;

  WorkoutTemplateEntry copyWith({
    int? targetSets,
    int? targetReps,
    double? defaultWeight,
    int? restSeconds,
  }) {
    return WorkoutTemplateEntry(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      bodyPart: bodyPart,
      equipment: equipment,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      defaultWeight: defaultWeight ?? this.defaultWeight,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'bodyPart': bodyPart,
        'equipment': equipment,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'defaultWeight': defaultWeight,
        'restSeconds': restSeconds,
      };
}

/// A reusable workout routine template.
class WorkoutTemplate with HealthRecordMetadata {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    this.goal = 'strength',
    this.split = 'custom',
    this.description = '',
    required this.entries,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory WorkoutTemplate.create({
    String? id,
    required String name,
    String goal = 'strength',
    String split = 'custom',
    String description = '',
    required List<WorkoutTemplateEntry> entries,
  }) {
    return WorkoutTemplate(
      id: id ?? HealthRecordMetadata.generateId(),
      name: name,
      goal: goal,
      split: split,
      description: description,
      entries: entries,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? const <dynamic>[];
    return WorkoutTemplate(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      name: (json['name'] as String?) ?? 'Routine',
      goal: (json['goal'] as String?) ?? 'strength',
      split: (json['split'] as String?) ?? 'custom',
      description: (json['description'] as String?) ?? '',
      entries: rawEntries
          .map(
            (e) => WorkoutTemplateEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      updatedAt:
          (json['updatedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      isSynced: (json['isSynced'] as bool?) ?? false,
    );
  }

  @override
  final String id;
  final String name;
  final String goal;
  final String split;
  final String description;
  final List<WorkoutTemplateEntry> entries;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  WorkoutTemplate copyWith({
    String? name,
    String? goal,
    String? split,
    String? description,
    List<WorkoutTemplateEntry>? entries,
  }) {
    return WorkoutTemplate(
      id: id,
      name: name ?? this.name,
      goal: goal ?? this.goal,
      split: split ?? this.split,
      description: description ?? this.description,
      entries: entries ?? this.entries,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        'name': name,
        'goal': goal,
        'split': split,
        'description': description,
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}
