import '../models/exercise_set.dart';
import '../models/workout_log.dart';

/// Kinds of personal records a completed set can earn.
enum RecordKind {
  weight,
  reps,
  e1rm,
  volume,
}

/// Historical baseline for a single exercise across completed [WorkoutLog]s.
class ExerciseRecordBaseline {
  const ExerciseRecordBaseline({
    required this.exerciseId,
    required this.exerciseName,
    required this.bestWeight,
    required this.bestE1RM,
    required this.bestSetVolume,
    required this.hasHistory,
  });

  final String exerciseId;
  final String exerciseName;
  final double bestWeight;
  final double bestE1RM;
  final double bestSetVolume;
  final bool hasHistory;
}

/// Computes historical baselines and detects new PRs on completed sets.
class PersonalRecordService {
  const PersonalRecordService();

  static const double _eps = 1e-6;

  /// Builds a baseline for [exerciseId] from [history].
  ExerciseRecordBaseline baselineFor(
    String exerciseId,
    List<WorkoutLog> history, {
    String? exerciseName,
  }) {
    double bestWeight = 0;
    double bestE1RM = 0;
    double bestVolume = 0;
    bool hasHistory = false;
    String resolvedName = exerciseName ?? exerciseId;

    for (final log in history) {
      for (final entry in log.entries) {
        if (entry.exerciseId != exerciseId) continue;
        resolvedName = entry.exerciseName;
        for (final set in entry.sets) {
          if (!set.isCompleted || set.isWarmup || set.reps <= 0) continue;
          hasHistory = true;
          if (set.weight > bestWeight) bestWeight = set.weight;
          final e1rm = set.estimated1RM();
          if (e1rm != null && e1rm > bestE1RM) bestE1RM = e1rm;
          if (set.volume > bestVolume) bestVolume = set.volume;
        }
      }
    }

    return ExerciseRecordBaseline(
      exerciseId: exerciseId,
      exerciseName: resolvedName,
      bestWeight: bestWeight,
      bestE1RM: bestE1RM,
      bestSetVolume: bestVolume,
      hasHistory: hasHistory,
    );
  }

  /// Returns all [RecordKind]s that [set] beats against [baseline].
  ///
  /// Returns an empty list if there is no prior history for the exercise
  /// (so the very first logged workout doesn't falsely celebrate every set).
  List<RecordKind> evaluateSet(
    ExerciseSet set,
    ExerciseRecordBaseline baseline,
  ) {
    if (!baseline.hasHistory || !set.isCompleted || set.isWarmup) {
      return const <RecordKind>[];
    }
    if (set.reps <= 0) return const <RecordKind>[];

    final kinds = <RecordKind>[];
    if (set.weight > 0 &&
        baseline.bestWeight > 0 &&
        set.weight > baseline.bestWeight + _eps) {
      kinds.add(RecordKind.weight);
    }
    final est = set.estimated1RM();
    if (est != null &&
        baseline.bestE1RM > 0 &&
        est > baseline.bestE1RM + _eps) {
      kinds.add(RecordKind.e1rm);
    }
    if (set.volume > 0 &&
        baseline.bestSetVolume > 0 &&
        set.volume > baseline.bestSetVolume + _eps) {
      kinds.add(RecordKind.volume);
    }
    return kinds;
  }

  /// Returns non-empty baselines for all exercises present in [history],
  /// sorted by heaviest weight descending.
  List<ExerciseRecordBaseline> allRecords(List<WorkoutLog> history) {
    final ids = <String>{};
    for (final log in history) {
      for (final entry in log.entries) {
        ids.add(entry.exerciseId);
      }
    }
    final baselines = ids
        .map((id) => baselineFor(id, history))
        .where((b) => b.hasHistory)
        .toList();
    baselines.sort((a, b) => b.bestWeight.compareTo(a.bestWeight));
    return baselines;
  }
}
