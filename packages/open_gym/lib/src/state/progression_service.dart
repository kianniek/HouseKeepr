import 'dart:math' as math;

import '../models/exercise_set.dart';
import '../models/workout_log.dart';
import '../models/workout_template.dart';
import 'personal_record_service.dart';

/// Metadata for a single named progression policy.
class ProgressionPolicyInfo {
  const ProgressionPolicyInfo({
    required this.key,
    required this.title,
    required this.description,
  });

  final String key;
  final String title;
  final String description;
}

/// Output of [ProgressionService.prescribe] for an exercise in a workout.
class ExercisePrescription {
  const ExercisePrescription({
    required this.weight,
    required this.reps,
    required this.sets,
    required this.restSeconds,
    required this.policyKey,
    required this.policyTitle,
    required this.insightReason,
    this.lastSessionSummary,
    this.lastSessionDate,
    this.lastSessionTimestamp,
  });

  final double weight;
  final int reps;
  final int sets;
  final int restSeconds;
  final String policyKey;
  final String policyTitle;
  final String insightReason;
  final String? lastSessionSummary;
  final String? lastSessionDate;
  final String? lastSessionTimestamp;
}

/// Post-workout progression comparison row shown on the Workout Complete summary.
class PostWorkoutComparison {
  const PostWorkoutComparison({
    required this.exerciseId,
    required this.exerciseName,
    required this.todaySummary,
    this.lastTimeSummary,
    required this.nextTimeSummary,
    required this.steppedUp,
  });

  final String exerciseId;
  final String exerciseName;
  final String todaySummary;
  final String? lastTimeSummary;
  final String nextTimeSummary;
  final bool steppedUp;
}

/// Pure progression rule engine ported from openGym `lib/progression.js` &
/// `lib/progression-copy.js`.
class ProgressionService {
  const ProgressionService();

  static const int densityStepSeconds = 15;
  static const int densityFloorSeconds = 45;

  static const List<ProgressionPolicyInfo> policies = <ProgressionPolicyInfo>[
    ProgressionPolicyInfo(
      key: 'off',
      title: 'No automatic progression',
      description: 'Targets stay where you set them.',
    ),
    ProgressionPolicyInfo(
      key: 'linear',
      title: 'Linear progression',
      description:
          'Hit every rep in every set and the weight goes up. Repeated misses trigger a deload.',
    ),
    ProgressionPolicyInfo(
      key: 'greyskull',
      title: 'Greyskull LP',
      description:
          'Two straight sets plus a final set taken to failure. Beat the target on that set and the weight goes up (twice as much if you double the reps). One failure resets 10 %.',
    ),
    ProgressionPolicyInfo(
      key: 'double',
      title: 'Double progression',
      description:
          'Work up through a rep range at the same weight. Reach the top of the range in every set and the weight goes up, reps back to the bottom.',
    ),
    ProgressionPolicyInfo(
      key: 'steady',
      title: 'Steady double progression',
      description:
          'Work up a rep range one rep at a time. Every set has to hit the target before it moves, and at the top of the range the weight goes up.',
    ),
    ProgressionPolicyInfo(
      key: 'triple',
      title: 'Triple progression',
      description:
          'Reps climb to the top of the range, then a set is added, up to your most sets. All of them at the top and the weight goes up, back to your first sets and reps.',
    ),
    ProgressionPolicyInfo(
      key: 'undulating',
      title: 'Undulating days',
      description:
          'Each session rotates: a medium day at your reps, a heavy day with fewer, a light day with more. The weights come from your estimated max, so they climb as you get stronger.',
    ),
    ProgressionPolicyInfo(
      key: 'density',
      title: 'Shorter rests',
      description:
          'Same weight, a bit less rest each time every set is clean. At your shortest rest the weight goes up and the rest starts over.',
    ),
    ProgressionPolicyInfo(
      key: 'ladder',
      title: 'Skill ladder',
      description:
          'For bodyweight skills. One more rep each clean session up to the top of the range, then the next, harder variation of the ladder, back at the bottom.',
    ),
  ];

  static ProgressionPolicyInfo policyInfo(String key) {
    return policies.firstWhere(
      (p) => p.key == key,
      orElse: () => policies[1], // linear
    );
  }

