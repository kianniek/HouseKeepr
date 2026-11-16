import 'package:health_keepr/health_keepr.dart';

/// A single logged set within a [WorkoutEntry].
class ExerciseSet with HealthRecordMetadata {
  const ExerciseSet({
    required this.id,
    this.weight = 0,
    this.reps = 0,
    this.durationSeconds,
    this.isWarmup = false,
    this.isFailure = false,
    this.isCompleted = false,
    this.rpe,
    this.notes,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory ExerciseSet.create({
    double weight = 0,
    int reps = 0,
    int? durationSeconds,
    bool isWarmup = false,
    bool isFailure = false,
    bool isCompleted = false,
    double? rpe,
    String? notes,
  }) {
    return ExerciseSet(
      id: HealthRecordMetadata.generateId(),
      weight: weight,
      reps: reps,
      durationSeconds: durationSeconds,
      isWarmup: isWarmup,
      isFailure: isFailure,
      isCompleted: isCompleted,
      rpe: rpe,
      notes: notes,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      isWarmup: (json['isWarmup'] as bool?) ?? false,
      isFailure: (json['isFailure'] as bool?) ?? false,
      isCompleted: (json['isCompleted'] as bool?) ?? false,
      rpe: (json['rpe'] as num?)?.toDouble(),
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
  final bool isWarmup;
  final bool isFailure;
  final bool isCompleted;
  final double? rpe;
  final String? notes;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  /// Volume for this set (`weight * reps`). Warm-up sets contribute 0 volume.
  double get volume => isWarmup ? 0 : weight * reps;

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
    bool? isWarmup,
    bool? isFailure,
    bool? isCompleted,
    double? rpe,
    String? notes,
  }) {
    return ExerciseSet(
      id: id,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isWarmup: isWarmup ?? this.isWarmup,
      isFailure: isFailure ?? this.isFailure,
      isCompleted: isCompleted ?? this.isCompleted,
      rpe: rpe ?? this.rpe,
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
        'isWarmup': isWarmup,
        'isFailure': isFailure,
        'isCompleted': isCompleted,
        if (rpe != null) 'rpe': rpe,
        if (notes != null) 'notes': notes,
      };
}
