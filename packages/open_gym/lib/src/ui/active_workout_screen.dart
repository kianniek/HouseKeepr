import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/exercise_set.dart';
import '../state/open_gym_controller.dart';
import '../state/personal_record_service.dart';
import 'exercise_library_screen.dart';

/// Live workout session logger with elapsed timer, rest countdown, set logging,
/// and instant personal record feedback.
class ActiveWorkoutScreen extends StatelessWidget {
  const ActiveWorkoutScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }

  Future<void> _addExercise(BuildContext context) async {
    final picked = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute<Exercise>(
        builder: (_) => ExerciseLibraryScreen(
          controller: controller,
          isPicker: true,
        ),
      ),
    );
    if (picked != null) {
      controller.addExerciseToActiveWorkout(picked);
    }
  }

  Future<void> _confirmFinish(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finish Workout?'),
        content: const Text(
          'Save this workout to your local OpenGym history?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Lifting'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await controller.finishWorkout();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard Workout?'),
        content: const Text('All sets logged in this session will be lost.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    controller.discardWorkout();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final workout = controller.activeWorkout;
        if (workout == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Workout')),
            body: const Center(child: Text('No active workout.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(workout.title, style: theme.textTheme.titleMedium),
                Text(
                  '${_formatDuration(controller.elapsedSeconds)}'
                  '${controller.isPaused ? ' (Paused)' : ''}'
                  ' • ${workout.completedSetsCount}/${workout.totalSetsCount} sets',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              IconButton(
                tooltip: controller.isPaused ? 'Resume timer' : 'Pause timer',
                icon: Icon(
                  controller.isPaused ? Icons.play_arrow : Icons.pause,
                ),
                onPressed: controller.togglePause,
              ),
              TextButton(
                onPressed: () => _confirmFinish(context),
                child: const Text('Finish'),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'discard') _confirmDiscard(context);
                },
                itemBuilder: (_) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'discard',
                    child: Text('Discard workout'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              if (controller.isResting)
                _RestTimerBanner(
                  remainingSeconds: controller.restRemainingSeconds,
                  totalSeconds: controller.restTotalSeconds,
                  formattedTime:
                      _formatDuration(controller.restRemainingSeconds),
                  onAdjust: controller.addRest,
                  onSkip: controller.skipRest,
                ),
              Expanded(
                child: workout.entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.fitness_center_rounded,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No exercises yet',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () => _addExercise(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Exercise'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: workout.entries.length + 1,
                        itemBuilder: (context, index) {
                          if (index == workout.entries.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton.icon(
                                onPressed: () => _addExercise(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Exercise'),
                              ),
                            );
                          }

                          final entry = workout.entries[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          entry.exerciseName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove exercise',
                                        icon: const Icon(Icons.close, size: 20),
                                        onPressed: () => controller
                                            .removeExerciseFromActiveWorkout(
                                          index,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: <Widget>[
                                      const SizedBox(width: 40, child: Text('Set')),
                                      const Expanded(child: Text('Weight (kg)')),
                                      const SizedBox(width: 8),
                                      const Expanded(child: Text('Reps')),
                                      const SizedBox(width: 44, child: Text('Done')),
                                    ],
                                  ),
                                  const Divider(height: 12),
                                  ...entry.sets.asMap().entries.map((setItem) {
                                    final setIdx = setItem.key;
                                    final set = setItem.value;
                                    final prs =
                                        controller.sessionPrs[set.id] ??
                                            const <RecordKind>[];
                                    return _SetRow(
                                      key: ValueKey<String>(set.id),
                                      setNumber: setIdx + 1,
                                      set: set,
                                      prs: prs,
                                      onWeightChanged: (w) =>
                                          controller.updateSet(
                                        index,
                                        setIdx,
                                        weight: w,
                                      ),
                                      onRepsChanged: (r) =>
                                          controller.updateSet(
                                        index,
                                        setIdx,
                                        reps: r,
                                      ),
                                      onToggleWarmup: () =>
                                          controller.updateSet(
                                        index,
                                        setIdx,
                                        isWarmup: !set.isWarmup,
                                      ),
                                      onToggleDone: () {
                                        final earned =
                                            controller.toggleSetCompleted(
                                          index,
                                          setIdx,
                                        );
                                        if (earned.isNotEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'New PR on ${entry.exerciseName}!',
                                              ),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                      onDelete: () =>
                                          controller.removeSet(index, setIdx),
                                    );
                                  }),
                                  const SizedBox(height: 6),
                                  TextButton.icon(
                                    onPressed: () => controller.addSet(index),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add Set'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RestTimerBanner extends StatelessWidget {
  const _RestTimerBanner({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.formattedTime,
    required this.onAdjust,
    required this.onSkip,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final String formattedTime;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress =
        totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;

    return Material(
      color: colorScheme.secondaryContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.timer_outlined,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Rest $formattedTime',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => onAdjust(-15),
                  child: const Text('-15s'),
                ),
                TextButton(
                  onPressed: () => onAdjust(15),
                  child: const Text('+15s'),
                ),
                FilledButton.tonal(
                  onPressed: onSkip,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
        ],
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.setNumber,
    required this.set,
    required this.prs,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onToggleWarmup,
    required this.onToggleDone,
    required this.onDelete,
  });

  final int setNumber;
  final ExerciseSet set;
  final List<RecordKind> prs;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onToggleWarmup;
  final VoidCallback onToggleDone;
  final VoidCallback onDelete;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _repsCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: widget.set.weight > 0 ? widget.set.weight.toString() : '',
    );
    _repsCtrl = TextEditingController(
      text: widget.set.reps > 0 ? widget.set.reps.toString() : '',
    );
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 40,
            child: InkWell(
              onTap: widget.onToggleWarmup,
              onLongPress: widget.onDelete,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.set.isWarmup ? 'W' : '${widget.setNumber}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: widget.set.isWarmup
                            ? colorScheme.tertiary
                            : colorScheme.onSurface,
                      ),
                    ),
                    if (widget.prs.isNotEmpty)
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '0',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (v) {
                final parsed = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                widget.onWeightChanged(parsed);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _repsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v) ?? 0;
                widget.onRepsChanged(parsed);
              },
            ),
          ),
          const SizedBox(width: 4),
          Checkbox(
            value: widget.set.isCompleted,
            onChanged: (_) => widget.onToggleDone(),
          ),
        ],
      ),
    );
  }
}
