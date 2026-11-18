import 'package:health_keepr/health_keepr.dart';

import 'exercise_set.dart';

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
    this.autoProgressionKg,
    this.mode = ExerciseMode.reps,
    this.targetRepsMin,
    this.targetSetsMax,
    this.targetDurationSeconds,
    this.targetDistanceMeters,
    this.progressionPolicy,
    this.deloadFactor = 0.90,
    this.supersetId,
    this.supersetName,
    this.supersetRestSeconds,
    this.note,
    this.warmupMode = 'auto',
    this.intensifierType = SetType.straight,
  });

  factory WorkoutTemplateEntry.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String?;
    final parsedMode = ExerciseMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => ExerciseMode.reps,
    );
    final intensifierName = json['intensifierType'] as String?;
    final parsedIntensifier = SetType.values.firstWhere(
      (s) => s.name == intensifierName,
      orElse: () => SetType.straight,
    );

    return WorkoutTemplateEntry(
      exerciseId: (json['exerciseId'] as String?) ?? '',
      exerciseName: (json['exerciseName'] as String?) ?? '',
      bodyPart: (json['bodyPart'] as String?) ?? 'full body',
      equipment: (json['equipment'] as String?) ?? 'body weight',
      targetSets: (json['targetSets'] as num?)?.toInt() ?? 3,
      targetReps: (json['targetReps'] as num?)?.toInt() ?? 10,
      defaultWeight: (json['defaultWeight'] as num?)?.toDouble() ?? 0,
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 90,
      autoProgressionKg: (json['autoProgressionKg'] as num?)?.toDouble(),
      mode: parsedMode,
      targetRepsMin: (json['targetRepsMin'] as num?)?.toInt(),
      targetSetsMax: (json['targetSetsMax'] as num?)?.toInt(),
      targetDurationSeconds: (json['targetDurationSeconds'] as num?)?.toInt(),
      targetDistanceMeters: (json['targetDistanceMeters'] as num?)?.toDouble(),
      progressionPolicy: json['progressionPolicy'] as String?,
      deloadFactor: (json['deloadFactor'] as num?)?.toDouble() ?? 0.90,
      supersetId: json['supersetId'] as String?,
      supersetName: json['supersetName'] as String?,
      supersetRestSeconds: (json['supersetRestSeconds'] as num?)?.toInt(),
      note: json['note'] as String?,
      warmupMode: (json['warmupMode'] as String?) ?? 'auto',
      intensifierType: parsedIntensifier,
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
  final double? autoProgressionKg;
  final ExerciseMode mode;
  final int? targetRepsMin;
  final int? targetSetsMax;
  final int? targetDurationSeconds;
  final double? targetDistanceMeters;
  final String? progressionPolicy;
  final double deloadFactor;
  final String? supersetId;
  final String? supersetName;
  final int? supersetRestSeconds;
  final String? note;
  final String warmupMode;
  final SetType intensifierType;

  String prescriptionSummary(String unit) {
    final restText = restSeconds > 0
        ? ' · ${restSeconds ~/ 60}:${(restSeconds % 60).toString().padLeft(2, '0')}'
        : '';
    switch (mode) {
      case ExerciseMode.time:
        return '$targetSets × ${targetDurationSeconds ?? 30}s$restText';
      case ExerciseMode.distance:
        return '$targetSets × ${(targetDistanceMeters ?? 40).toStringAsFixed(0)}m$restText';
      case ExerciseMode.cardio:
        return '${((targetDurationSeconds ?? 1200) / 60).round()} min';
      case ExerciseMode.reps:
        final repText = (targetRepsMin != null && targetRepsMin! < targetReps)
            ? '$targetRepsMin–$targetReps'
            : '$targetReps';
        final weightText = defaultWeight > 0
            ? ' · ${defaultWeight == defaultWeight.roundToDouble() ? defaultWeight.toStringAsFixed(0) : defaultWeight.toStringAsFixed(1)} $unit'
            : '';
        return '$targetSets × $repText$weightText$restText';
    }
  }

  WorkoutTemplateEntry copyWith({
    String? exerciseId,
    String? exerciseName,
    String? bodyPart,
    String? equipment,
    int? targetSets,
    int? targetReps,
    double? defaultWeight,
    int? restSeconds,
    double? autoProgressionKg,
    ExerciseMode? mode,
    int? targetRepsMin,
    bool clearTargetRepsMin = false,
    int? targetSetsMax,
    bool clearTargetSetsMax = false,
    int? targetDurationSeconds,
    double? targetDistanceMeters,
    String? progressionPolicy,
    bool clearProgressionPolicy = false,
    double? deloadFactor,
    String? supersetId,
    bool clearSuperset = false,
    String? supersetName,
    int? supersetRestSeconds,
    String? note,
    bool clearNote = false,
    String? warmupMode,
    SetType? intensifierType,
  }) {
    return WorkoutTemplateEntry(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      bodyPart: bodyPart ?? this.bodyPart,
      equipment: equipment ?? this.equipment,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      defaultWeight: defaultWeight ?? this.defaultWeight,
      restSeconds: restSeconds ?? this.restSeconds,
      autoProgressionKg: autoProgressionKg ?? this.autoProgressionKg,
      mode: mode ?? this.mode,
      targetRepsMin:
          clearTargetRepsMin ? null : (targetRepsMin ?? this.targetRepsMin),
      targetSetsMax:
          clearTargetSetsMax ? null : (targetSetsMax ?? this.targetSetsMax),
      targetDurationSeconds:
          targetDurationSeconds ?? this.targetDurationSeconds,
      targetDistanceMeters: targetDistanceMeters ?? this.targetDistanceMeters,
      progressionPolicy: clearProgressionPolicy
          ? null
          : (progressionPolicy ?? this.progressionPolicy),
      deloadFactor: deloadFactor ?? this.deloadFactor,
      supersetId: clearSuperset ? null : (supersetId ?? this.supersetId),
      supersetName: clearSuperset ? null : (supersetName ?? this.supersetName),
      supersetRestSeconds:
          clearSuperset ? null : (supersetRestSeconds ?? this.supersetRestSeconds),
      note: clearNote ? null : (note ?? this.note),
      warmupMode: warmupMode ?? this.warmupMode,
      intensifierType: intensifierType ?? this.intensifierType,
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
        if (autoProgressionKg != null) 'autoProgressionKg': autoProgressionKg,
        if (mode != ExerciseMode.reps) 'mode': mode.name,
        if (targetRepsMin != null) 'targetRepsMin': targetRepsMin,
        if (targetSetsMax != null) 'targetSetsMax': targetSetsMax,
        if (targetDurationSeconds != null)
          'targetDurationSeconds': targetDurationSeconds,
        if (targetDistanceMeters != null)
          'targetDistanceMeters': targetDistanceMeters,
        if (progressionPolicy != null) 'progressionPolicy': progressionPolicy,
        if (deloadFactor != 0.90) 'deloadFactor': deloadFactor,
        if (supersetId != null) 'supersetId': supersetId,
        if (supersetName != null) 'supersetName': supersetName,
        if (supersetRestSeconds != null)
          'supersetRestSeconds': supersetRestSeconds,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (warmupMode != 'auto') 'warmupMode': warmupMode,
        if (intensifierType != SetType.straight)
          'intensifierType': intensifierType.name,
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
    this.folder,
    this.isFavorite = false,
    this.iconKey = 'overhead_press',
    this.progressionPolicy = 'linear',
    this.routineType = 'regular',
    this.isDeload = false,
    this.sortOrder = 0,
    this.circuitConfig,
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
    String? folder,
    bool isFavorite = false,
    String iconKey = 'overhead_press',
    String progressionPolicy = 'linear',
    String routineType = 'regular',
    bool isDeload = false,
    int sortOrder = 0,
    Map<String, dynamic>? circuitConfig,
    required List<WorkoutTemplateEntry> entries,
  }) {
    return WorkoutTemplate(
      id: id ?? HealthRecordMetadata.generateId(),
      name: name,
      goal: goal,
      split: split,
      description: description,
      folder: folder,
      isFavorite: isFavorite,
      iconKey: iconKey,
      progressionPolicy: progressionPolicy,
      routineType: routineType,
      isDeload: isDeload,
      sortOrder: sortOrder,
      circuitConfig: circuitConfig,
      entries: entries,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? const <dynamic>[];
    final rawCircuit = json['circuitConfig'];
    return WorkoutTemplate(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      name: (json['name'] as String?) ?? 'Routine',
      goal: (json['goal'] as String?) ?? 'strength',
      split: (json['split'] as String?) ?? 'custom',
      description: (json['description'] as String?) ?? '',
      folder: json['folder'] as String?,
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      iconKey: (json['iconKey'] as String?) ?? 'overhead_press',
      progressionPolicy: (json['progressionPolicy'] as String?) ?? 'linear',
      routineType: (json['routineType'] as String?) ?? 'regular',
      isDeload: (json['isDeload'] as bool?) ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      circuitConfig: rawCircuit is Map
          ? Map<String, dynamic>.from(rawCircuit)
          : null,
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
  final String? folder;
  final bool isFavorite;
  final String iconKey;
  final String progressionPolicy;
  final String routineType;
  final bool isDeload;
  final int sortOrder;
  final Map<String, dynamic>? circuitConfig;
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
    String? folder,
    bool clearFolder = false,
    bool? isFavorite,
    String? iconKey,
    String? progressionPolicy,
    String? routineType,
    bool? isDeload,
    int? sortOrder,
    Map<String, dynamic>? circuitConfig,
    bool clearCircuitConfig = false,
    List<WorkoutTemplateEntry>? entries,
  }) {
    return WorkoutTemplate(
      id: id,
      name: name ?? this.name,
      goal: goal ?? this.goal,
      split: split ?? this.split,
      description: description ?? this.description,
      folder: clearFolder ? null : (folder ?? this.folder),
      isFavorite: isFavorite ?? this.isFavorite,
      iconKey: iconKey ?? this.iconKey,
      progressionPolicy: progressionPolicy ?? this.progressionPolicy,
      routineType: routineType ?? this.routineType,
      isDeload: isDeload ?? this.isDeload,
      sortOrder: sortOrder ?? this.sortOrder,
      circuitConfig:
          clearCircuitConfig ? null : (circuitConfig ?? this.circuitConfig),
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
        if (folder != null && folder!.isNotEmpty) 'folder': folder,
        'isFavorite': isFavorite,
        'iconKey': iconKey,
        'progressionPolicy': progressionPolicy,
        'routineType': routineType,
        'isDeload': isDeload,
        'sortOrder': sortOrder,
        if (circuitConfig != null) 'circuitConfig': circuitConfig,
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}
