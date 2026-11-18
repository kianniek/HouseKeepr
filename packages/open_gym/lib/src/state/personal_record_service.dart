import 'dart:math' as math;

import '../models/exercise_set.dart';
import '../models/workout_log.dart';

/// Kinds of personal records a completed set can earn.
enum RecordKind {
  weight,
  reps,
  e1rm,
  volume,
}

/// Supported 1-Rep Max estimation formulas ported from openGym `onerm.js`.
class OneRmEstimator {
  OneRmEstimator._();

  static const int repCap = 12;

  static const List<String> formulaKeys = <String>[
    'epley',
    'brzycki',
    'lombardi',
    'oconner',
    'mayhew',
    'wathan',
    'lander',
    'weighted',
  ];

  static String displayName(String key) {
    switch (key) {
      case 'brzycki':
        return 'Brzycki';
      case 'lombardi':
        return 'Lombardi';
      case 'oconner':
        return "O'Conner";
      case 'mayhew':
        return 'Mayhew';
      case 'wathan':
        return 'Wathan';
      case 'lander':
        return 'Lander';
      case 'weighted':
        return 'Weighted Ensemble';
      case 'epley':
      default:
        return 'Epley';
    }
  }

  /// Estimates 1RM for [weight] and [reps] using [formula].
  static double? estimate(
    double weight,
    int reps, {
    String formula = 'epley',
  }) {
    if (weight <= 0 || reps <= 0 || reps > repCap) return null;
    if (reps == 1) return weight;

    switch (formula) {
      case 'brzycki':
        return weight * 36.0 / (37 - reps);
      case 'lombardi':
        return weight * math.pow(reps, 0.1).toDouble();
      case 'oconner':
        return weight * (1.0 + reps / 40.0);
      case 'mayhew':
        return (weight * 100.0) /
            (52.2 + 41.9 * math.exp(-0.055 * reps));
      case 'wathan':
        return (weight * 100.0) /
            (48.8 + 53.8 * math.exp(-0.075 * reps));
      case 'lander':
        return (weight * 100.0) / (101.3 - 2.67123 * reps);
      case 'weighted':
        final values = <double>[
          estimate(weight, reps, formula: 'epley')!,
          estimate(weight, reps, formula: 'brzycki')!,
          estimate(weight, reps, formula: 'lombardi')!,
          estimate(weight, reps, formula: 'oconner')!,
          estimate(weight, reps, formula: 'mayhew')!,
          estimate(weight, reps, formula: 'wathan')!,
          estimate(weight, reps, formula: 'lander')!,
        ];
        return values.reduce((a, b) => a + b) / values.length;
      case 'epley':
      default:
        return weight * (1.0 + reps / 30.0);
    }
  }
}

/// Historical baseline for a single exercise across completed [WorkoutLog]s.
class ExerciseRecordBaseline {
  const ExerciseRecordBaseline({
    required this.exerciseId,
    required this.exerciseName,
    required this.bestWeight,
    required this.bestE1RM,
    required this.bestSetVolume,
    required this.points,
    required this.hasHistory,
  });

  final String exerciseId;
  final String exerciseName;
  final double bestWeight;
  final double bestE1RM;
  final double bestSetVolume;
  final List<({double weight, int reps})> points;
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
    String formula = 'epley',
  }) {
    double bestWeight = 0;
    double bestE1RM = 0;
    double bestVolume = 0;
    bool hasHistory = false;
    String resolvedName = exerciseName ?? exerciseId;
    final points = <({double weight, int reps})>[];

    for (final log in history) {
      for (final entry in log.entries) {
        if (entry.exerciseId != exerciseId) continue;
        resolvedName = entry.exerciseName;
        for (final set in entry.sets) {
          if (!set.isCompleted || set.isWarmup || set.reps <= 0) continue;
          hasHistory = true;
          points.add((weight: set.weight, reps: set.reps));
          if (set.weight > bestWeight) bestWeight = set.weight;
          final e1rm = OneRmEstimator.estimate(
            set.weight,
            set.reps,
            formula: formula,
          );
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
      points: points,
      hasHistory: hasHistory,
    );
  }

  /// Most reps achieved at [weight] or heavier, or `null` if no prior match.
  int? repsRecordAt(ExerciseRecordBaseline baseline, double weight) {
    int? best;
    for (final p in baseline.points) {
      if (p.weight < weight - _eps) continue;
      if ((p.weight > 0) != (weight > 0)) continue;
      if (best == null || p.reps > best) best = p.reps;
    }
    return best;
  }

  /// Returns all [RecordKind]s that [set] beats against [baseline].
  List<RecordKind> evaluateSet(
    ExerciseSet set,
    ExerciseRecordBaseline baseline, {
    String formula = 'epley',
  }) {
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
    final recReps = repsRecordAt(baseline, set.weight);
    if (recReps != null && set.reps > recReps) {
      kinds.add(RecordKind.reps);
    }
    final est = OneRmEstimator.estimate(
      set.weight,
      set.reps,
      formula: formula,
    );
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
  List<ExerciseRecordBaseline> allRecords(
    List<WorkoutLog> history, {
    String formula = 'epley',
  }) {
    final ids = <String>{};
    for (final log in history) {
      for (final entry in log.entries) {
        ids.add(entry.exerciseId);
      }
    }
    final baselines = ids
        .map((id) => baselineFor(id, history, formula: formula))
        .where((b) => b.hasHistory)
        .toList();
    baselines.sort((a, b) => b.bestWeight.compareTo(a.bestWeight));
    return baselines;
  }
}
