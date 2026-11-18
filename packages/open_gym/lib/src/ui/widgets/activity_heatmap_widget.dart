import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/workout_log.dart';

/// 12-week GitHub-style workout consistency heatmap supporting both session
/// duration/time and total lifted volume modes.
class ActivityHeatmapWidget extends StatelessWidget {
  const ActivityHeatmapWidget({
    super.key,
    required this.history,
    this.byVolume = false,
  });

  final List<WorkoutLog> history;
  final bool byVolume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final valuesByDay = <String, double>{};

    for (final log in history) {
      final dt = DateTime.tryParse(log.startedAt)?.toLocal();
      if (dt == null) continue;
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final delta = byVolume
          ? (log.totalVolume > 0 ? log.totalVolume : 1.0)
          : math.max(1.0, log.durationSeconds / 60.0);
      valuesByDay[key] = (valuesByDay[key] ?? 0) + delta;
    }

    final maxVal = valuesByDay.values.isEmpty
        ? 1.0
        : valuesByDay.values.reduce(math.max);

    final today = DateTime.now();
    const weeks = 12;
    final start = today.subtract(Duration(days: weeks * 7 - 1));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '12-Week Activity (${byVolume ? 'Volume' : 'Time'})',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 108,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List<Widget>.generate(weeks, (w) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List<Widget>.generate(7, (d) {
                      final day = start.add(Duration(days: w * 7 + d));
                      final key =
                          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                      final val = valuesByDay[key] ?? 0;
                      final ratio = maxVal > 0 ? (val / maxVal) : 0.0;
                      final color = val <= 0
                          ? colorScheme.surfaceContainerHighest
                          : colorScheme.primary.withValues(
                              alpha: (0.30 + ratio * 0.70).clamp(0.30, 1.0),
                            );
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
