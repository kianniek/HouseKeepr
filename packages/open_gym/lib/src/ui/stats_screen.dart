import 'package:flutter/material.dart';

import '../models/workout_log.dart';
import '../state/open_gym_controller.dart';
import 'measurements_screen.dart';
import 'progress_photos_screen.dart';
import 'tools_screen.dart';
import 'widgets/activity_heatmap_widget.dart';
import 'widgets/body_map_widget.dart';
import 'widgets/line_chart_widget.dart';
import 'workout_history_screen.dart';

/// Stats screen matching `stats_overview.png`, `stats_body.png`,
/// `stats_lifts.png`, and `stats_effort.png` with Material 3 components.
class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    required this.controller,
    this.embedded = false,
  });

  final OpenGymController controller;
  final bool embedded;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

enum _StatsTab { overview, body, lifts, effort }

class _StatsScreenState extends State<StatsScreen> {
  _StatsTab _tab = _StatsTab.overview;
  bool _heatmapVolume = false;
  String? _selectedLiftId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final history = widget.controller.history;
        final unit = widget.controller.preferences.weightUnit;

        final bodyContent = ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Stats',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Progress & history',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Gym Tools',
                  icon: const Icon(Icons.calculate_outlined),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ToolsScreen(controller: widget.controller),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Workout History',
                  icon: const Icon(Icons.history),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('History')),
                        body: WorkoutHistoryScreen(
                          controller: widget.controller,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<_StatsTab>(
              segments: const <ButtonSegment<_StatsTab>>[
                ButtonSegment<_StatsTab>(
                  value: _StatsTab.overview,
                  label: Text('Overview'),
                ),
                ButtonSegment<_StatsTab>(
                  value: _StatsTab.body,
                  label: Text('Body'),
                ),
                ButtonSegment<_StatsTab>(
                  value: _StatsTab.lifts,
                  label: Text('Lifts'),
                ),
                ButtonSegment<_StatsTab>(
                  value: _StatsTab.effort,
                  label: Text('Effort'),
                ),
              ],
              selected: <_StatsTab>{_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(height: 16),
            if (_tab == _StatsTab.overview)
              ..._buildOverview(context, history, unit),
            if (_tab == _StatsTab.body) ..._buildBody(context, unit),
            if (_tab == _StatsTab.lifts) ..._buildLifts(context, history, unit),
            if (_tab == _StatsTab.effort) ..._buildEffort(context, history),
          ],
        );

        if (widget.embedded) {
          return bodyContent;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Stats')),
          body: bodyContent,
        );
      },
    );
  }

  List<Widget> _buildOverview(
    BuildContext context,
    List<WorkoutLog> history,
    String unit,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final thisMonthCount = history.where((w) {
      final dt = DateTime.tryParse(w.startedAt)?.toLocal();
      return dt != null && dt.year == now.year && dt.month == now.month;
    }).length;
    final totalSets = history.fold<int>(
      0,
      (sum, w) => sum + w.completedSetsCount,
    );
    final totalHours =
        (history.fold<int>(0, (s, w) => s + w.durationSeconds) / 3600.0);
    final lifetimeVol = widget.controller.totalLifetimeVolume;
    final formattedLifetime = lifetimeVol >= 1000
        ? '${(lifetimeVol / 1000).toStringAsFixed(1)} t'
        : '${lifetimeVol.toStringAsFixed(0)} $unit';
    final lifetimeWeightFun = lifetimeVol >= 75000
        ? 'About the weight of a space shuttle orbiter'
        : lifetimeVol >= 15000
            ? 'About the weight of a school bus'
            : lifetimeVol >= 5000
                ? 'About the weight of an adult elephant'
                : lifetimeVol >= 500
                    ? 'About the weight of a grand piano'
                    : 'Every rep adds up';

    final cutoff30 = now.subtract(const Duration(days: 30));
    final weighIns = widget.controller.weighIns;
    String weight30dText = '—';
    if (weighIns.length >= 2) {
      final latestW = weighIns.first.weightKg;
      final older = weighIns.where((w) {
        final dt = DateTime.tryParse(w.date);
        return dt != null && !dt.isAfter(cutoff30);
      }).firstOrNull ??
          weighIns.last;
      final diff = latestW - older.weightKg;
      final sign = diff > 0 ? '+' : '';
      weight30dText = '$sign${diff.toStringAsFixed(1)} $unit';
    }
    final streak = widget.controller.weeklyStreak;

    return <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MiniStat(
                      label: 'Workouts',
                      value: '${history.length}',
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'This month',
                      value: '$thisMonthCount',
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'Weight 30d',
                      value: weight30dText,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'Lifted in total',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formattedLifetime,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${history.length} workouts • $totalSets sets • ${totalHours.toStringAsFixed(1)} h',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                lifetimeWeightFun,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${streak.currentWeeks} week streak',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Best ${streak.longestWeeks} weeks',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: <int>[2, 4, 8, 12, 26, 52].map((w) {
                  final reached = streak.longestWeeks >= w;
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        reached ? colorScheme.primaryContainer : null,
                    label: Text(
                      '${w}w',
                      style: TextStyle(
                        color: reached ? colorScheme.onPrimaryContainer : null,
                        fontWeight: reached ? FontWeight.w700 : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const <ButtonSegment<bool>>[
          ButtonSegment<bool>(value: false, label: Text('Time')),
          ButtonSegment<bool>(value: true, label: Text('Volume')),
        ],
        selected: <bool>{_heatmapVolume},
        onSelectionChanged: (s) => setState(() => _heatmapVolume = s.first),
      ),
      const SizedBox(height: 8),
      ActivityHeatmapWidget(history: history, byVolume: _heatmapVolume),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('Recent workouts', style: theme.textTheme.titleMedium),
          TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('History')),
                  body: WorkoutHistoryScreen(controller: widget.controller),
                ),
              ),
            ),
            child: Text('All ${history.length} >'),
          ),
        ],
      ),
      if (history.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No workouts logged yet.'),
          ),
        )
      else
        ...history.take(3).map(
              (w) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.fitness_center, size: 18),
                  ),
                  title: Text(w.title),
                  subtitle: Text(
                    '${w.completedSetsCount} sets • ${w.totalVolume.toStringAsFixed(0)} $unit'
                    '${w.caloriesKcal != null ? ' • ${w.caloriesKcal!.round()} kcal' : ''}'
                    '${w.avgHeartRateBpm != null ? ' • ${w.avgHeartRateBpm} bpm' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
      if (widget.controller.dailyHealthMetrics.isNotEmpty ||
          widget.controller.externalWorkouts.isNotEmpty) ...<Widget>[
        const SizedBox(height: 16),
        Text('Health Connect', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _buildHealthConnectOverviewCard(context),
      ],
    ];
  }

  Widget _buildHealthConnectOverviewCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = widget.controller.dailyHealthMetrics;
    final externals = widget.controller.externalWorkouts;

    final recent7 = metrics.take(7).toList();
    final activeKcal7d = recent7.fold<double>(
      0,
      (sum, d) => sum + d.activeCaloriesKcal,
    );
    final hrDays = recent7.where((d) => d.avgHeartRateBpm != null).toList();
    final avgHr = hrDays.isEmpty
        ? null
        : (hrDays.fold<int>(0, (s, d) => s + d.avgHeartRateBpm!) /
                hrDays.length)
            .round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _MiniStat(
                    label: 'Active kcal (7d)',
                    value: '${activeKcal7d.round()}',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Avg HR (7d)',
                    value: avgHr != null ? '$avgHr bpm' : '—',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'External sessions',
                    value: '${externals.length}',
                  ),
                ),
              ],
            ),
            if (externals.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              const Divider(),
              ...externals.take(3).map(
                    (ext) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        Icons.directions_run_rounded,
                        color: colorScheme.secondary,
                      ),
                      title: Text(ext.title),
                      subtitle: Text(
                        '${(ext.durationSeconds / 60).round()} min'
                        '${ext.caloriesKcal != null ? ' • ${ext.caloriesKcal!.round()} kcal' : ''}'
                        '${ext.avgHeartRateBpm != null ? ' • ${ext.avgHeartRateBpm} bpm' : ''}',
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context, String unit) {
    final theme = Theme.of(context);
    final weighIns = widget.controller.weighIns;
    final values = weighIns.reversed.map((w) => w.weightKg).toList();

    return <Widget>[
      Text('Body', style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Body weight ($unit)',
                      style: theme.textTheme.titleMedium),
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Body & Weigh-ins')),
                          body: MeasurementsScreen(
                            controller: widget.controller,
                          ),
                        ),
                      ),
                    ),
                    child: const Text('All weigh-ins >'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OpenGymLineChart(
                values: values,
                goalValue: widget.controller.preferences.goalWeightKg,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text('More', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: <Widget>[
            ListTile(
              title: const Text('Body measurements'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Body Measurements')),
                    body: MeasurementsScreen(controller: widget.controller),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Progress photos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ProgressPhotosScreen(controller: widget.controller),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Tools & Calculators'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ToolsScreen(controller: widget.controller),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildLifts(
    BuildContext context,
    List<WorkoutLog> history,
    String unit,
  ) {
    final theme = Theme.of(context);
    final prs = widget.controller.allPersonalRecords;
    final activeId = _selectedLiftId ?? (prs.isNotEmpty ? prs.first.exerciseId : null);

    final points = <double>[];
    String activeName = 'Select an exercise';
    if (activeId != null) {
      for (final log in history.reversed) {
        for (final entry in log.entries) {
          if (entry.exerciseId != activeId) continue;
          activeName = entry.exerciseName;
          final maxW = entry.sets
              .where((s) => s.isCompleted && !s.isWarmup)
              .fold<double>(0, (m, s) => s.weight > m ? s.weight : m);
          if (maxW > 0) points.add(maxW);
        }
      }
    }

    return <Widget>[
      Text('Lifts', style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (prs.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: activeId,
                  decoration: const InputDecoration(
                    labelText: 'Exercise progress',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: prs
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p.exerciseId,
                          child: Text(p.exerciseName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedLiftId = v),
                )
              else
                Text(activeName, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              OpenGymLineChart(values: points),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      BodyMapWidget(
        weeklySetsByBodyPart: widget.controller.weeklySetsByBodyPart,
      ),
    ];
  }

  List<Widget> _buildEffort(
    BuildContext context,
    List<WorkoutLog> history,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    int totalSets = 0;
    int failureSets = 0;
    int ratedSets = 0;
    double rirSum = 0;
    final rirBuckets = List<int>.filled(5, 0); // 0, 1, 2, 3, 4+
    final timeByExercise = <String, int>{};

    for (final log in history) {
      final entryCount = log.entries.isEmpty ? 1 : log.entries.length;
      final perEntrySec = log.durationSeconds ~/ entryCount;
      for (final entry in log.entries) {
        timeByExercise[entry.exerciseName] =
            (timeByExercise[entry.exerciseName] ?? 0) + perEntrySec;
        for (final s in entry.sets) {
          if (!s.isCompleted || s.isWarmup) continue;
          totalSets++;
          if (s.isFailure || (s.rpe != null && s.rpe! >= 9.5)) {
            failureSets++;
          }
          final effectiveRir = s.rir ?? (s.rpe != null ? (10 - s.rpe!).round() : null);
          if (effectiveRir != null) {
            ratedSets++;
            rirSum += effectiveRir;
            final bucket = effectiveRir.clamp(0, 4);
            rirBuckets[bucket]++;
          }
        }
      }
    }

    final sortedTimes = timeByExercise.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxSec = sortedTimes.isNotEmpty && sortedTimes.first.value > 0
        ? sortedTimes.first.value
        : 1;
    final avgRir = ratedSets > 0 ? rirSum / ratedSets : null;

    return <Widget>[
      Text('Effort', style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                avgRir != null
                    ? '${avgRir.toStringAsFixed(1)} RIR average effort'
                    : '$failureSets / $totalSets hard sets',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ratedSets > 0
                    ? '$ratedSets of $totalSets finished sets rated • $failureSets to failure'
                    : 'Rate sets with RIR or RPE in workout settings to track effort.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: totalSets > 0 ? failureSets / totalSets : 0,
                borderRadius: BorderRadius.circular(4),
              ),
              if (ratedSets > 0) ...<Widget>[
                const SizedBox(height: 14),
                Text('Where the sets land', style: theme.textTheme.labelMedium),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: <Widget>[
                        for (var b = 0; b < 5; b++)
                          if (rirBuckets[b] > 0)
                            Expanded(
                              flex: rirBuckets[b],
                              child: Container(
                                color: <Color>[
                                  colorScheme.error,
                                  Colors.orange,
                                  colorScheme.primary,
                                  colorScheme.tertiary,
                                  colorScheme.surfaceContainerHighest,
                                ][b],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  children: <String>['RIR 0', 'RIR 1', 'RIR 2', 'RIR 3', 'RIR 4+']
                      .asMap()
                      .entries
                      .map(
                        (e) => Text(
                          '${e.value}: ${rirBuckets[e.key]}',
                          style: theme.textTheme.labelSmall,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Time per exercise', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (sortedTimes.isEmpty)
                Text(
                  'Complete workouts to see time per exercise.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...sortedTimes.take(6).map((e) {
                  final mins = (e.value / 60).ceil();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(child: Text(e.key)),
                            Text('$mins min'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (e.value / maxSec).clamp(0.05, 1.0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      if (history.any(
        (w) => w.caloriesKcal != null || w.avgHeartRateBpm != null,
      )) ...<Widget>[
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Workout Calories & Heart Rate',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...history
                    .where(
                      (w) => w.caloriesKcal != null || w.avgHeartRateBpm != null,
                    )
                    .take(5)
                    .map(
                      (w) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(w.title),
                        subtitle: Text(
                          '${w.caloriesKcal != null ? '${w.caloriesKcal!.round()} kcal' : '—'}'
                          ' • '
                          '${w.avgHeartRateBpm != null ? 'Avg ${w.avgHeartRateBpm} bpm' : 'No HR'}'
                          '${w.maxHeartRateBpm != null ? ' (Max ${w.maxHeartRateBpm})' : ''}',
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    ];
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
