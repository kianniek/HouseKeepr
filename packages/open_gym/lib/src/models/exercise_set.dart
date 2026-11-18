import 'package:health_keepr/health_keepr.dart';

/// Tracking mode for an exercise entry.
enum ExerciseMode {
  reps,
  time,
  cardio,
  distance,
}

/// Structural type of a set row.
enum SetType {
  straight,
  dropset,
  restpause,
  cluster,
}

/// A weight drop inside a drop-set.
class SetDrop {
  const SetDrop({required this.weight, required this.reps});

  factory SetDrop.fromJson(Map<String, dynamic> json) => SetDrop(
        weight: (json['weight'] as num?)?.toDouble() ?? 0,
        reps: (json['reps'] as num?)?.toInt() ?? 0,
      );

  final double weight;
  final int reps;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'weight': weight,
        'reps': reps,
      };
}

/// A short-rest mini-set burst inside a rest-pause or cluster set.
class SetCluster {
  const SetCluster({required this.reps, this.restSeconds = 20});

  factory SetCluster.fromJson(Map<String, dynamic> json) => SetCluster(
        reps: (json['reps'] as num?)?.toInt() ?? 0,
        restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 20,
      );

  final int reps;
  final int restSeconds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'reps': reps,
        'restSeconds': restSeconds,
      };
}

/// A single logged set within a [WorkoutEntry].
class ExerciseSet with HealthRecordMetadata {
  const ExerciseSet({
    required this.id,
    this.weight = 0,
    this.reps = 0,
    this.durationSeconds,
    this.distanceMeters,
    this.speed,
    this.incline,
    this.setType = SetType.straight,
    this.drops = const <SetDrop>[],
    this.clusters = const <SetCluster>[],
    this.isWarmup = false,
    this.isFailure = false,
    this.isCompleted = false,
    this.rpe,
    this.rir,
    this.notes,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory ExerciseSet.create({
    double weight = 0,
    int reps = 0,
    int? durationSeconds,
    double? distanceMeters,
    double? speed,
    double? incline,
    SetType setType = SetType.straight,
    List<SetDrop> drops = const <SetDrop>[],
    List<SetCluster> clusters = const <SetCluster>[],
    bool isWarmup = false,
    bool isFailure = false,
    bool isCompleted = false,
    double? rpe,
    int? rir,
    String? notes,
  }) {
    return ExerciseSet(
      id: HealthRecordMetadata.generateId(),
      weight: weight,
      reps: reps,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      speed: speed,
      incline: incline,
      setType: setType,
      drops: drops,
      clusters: clusters,
      isWarmup: isWarmup,
      isFailure: isFailure,
      isCompleted: isCompleted,
      rpe: rpe,
      rir: rir,
      notes: notes,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    final typeName = json['setType'] as String?;
    final parsedType = SetType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => SetType.straight,
    );
    return ExerciseSet(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      incline: (json['incline'] as num?)?.toDouble(),
      setType: parsedType,
      drops: (json['drops'] as List<dynamic>?)
              ?.map((e) => SetDrop.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const <SetDrop>[],
      clusters: (json['clusters'] as List<dynamic>?)
              ?.map(
                (e) => SetCluster.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const <SetCluster>[],
      isWarmup: (json['isWarmup'] as bool?) ?? false,
      isFailure: (json['isFailure'] as bool?) ?? false,
      isCompleted: (json['isCompleted'] as bool?) ?? false,
      rpe: (json['rpe'] as num?)?.toDouble(),
      rir: (json['rir'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      updatedAt:
          (json['updatedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      isSynced: (json['isSynced'] as bool?) ?? false,
    );
  }

  @override
  final String id;
  final double weight;
  final int reps;
  final int? durationSeconds;
  final double? distanceMeters;
  final double? speed;
  final double? incline;
  final SetType setType;
  final List<SetDrop> drops;
  final List<SetCluster> clusters;
  final bool isWarmup;
  final bool isFailure;
  final bool isCompleted;
  final double? rpe;
  final int? rir;
  final String? notes;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  /// Volume for this set (`weight * reps` + drop-set extra volume).
  /// Warm-up sets contribute 0 volume.
  double get volume {
    if (isWarmup) return 0;
    final base = weight * reps;
    if (setType == SetType.dropset && drops.isNotEmpty) {
      final extra = drops.fold<double>(
        0,
        (sum, d) => sum + (d.weight * d.reps),
      );
      return base + extra;
    }
    return base;
  }

  /// Estimates 1-rep max using the Epley formula (capped at 12 reps).
  double? estimated1RM() {
    if (isWarmup || weight <= 0 || reps <= 0 || reps > 12) return null;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  ExerciseSet copyWith({
    double? weight,
    int? reps,
    int? durationSeconds,
    double? distanceMeters,
    double? speed,
    double? incline,
    SetType? setType,
    List<SetDrop>? drops,
    List<SetCluster>? clusters,
    bool? isWarmup,
    bool? isFailure,
    bool? isCompleted,
    double? rpe,
    int? rir,
    String? notes,
  }) {
    return ExerciseSet(
      id: id,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      speed: speed ?? this.speed,
      incline: incline ?? this.incline,
      setType: setType ?? this.setType,
      drops: drops ?? this.drops,
      clusters: clusters ?? this.clusters,
      isWarmup: isWarmup ?? this.isWarmup,
      isFailure: isFailure ?? this.isFailure,
      isCompleted: isCompleted ?? this.isCompleted,
      rpe: rpe ?? this.rpe,
      rir: rir ?? this.rir,
      notes: notes ?? this.notes,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        'weight': weight,
        'reps': reps,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (speed != null) 'speed': speed,
        if (incline != null) 'incline': incline,
        if (setType != SetType.straight) 'setType': setType.name,
        if (drops.isNotEmpty)
          'drops': drops.map((d) => d.toJson()).toList(),
        if (clusters.isNotEmpty)
          'clusters': clusters.map((c) => c.toJson()).toList(),
        'isWarmup': isWarmup,
        'isFailure': isFailure,
        'isCompleted': isCompleted,
        if (rpe != null) 'rpe': rpe,
        if (rir != null) 'rir': rir,
        if (notes != null) 'notes': notes,
      };
}