  static String policyTitle(String key) => policyInfo(key).title;

  static String policyDescription(String key) => policyInfo(key).description;

  static double defaultIncrement(String unit, String equipment) {
    final isLb = unit.toLowerCase().startsWith('lb');
    if (equipment.toLowerCase().contains('dumbbell')) {
      return isLb ? 5.0 : 2.0;
    }
    return isLb ? 5.0 : 2.5;
  }

  static double snapToStep(double value, double step) {
    if (value <= 0) return 0;
    if (step <= 0) return value;
    final snapped = (value / step).round() * step;
    return (snapped * 100).round() / 100.0;
  }

  static String _fmtWeight(double w) {
    if (w == w.roundToDouble()) return w.toStringAsFixed(0);
    return w.toStringAsFixed(1);
  }

  /// Derives the prescription and insight banner for [entry] from [history].
  ExercisePrescription prescribe({
    required WorkoutTemplateEntry entry,
    required List<WorkoutLog> history,
    String routinePolicy = 'linear',
    bool routineIsDeload = false,
    String unit = 'kg',
    String oneRmFormula = 'epley',
  }) {
    final activePolicyKey =
        routineIsDeload ? 'off' : (entry.progressionPolicy ?? routinePolicy);
    final info = policyInfo(activePolicyKey);
    final inc = entry.autoProgressionKg ?? defaultIncrement(unit, entry.equipment);

    if (routineIsDeload) {
      return ExercisePrescription(
        weight: entry.defaultWeight,
        reps: entry.targetReps,
        sets: entry.targetSets,
        restSeconds: entry.restSeconds,
        policyKey: 'off',
        policyTitle: 'Deload routine',
        insightReason: 'Opens at the numbers set here without progressing.',
      );
    }

    if (activePolicyKey == 'off') {
      return ExercisePrescription(
        weight: entry.defaultWeight,
        reps: entry.targetReps,
        sets: entry.targetSets,
        restSeconds: entry.restSeconds,
        policyKey: 'off',
        policyTitle: info.title,
        insightReason: info.description,
      );
    }

    // Extract prior eligible sessions (newest first, as history is sorted).
    final sessions = <({WorkoutLog log, WorkoutEntry entry, List<ExerciseSet> workSets})>[];
    for (final log in history) {
      if (!log.countForProgression) continue;
      for (final e in log.entries) {
        if (e.exerciseId != entry.exerciseId || !e.countForProgression) continue;
        final work = e.sets
            .where((s) => s.isCompleted && !s.isWarmup)
            .toList();
        if (work.isNotEmpty) {
          sessions.add((log: log, entry: e, workSets: work));
        }
        break;
      }
    }

    if (sessions.isEmpty) {
      return ExercisePrescription(
        weight: entry.defaultWeight,
        reps: entry.targetReps,
        sets: entry.targetSets,
        restSeconds: entry.restSeconds,
        policyKey: activePolicyKey,
        policyTitle: info.title,
        insightReason: 'Nothing logged yet, so this session sets the baseline.',
      );
    }

    final latest = sessions.first;
    final lastSummary = latest.workSets
        .map((s) => '${_fmtWeight(s.weight)}×${s.reps}')
        .join(', ');
    final lastDate = _relativeDateLabel(latest.log.startedAt);

    final topWeight = latest.workSets.fold<double>(
      0,
      (m, s) => s.weight > m ? s.weight : m,
    );
    final plannedSets = entry.targetSets.clamp(1, 20);
    final graded = latest.workSets.take(plannedSets).toList();
    final lowReps = graded.isEmpty
        ? 0
        : graded.map((s) => s.reps).reduce(math.min);
    final isClean = graded.length >= plannedSets &&
        graded.every((s) => s.reps >= entry.targetReps);

    // Count consecutive misses at the top of history.
    int stalls = 0;
    for (final s in sessions) {
      final g = s.workSets.take(plannedSets).toList();
      final clean = g.length >= plannedSets &&
          g.every((r) => r.reps >= entry.targetReps);
      if (clean) break;
      stalls++;
    }

    switch (activePolicyKey) {
      case 'greyskull':
        final amrapReps = graded.isNotEmpty ? graded.last.reps : 0;
        if (isClean && topWeight > 0) {
          final doubled = amrapReps >= entry.targetReps * 2;
          final delta = doubled ? inc * 2 : inc;
          return ExercisePrescription(
            weight: snapToStep(topWeight + delta, inc),
            reps: entry.targetReps,
            sets: plannedSets,
            restSeconds: entry.restSeconds,
            policyKey: activePolicyKey,
            policyTitle: info.title,
            insightReason: doubled
                ? 'Doubled the final AMRAP target, so +${_fmtWeight(delta)} $unit.'
                : 'Hit every target rep last time, so +${_fmtWeight(delta)} $unit.',
            lastSessionSummary: lastSummary,
            lastSessionDate: lastDate,
            lastSessionTimestamp: latest.log.startedAt,
          );
        }
        if (topWeight > 0) {
          final deloaded = snapToStep(topWeight * entry.deloadFactor, inc);
          return ExercisePrescription(
            weight: deloaded,
            reps: entry.targetReps,
            sets: plannedSets,
            restSeconds: entry.restSeconds,
            policyKey: activePolicyKey,
            policyTitle: info.title,
            insightReason:
                'Missed target on Greyskull LP, so −10% reset to ${_fmtWeight(deloaded)} $unit.',
            lastSessionSummary: lastSummary,
            lastSessionDate: lastDate,
            lastSessionTimestamp: latest.log.startedAt,
          );
        }
        break;

      case 'double':
      case 'steady':
        final minReps = (entry.targetRepsMin ?? math.max(1, entry.targetReps - 4))
            .clamp(1, entry.targetReps);
        if (isClean) {
          final nextW = topWeight > 0 ? snapToStep(topWeight + inc, inc) : 0.0;
          return ExercisePrescription(
            weight: nextW,
            reps: minReps,
            sets: plannedSets,
            restSeconds: entry.restSeconds,
            policyKey: activePolicyKey,
            policyTitle: info.title,
            insightReason: nextW > topWeight
                ? 'Topped out $minReps–${entry.targetReps} reps, so +${_fmtWeight(inc)} $unit at $minReps reps.'
                : 'Hit all ${entry.targetReps} reps—keep climbing.',
            lastSessionSummary: lastSummary,
            lastSessionDate: lastDate,
            lastSessionTimestamp: latest.log.startedAt,
          );
        }
        final nextReps = activePolicyKey == 'steady'
            ? (lowReps + 1).clamp(minReps, entry.targetReps)
            : (lowReps + 1).clamp(minReps, entry.targetReps);
        return ExercisePrescription(
          weight: topWeight,
          reps: nextReps,
          sets: plannedSets,
          restSeconds: entry.restSeconds,
          policyKey: activePolicyKey,
          policyTitle: info.title,
          insightReason:
              'Same ${_fmtWeight(topWeight)} $unit, aim for $nextReps reps.',
          lastSessionSummary: lastSummary,
          lastSessionDate: lastDate,
          lastSessionTimestamp: latest.log.startedAt,
        );

      case 'triple':
        final minReps = (entry.targetRepsMin ?? math.max(1, entry.targetReps - 4))
            .clamp(1, entry.targetReps);
        final maxSets = (entry.targetSetsMax ?? (plannedSets + 2)).clamp(plannedSets, 10);
        final lastSetCount = latest.workSets.length.clamp(plannedSets, maxSets);
        final cleanAtLastSets = latest.workSets.length >= lastSetCount &&
            latest.workSets.take(lastSetCount).every((s) => s.reps >= entry.targetReps);
        if (cleanAtLastSets) {
          if (lastSetCount < maxSets) {
            return ExercisePrescription(
              weight: topWeight,
              reps: entry.targetReps,
              sets: lastSetCount + 1,
              restSeconds: entry.restSeconds,
              policyKey: activePolicyKey,
              policyTitle: info.title,
              insightReason:
                  'Hit top reps across $lastSetCount sets, so adding set ${lastSetCount + 1}.',
              lastSessionSummary: lastSummary,
              lastSessionDate: lastDate,
              lastSessionTimestamp: latest.log.startedAt,
            );
          }
          final nextW = topWeight > 0 ? snapToStep(topWeight + inc, inc) : 0.0;
          return ExercisePrescription(
            weight: nextW,
            reps: minReps,
            sets: plannedSets,
            restSeconds: entry.restSeconds,
            policyKey: activePolicyKey,
            policyTitle: info.title,
            insightReason:
                'Hit $maxSets × ${entry.targetReps}, so +${_fmtWeight(inc)} $unit back to $plannedSets × $minReps.',
            lastSessionSummary: lastSummary,
            lastSessionDate: lastDate,
            lastSessionTimestamp: latest.log.startedAt,
          );
        }
        return ExercisePrescription(
          weight: topWeight,
          reps: (lowReps + 1).clamp(minReps, entry.targetReps),
          sets: lastSetCount,
          restSeconds: entry.restSeconds,
          policyKey: activePolicyKey,
          policyTitle: info.title,
          insightReason:
              'Build reps at ${_fmtWeight(topWeight)} $unit across $lastSetCount sets.',
          lastSessionSummary: lastSummary,
          lastSessionDate: lastDate,
          lastSessionTimestamp: latest.log.startedAt,
        );

      case 'undulating':
        final dayIdx = sessions.length % 3;
        final label = switch (dayIdx) {
          1 => 'Heavy day',
          2 => 'Light day',
          _ => 'Medium day',
        };
        final dayReps = switch (dayIdx) {
          1 => math.max(3, (entry.targetReps * 0.6).round()),
          2 => math.min(20, (entry.targetReps * 1.5).round()),
          _ => entry.targetReps,
        };
        double bestE1rm = 0;
        for (final s in sessions.take(3)) {
          for (final r in s.workSets) {
            final est = OneRmEstimator.estimate(
              r.weight,
              r.reps,
              formula: oneRmFormula,
            );
            if (est != null && est > bestE1rm) bestE1rm = est;
          }
        }
        final prescribedW = bestE1rm > 0
            ? snapToStep(bestE1rm / (1.0 + (dayReps + 2) / 30.0), inc)
            : topWeight;
        return ExercisePrescription(
          weight: prescribedW,
          reps: dayReps,
          sets: plannedSets,
          restSeconds: entry.restSeconds,
          policyKey: activePolicyKey,
          policyTitle: info.title,
          insightReason: '$label: $plannedSets × $dayReps @ ${_fmtWeight(prescribedW)} $unit.',
          lastSessionSummary: lastSummary,
          lastSessionDate: lastDate,
          lastSessionTimestamp: latest.log.startedAt,
        );

      case 'density':
        final lastRest = latest.entry.restSeconds;
        if (isClean) {
          if (lastRest > densityFloorSeconds) {
            final nextRest = math.max(densityFloorSeconds, lastRest - densityStepSeconds);
            return ExercisePrescription(
              weight: topWeight,
              reps: entry.targetReps,
              sets: plannedSets,
              restSeconds: nextRest,
              policyKey: activePolicyKey,
              policyTitle: info.title,
              insightReason:
                  'Clean session—trimming rest by ${densityStepSeconds}s to ${nextRest}s.',
              lastSessionSummary: lastSummary,
              lastSessionDate: lastDate,
              lastSessionTimestamp: latest.log.startedAt,
            );
          }
          final nextW = topWeight > 0 ? snapToStep(topWeight + inc, inc) : 0.0;
          return ExercisePrescription(
            weight: nextW,
            reps: entry.targetReps,
            sets: plannedSets,
            restSeconds: entry.restSeconds,
            policyKey: activePolicyKey,
            policyTitle: info.title,
            insightReason:
                'Hit shortest rest floor, so +${_fmtWeight(inc)} $unit and reset rest to ${entry.restSeconds}s.',
            lastSessionSummary: lastSummary,
            lastSessionDate: lastDate,
            lastSessionTimestamp: latest.log.startedAt,
          );
        }
        return ExercisePrescription(
          weight: topWeight,
          reps: entry.targetReps,
          sets: plannedSets,
          restSeconds: lastRest,
          policyKey: activePolicyKey,
          policyTitle: info.title,
          insightReason: 'Hold ${_fmtWeight(topWeight)} $unit at ${lastRest}s rest.',
          lastSessionSummary: lastSummary,
          lastSessionDate: lastDate,
          lastSessionTimestamp: latest.log.startedAt,
        );

      case 'ladder':
        final minReps = (entry.targetRepsMin ?? math.max(1, entry.targetReps - 3))
            .clamp(1, entry.targetReps);
        if (isClean) {
          return ExercisePrescription(
            weight: topWeight,
            reps: minReps,
            sets: plannedSets,
            restSeconds: entry.restSeconds,
            policyKey: activePolicyKey,
            policyTitle: info.title,
            insightReason:
                'Owned every set at ${entry.targetReps} reps—ready for the next ladder rung!',
            lastSessionSummary: lastSummary,
            lastSessionDate: lastDate,
            lastSessionTimestamp: latest.log.startedAt,
          );
        }
        return ExercisePrescription(
          weight: topWeight,
          reps: (lowReps + 1).clamp(minReps, entry.targetReps),
          sets: plannedSets,
          restSeconds: entry.restSeconds,
          policyKey: activePolicyKey,
          policyTitle: info.title,
          insightReason: 'Aim for ${(lowReps + 1).clamp(minReps, entry.targetReps)} reps.',
          lastSessionSummary: lastSummary,
          lastSessionDate: lastDate,
          lastSessionTimestamp: latest.log.startedAt,
        );

      case 'linear':
      default:
        if (isClean) {
          if (topWeight <= 0) {
            final nextReps = entry.targetReps + 1;
            return ExercisePrescription(
              weight: 0,
              reps: nextReps,
              sets: plannedSets,
              restSeconds: entry.restSeconds,
              policyKey: 'linear',
              policyTitle: info.title,
              insightReason: 'Hit every target rep last time, so +1 rep.',
              lastSessionSummary: lastSummary,
              lastSessionDate: lastDate,
              lastSessionTimestamp: latest.log.startedAt,
            );
          }
          final nextW = snapToStep(topWeight + inc, inc);
          return ExercisePrescription(
            weight: nextW,
            reps: entry.targetReps,
            sets: plannedSets,
            restSeconds: entry.restSeconds,
            policyKey: 'linear',
            policyTitle: info.title,
            insightReason:
                'Hit every target rep last time, so +${_fmtWeight(inc)} $unit.',
            lastSessionSummary: lastSummary,
            lastSessionDate: lastDate,
            lastSessionTimestamp: latest.log.startedAt,
          );
        }
        if (stalls >= 3 && topWeight > 0) {
          final deloaded = snapToStep(topWeight * entry.deloadFactor, inc);
          return ExercisePrescription(
            weight: deloaded,
            reps: entry.targetReps,
            sets: plannedSets,
            restSeconds: entry.restSeconds,
            policyKey: 'linear',
            policyTitle: info.title,
            insightReason:
                'Missed 3 times in a row, so −10% deload to ${_fmtWeight(deloaded)} $unit.',
            lastSessionSummary: lastSummary,
            lastSessionDate: lastDate,
            lastSessionTimestamp: latest.log.startedAt,
          );
        }
        return ExercisePrescription(
          weight: topWeight,
          reps: entry.targetReps,
          sets: plannedSets,
          restSeconds: entry.restSeconds,
          policyKey: 'linear',
          policyTitle: info.title,
          insightReason: 'Missed target reps last time, so same weight again.',
          lastSessionSummary: lastSummary,
          lastSessionDate: lastDate,
          lastSessionTimestamp: latest.log.startedAt,
        );
    }

    return ExercisePrescription(
      weight: entry.defaultWeight,
      reps: entry.targetReps,
      sets: entry.targetSets,
      restSeconds: entry.restSeconds,
      policyKey: activePolicyKey,
      policyTitle: info.title,
      insightReason: 'Nothing logged yet, so this session sets the baseline.',
    );
  }

