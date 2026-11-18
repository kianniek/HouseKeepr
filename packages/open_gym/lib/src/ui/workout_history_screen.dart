import 'package:flutter/material.dart';

import '../models/workout_log.dart';
import '../state/open_gym_controller.dart';

/// Displays completed workout logs, summary volume stats, and personal records.
class WorkoutHistoryScreen extends StatelessWidget {
  const WorkoutHistoryScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '${h}h ${m}m';
    }
    return '${minutes}m ${seconds}s';
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final unit = controller.preferences.weightUnit;
        final history = controller.history;
        final prs = controller.allPersonalRecords;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatCard(
                    label: 'Workouts',
                    value: '${history.length}',
                    icon: Icons.event_available_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Total Volume',
                    value: '${controller.totalLifetimeVolume.toStringAsFixed(0)} $unit',
                    icon: Icons.bar_chart_rounded,
                  ),
                ),
              ],
            ),
            if (prs.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text('Personal Records', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: prs.take(5).map((pr) {
                    return ListTile(
                      leading: Icon(
                        Icons.emoji_events_rounded,
                        color: colorScheme.primary,
                      ),
                      title: Text(pr.exerciseName),
                      subtitle: Text(
                        'Best 1RM: ${pr.bestE1RM.toStringAsFixed(1)} $unit',
                      ),
                      trailing: Text(
                        '${pr.bestWeight.toStringAsFixed(1)} $unit',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Recent Sessions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (history.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Complete your first workout to see history here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...history.map((log) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(log.title),
                    subtitle: Text(
                      '${_formatDate(log.startedAt)} • '
                      '${_formatDuration(log.durationSeconds)} • '
                      '${log.completedSetsCount} sets • '
                      '${log.totalVolume.toStringAsFixed(0)} $unit',
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete log',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => controller.deleteWorkoutLog(log.id),
                    ),
                    onTap: () => _showLogDetails(context, log),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  void _showLogDetails(BuildContext context, WorkoutLog log) {
    final unit = controller.preferences.weightUnit;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          shrinkWrap: true,
          children: <Widget>[
            Text(log.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${_formatDate(log.startedAt)} • '
              '${_formatDuration(log.durationSeconds)} • '
              '${log.totalVolume.toStringAsFixed(0)} $unit volume',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ...log.entries.map((entry) {
              final completed =
                  entry.sets.where((s) => s.isCompleted).toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.exerciseName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...completed.asMap().entries.map(
                          (item) => Text(
                            'Set ${item.key + 1}: ${item.value.weight} $unit × ${item.value.reps} reps'
                            '${item.value.isWarmup ? ' (Warm-up)' : ''}',
                          ),
                        ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
