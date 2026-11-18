import '../models/workout_log.dart';

/// Pure Dart analytics and strength calculators for OpenGym.
class OpenGymAnalyticsService {
  const OpenGymAnalyticsService();

  static const List<double> defaultPlatesKg = <double>[
    25,
    20,
    15,
    10,
    5,
    2.5,
    1.25,
  ];

  /// Calculates the plates needed **per side** of a barbell to reach [targetWeight].
  Map<double, int> calculatePlatesPerSide({
    required double targetWeight,
    double barWeight = 20.0,
    List<double> availablePlates = defaultPlatesKg,
  }) {
    final result = <double, int>{};
    if (targetWeight <= barWeight) return result;
    double remainingPerSide = (targetWeight - barWeight) / 2.0;
    final sorted = List<double>.from(availablePlates)
      ..sort((a, b) => b.compareTo(a));

    for (final plate in sorted) {
      if (plate <= 0) continue;
      final count = (remainingPerSide + 1e-6) ~/ plate;
      if (count > 0) {
        result[plate] = count;
        remainingPerSide -= count * plate;
      }
    }
    return result;
  }

  /// Generates a 3-step progressive warm-up ramp for a working weight.
  List<({double weight, int reps})> generateWarmupRamp({
    required double workingWeight,
    double barWeight = 20.0,
  }) {
    if (workingWeight <= barWeight) {
      return <({double weight, int reps})>[
        (weight: workingWeight, reps: 8),
      ];
    }
    double roundTo25(double v) => (v / 2.5).round() * 2.5;
    return <({double weight, int reps})>[
      (weight: roundTo25(workingWeight * 0.45).clamp(barWeight, workingWeight), reps: 8),
      (weight: roundTo25(workingWeight * 0.65).clamp(barWeight, workingWeight), reps: 5),
      (weight: roundTo25(workingWeight * 0.85).clamp(barWeight, workingWeight), reps: 2),
    ];
  }

  /// Computes completed working sets per body part over the last [days] days.
  Map<String, int> weeklySetsByBodyPart(
    List<WorkoutLog> history, {
    int days = 7,
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now().toUtc())
        .subtract(Duration(days: days));
    final counts = <String, int>{};

    for (final log in history) {
      final dt = DateTime.tryParse(log.startedAt)?.toUtc();
      if (dt == null || dt.isBefore(cutoff)) continue;
      for (final entry in log.entries) {
        final completed = entry.sets
            .where((s) => s.isCompleted && !s.isWarmup)
            .length;
        if (completed > 0) {
          counts[entry.bodyPart] = (counts[entry.bodyPart] ?? 0) + completed;
        }
      }
    }
    return counts;
  }

  /// Computes current and longest consecutive-week training streaks.
  ({int currentWeeks, int longestWeeks}) weeklyStreak(
    List<WorkoutLog> history, {
    DateTime? now,
  }) {
    if (history.isEmpty) return (currentWeeks: 0, longestWeeks: 0);

    String weekKey(DateTime dt) {
      final local = dt.toLocal();
      final monday = local.subtract(Duration(days: local.weekday - 1));
      return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    }

    final weeks = <String>{};
    for (final log in history) {
      final dt = DateTime.tryParse(log.startedAt);
      if (dt != null) weeks.add(weekKey(dt));
    }
    if (weeks.isEmpty) return (currentWeeks: 0, longestWeeks: 0);

    final sorted = weeks.toList()..sort();
    int longest = 1;
    int run = 1;
    for (var i = 1; i < sorted.length; i++) {
      final prev = DateTime.parse(sorted[i - 1]);
      final curr = DateTime.parse(sorted[i]);
      if (curr.difference(prev).inDays == 7) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }

    final ref = now ?? DateTime.now();
    final thisWeek = weekKey(ref);
    final lastWeek = weekKey(ref.subtract(const Duration(days: 7)));
    int current = 0;
    if (weeks.contains(thisWeek) || weeks.contains(lastWeek)) {
      var cursor = weeks.contains(thisWeek)
          ? DateTime.parse(thisWeek)
          : DateTime.parse(lastWeek);
      while (weeks.contains(weekKey(cursor))) {
        current++;
        cursor = cursor.subtract(const Duration(days: 7));
      }
    }
    return (currentWeeks: current, longestWeeks: longest);
  }
}