  /// Generates `LAST TIME AND NEXT TIME` comparison cards for [completed].
  List<PostWorkoutComparison> compareAfterWorkout(
    WorkoutLog completed,
    List<WorkoutLog> historyIncludingCompleted, {
    String unit = 'kg',
  }) {
    final priorHistory = historyIncludingCompleted
        .where((w) => w.id != completed.id)
        .toList();
    final out = <PostWorkoutComparison>[];

    for (final entry in completed.entries) {
      final work = entry.sets.where((s) => s.isCompleted && !s.isWarmup).toList();
      if (work.isEmpty) continue;

      final todayTopW = work.fold<double>(0, (m, s) => s.weight > m ? s.weight : m);
      final todayTopR = work.fold<int>(0, (m, s) => s.reps > m ? s.reps : m);
      final todaySummary =
          '${_fmtWeight(todayTopW)} $unit · ${work.length} × $todayTopR';

      String? lastSummary;
      for (final log in priorHistory) {
        final match = log.entries
            .where((e) => e.exerciseId == entry.exerciseId)
            .firstOrNull;
        if (match == null) continue;
        final prevWork = match.sets
            .where((s) => s.isCompleted && !s.isWarmup)
            .toList();
        if (prevWork.isEmpty) continue;
        final pw = prevWork.fold<double>(0, (m, s) => s.weight > m ? s.weight : m);
        final pr = prevWork.fold<int>(0, (m, s) => s.reps > m ? s.reps : m);
        lastSummary = '${_fmtWeight(pw)} $unit · ${prevWork.length} × $pr';
        break;
      }

      final syntheticTemplateEntry = WorkoutTemplateEntry(
        exerciseId: entry.exerciseId,
        exerciseName: entry.exerciseName,
        bodyPart: entry.bodyPart,
        equipment: entry.equipment,
        targetSets: work.length,
        targetReps: todayTopR > 0 ? todayTopR : 8,
        defaultWeight: todayTopW,
        restSeconds: entry.restSeconds,
        progressionPolicy: entry.progressionMode,
      );

      final nextRx = prescribe(
        entry: syntheticTemplateEntry,
        history: historyIncludingCompleted,
        routinePolicy: entry.progressionMode,
        unit: unit,
      );
      final steppedUp = nextRx.weight > todayTopW || nextRx.reps > todayTopR;
      final nextSummary =
          '${_fmtWeight(nextRx.weight)} $unit · ${nextRx.sets} × ${nextRx.reps}';

      out.add(
        PostWorkoutComparison(
          exerciseId: entry.exerciseId,
          exerciseName: entry.exerciseName,
          todaySummary: todaySummary,
          lastTimeSummary: lastSummary,
          nextTimeSummary: nextSummary,
          steppedUp: steppedUp,
        ),
      );
    }

    return out;
  }

  static String _relativeDateLabel(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(target).inDays;
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final datePart = '${dt.day} ${months[dt.month - 1]}';
    if (diffDays <= 0) return 'today, $datePart';
    if (diffDays == 1) return 'yesterday, $datePart';
    return '$diffDays days ago, $datePart';
  }

  /// Groups adjacent entries sharing a non-null `supersetId` into units.
  static List<List<int>> supersetUnits(List<WorkoutTemplateEntry> entries) {
    final units = <List<int>>[];
    for (var i = 0; i < entries.length; i++) {
      final sg = entries[i].supersetId;
      if (sg != null &&
          sg.isNotEmpty &&
          units.isNotEmpty &&
          entries[units.last.first].supersetId == sg) {
        units.last.add(i);
      } else {
        units.add(<int>[i]);
      }
    }
    return units;
  }

  /// Clears orphaned single-entry superset IDs.
  static List<WorkoutTemplateEntry> cleanupTemplateSupersets(
    List<WorkoutTemplateEntry> entries,
  ) {
    final counts = <String, int>{};
    for (final e in entries) {
      if (e.supersetId != null && e.supersetId!.isNotEmpty) {
        counts[e.supersetId!] = (counts[e.supersetId!] ?? 0) + 1;
      }
    }
    return entries.map((e) {
      if (e.supersetId != null && (counts[e.supersetId!] ?? 0) < 2) {
        return e.copyWith(clearSuperset: true);
      }
      return e;
    }).toList();
  }
}
