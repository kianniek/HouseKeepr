import 'package:flutter/material.dart';

import '../models/exercise_set.dart';
import '../models/workout_log.dart';
import '../state/open_gym_controller.dart';
import '../state/personal_record_service.dart';
import 'widgets/body_map_widget.dart';
import 'widgets/exercise_media_view.dart';
import 'widgets/exercise_menu_sheet.dart';
import 'widgets/workout_session_sheets.dart';

/// Live workout session logger matching the `GymSessionStart` screenshots
/// with Material 3 components.
class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  int _selectedEntryIndex = 0;
  int _lastRestCompletedNonce = 0;
  bool _showScreenFlash = false;
  final Set<String> _expandedAnimationIds = <String>{};
  final Set<String> _collapsedAnimationIds = <String>{};
  final Map<String, bool> _animationPlaying = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _lastRestCompletedNonce = widget.controller.restCompletedNonce;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final nonce = widget.controller.restCompletedNonce;
    if (nonce != _lastRestCompletedNonce) {
      _lastRestCompletedNonce = nonce;
      if (widget.controller.preferences.flashScreen && mounted) {
        setState(() => _showScreenFlash = true);
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (mounted) setState(() => _showScreenFlash = false);
        });
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$mm:$ss';
    return '$minutes:$ss';
  }

  Future<void> _addExercise() async {
    final picked = await showAddExerciseSheet(
      context,
      controller: widget.controller,
    );
    if (picked != null) {
      widget.controller.addExerciseToActiveWorkout(picked);
      final count = widget.controller.activeWorkout?.entries.length ?? 1;
      setState(() => _selectedEntryIndex = (count - 1).clamp(0, count));
    }
  }

  Future<void> _openWorkoutMenu() async {
    final action = await showWorkoutMenuSheet(
      context,
      controller: widget.controller,
    );
    if (!mounted) return;
    if (action == WorkoutMenuAction.addExercise) {
      await _addExercise();
    }
  }

  Future<void> _openFinishFlow() async {
    final workout = widget.controller.activeWorkout;
    if (workout == null) return;

    final choice = await showFinishWorkoutSheet(
      context,
      workout: workout,
    );
    if (!mounted || choice == null) return;

    if (choice == FinishWorkoutChoice.discardWorkout) {
      final confirmed = await showDiscardWorkoutDialog(context);
      if (confirmed == true) {
        widget.controller.discardWorkout();
        if (mounted) Navigator.of(context).pop();
      }
      return;
    }

    final prCount = widget.controller.sessionPrs.length;
    final completed = await widget.controller.finishWorkout();
    if (!mounted) return;
    if (completed != null) {
      await showWorkoutCompleteSummarySheet(
        context,
        controller: widget.controller,
        completed: completed,
        prCount: prCount,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = widget.controller;

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

        final prefs = controller.preferences;
        final unit = prefs.weightUnit;
        final totalSets = workout.totalSetsCount;
        final doneSets = workout.completedSetsCount;
        final progress = totalSets > 0 ? doneSets / totalSets : 0.0;
        final layout = prefs.workoutLayout;

        if (_selectedEntryIndex >= workout.entries.length &&
            workout.entries.isNotEmpty) {
          _selectedEntryIndex = workout.entries.length - 1;
        }

        final currentEntry = workout.entries.isNotEmpty
            ? workout.entries[_selectedEntryIndex]
            : null;
        final activeBodyParts = <String, int>{
          for (final e in workout.entries) e.bodyPart: 4,
        };

        return Stack(
          children: <Widget>[
            Scaffold(
              appBar: AppBar(
                leading: IconButton.filledTonal(
                  tooltip: 'Minimize workout',
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                centerTitle: true,
                title: Column(
                  children: <Widget>[
                    Text(
                      workout.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          if (controller.isPaused)
                            TextSpan(
                              text: 'Paused ',
                              style: TextStyle(
                                color: colorScheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          TextSpan(
                            text:
                                '${_formatDuration(controller.elapsedSeconds)} • $doneSets/$totalSets sets',
                          ),
                        ],
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                actions: <Widget>[
                  IconButton.filledTonal(
                    tooltip: 'Workout menu',
                    icon: const Icon(Icons.more_horiz),
                    onPressed: _openWorkoutMenu,
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton(
                      onPressed: _openFinishFlow,
                      child: const Text('Finish'),
                    ),
                  ),
                ],
              ),
              body: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${workout.totalVolume.toStringAsFixed(0)} $unit',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.isPaused)
                    _PausedWorkoutBanner(
                      onResume: controller.togglePause,
                    ),
                  if (controller.isResting)
                    _RestTimerBanner(
                      remainingSeconds: controller.restRemainingSeconds,
                      totalSeconds: controller.restTotalSeconds,
                      formattedTime:
                          _formatDuration(controller.restRemainingSeconds),
                      onAdjust: controller.addRest,
                      onSkip: controller.skipRest,
                    ),
              if (workout.entries.isNotEmpty && layout != 'list')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List<Widget>.generate(
                              workout.entries.length,
                              (i) {
                                final isSelected = i == _selectedEntryIndex;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () =>
                                        setState(() => _selectedEntryIndex = i),
                                    child: CircleAvatar(
                                      radius: 17,
                                      backgroundColor: isSelected
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHighest,
                                      foregroundColor: isSelected
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurfaceVariant,
                                      child: Text(
                                        '${i + 1}',
                                        style: theme.textTheme.labelLarge,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BodyMapWidget(
                        weeklySetsByBodyPart: activeBodyParts,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: currentEntry == null
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
                              onPressed: _addExercise,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Exercise'),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: <Widget>[
                          if (layout == 'focus')
                            _buildFocusSection(
                              context,
                              entryIndex: _selectedEntryIndex,
                              entry: currentEntry,
                              unit: unit,
                            )
                          else if (layout == 'list')
                            ...List<Widget>.generate(
                              workout.entries.length,
                              (idx) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildExerciseSection(
                                  context,
                                  entryIndex: idx,
                                  entry: workout.entries[idx],
                                  workout: workout,
                                  unit: unit,
                                  compact: false,
                                ),
                              ),
                            )
                          else
                            _buildExerciseSection(
                              context,
                              entryIndex: _selectedEntryIndex,
                              entry: currentEntry,
                              workout: workout,
                              unit: unit,
                              compact: layout == 'compact',
                            ),
                          if (layout != 'list') ...<Widget>[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                TextButton.icon(
                                  onPressed: _selectedEntryIndex > 0
                                      ? () => setState(
                                          () => _selectedEntryIndex--)
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                  label: const Text('Prev'),
                                ),
                                TextButton(
                                  onPressed: _selectedEntryIndex <
                                          workout.entries.length - 1
                                      ? () => setState(
                                          () => _selectedEntryIndex++)
                                      : null,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text('Next'),
                                      SizedBox(width: 4),
                                      Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Card(
                            child: Column(
                              children: <Widget>[
                                ListTile(
                                  leading: Icon(
                                    Icons.add_circle_outline,
                                    color: colorScheme.primary,
                                  ),
                                  title: Text(
                                    'Add exercise',
                                    style: TextStyle(color: colorScheme.primary),
                                  ),
                                  onTap: _addExercise,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading:
                                      const Icon(Icons.sticky_note_2_outlined),
                                  title: Text(
                                    (workout.notes?.isNotEmpty ?? false)
                                        ? 'Session note'
                                        : 'Add session note',
                                  ),
                                  subtitle:
                                      (workout.notes?.isNotEmpty ?? false)
                                          ? Text(
                                              workout.notes!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          : null,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => showSessionNoteSheet(
                                    context,
                                    controller: controller,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final doneExercises = workout.entries
                                  .where(
                                    (e) =>
                                        e.sets.isNotEmpty &&
                                        e.sets.every((s) => s.isCompleted),
                                  )
                                  .length;
                              return Center(
                                child: TextButton(
                                  onPressed: _openFinishFlow,
                                  child: Text(
                                    'Finish workout early · $doneExercises/${workout.entries.length} exercises ($doneSets/$totalSets sets)',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
            ),
            if (_showScreenFlash)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showScreenFlash ? 0.65 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(color: colorScheme.primary),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildExerciseSection(
    BuildContext context, {
    required int entryIndex,
    required WorkoutEntry entry,
    required WorkoutLog workout,
    required String unit,
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = widget.controller;
    final prefs = controller.preferences;
    final animSize = prefs.exerciseAnimationSize;
    final effortMode = prefs.effortMode;
    final swipeEnabled = prefs.swipeActionsEnabled;

    final isExpanded = animSize != 'hidden' &&
        ((animSize == 'full' && !_collapsedAnimationIds.contains(entry.exerciseId)) ||
            _expandedAnimationIds.contains(entry.exerciseId));
    final isPlaying = _animationPlaying[entry.exerciseId] ?? true;
    final prescription = controller.prescribeForActiveEntry(entry);
    final baseline = controller.recordBaselineFor(
      entry.exerciseId,
      name: entry.exerciseName,
    );
    final workSets = entry.sets.where((s) => !s.isWarmup).toList();
    final planReps =
        workSets.isNotEmpty ? workSets.first.reps : prescription.reps;
    final showBarbellPlates =
        entry.equipment.toLowerCase().contains('barbell') ||
            entry.equipment.toLowerCase().contains('smith');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (isExpanded) ...<Widget>[
          Stack(
            children: <Widget>[
              GestureDetector(
                onTap: () => setState(() {
                  _animationPlaying[entry.exerciseId] = !isPlaying;
                }),
                child: ExerciseAnimationView(
                  exerciseId: entry.exerciseId,
                  controller: controller,
                  height: null,
                  isPlaying: isPlaying,
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        colorScheme.inverseSurface.withValues(alpha: 0.78),
                    foregroundColor: colorScheme.onInverseSurface,
                  ),
                  onPressed: () => setState(() {
                    _expandedAnimationIds.remove(entry.exerciseId);
                    _collapsedAnimationIds.add(entry.exerciseId);
                  }),
                  icon: const Icon(Icons.close_fullscreen, size: 16),
                  label: const Text('Minimize'),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        colorScheme.inverseSurface.withValues(alpha: 0.78),
                    foregroundColor: colorScheme.onInverseSurface,
                  ),
                  onPressed: () => setState(() {
                    _animationPlaying[entry.exerciseId] = !isPlaying;
                  }),
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 16,
                  ),
                  label: Text(isPlaying ? 'Tap to pause' : 'Tap to play'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: <Widget>[
            if (animSize != 'hidden' && !isExpanded) ...<Widget>[
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  _collapsedAnimationIds.remove(entry.exerciseId);
                  _expandedAnimationIds.add(entry.exerciseId);
                  _animationPlaying[entry.exerciseId] = true;
                }),
                child: ExerciseStillThumbnail(
                  exerciseId: entry.exerciseId,
                  mediaService: controller.mediaService,
                  serverUrl: controller.serverConnection?.serverUrl,
                  size: 52,
                  showMaximizeBadge: true,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                entry.exerciseName,
                style: (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Exercise options',
              icon: const Icon(Icons.more_horiz),
              onPressed: () => showExerciseMenuSheet(
                context,
                controller: controller,
                entryIndex: entryIndex,
              ),
            ),
          ],
        ),
        if (!workout.countForProgression || !entry.countForProgression) ...<Widget>[
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(
                Icons.trending_down_outlined,
                size: 16,
                color: colorScheme.tertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Not counted for progression',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.tertiary,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () {
                  if (!workout.countForProgression) {
                    controller.setCountForProgression(true);
                  }
                  if (!entry.countForProgression) {
                    controller.setEntryCountForProgression(entryIndex, true);
                  }
                },
                child: const Text('Undo'),
              ),
            ],
          ),
        ],
        if (entry.notes?.isNotEmpty ?? false) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            entry.notes!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (!compact) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              Chip(
                label: Text(entry.bodyPart),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(entry.equipment),
                visualDensity: VisualDensity.compact,
              ),
              if (baseline.bestWeight > 0)
                Chip(
                  label: Text(
                    'Best: ${baseline.bestWeight % 1 == 0 ? baseline.bestWeight.toInt() : baseline.bestWeight.toStringAsFixed(1)} $unit',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Plan: ${workSets.length} × $planReps',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (prescription.lastSessionSummary != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            'Last time (${prescription.lastSessionDate ?? ''}): ${prescription.lastSessionSummary}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.lightbulb_outline,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '${prescription.policyTitle} · ',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: prescription.insightReason,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const SizedBox(width: 36),
                    Expanded(
                      child: Center(
                        child: Text(
                          entry.mode == ExerciseMode.cardio
                              ? 'Speed'
                              : 'Weight ($unit)',
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Center(
                        child: Text(
                          entry.mode == ExerciseMode.time
                              ? 'Sec'
                              : entry.mode == ExerciseMode.distance
                                  ? 'Meters'
                                  : entry.mode == ExerciseMode.cardio
                                      ? 'Min'
                                      : 'Reps',
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    ),
                    if (effortMode != 'off') ...<Widget>[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Center(
                          child: Text(
                            effortMode.toUpperCase(),
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 8),
                ...entry.sets.asMap().entries.map((setItem) {
                  final setIdx = setItem.key;
                  final set = setItem.value;
                  final prs =
                      controller.sessionPrs[set.id] ?? const <RecordKind>[];
                  String? plateBreakdown;
                  if (showBarbellPlates &&
                      set.weight > prefs.barWeightKg) {
                    final platesMap =
                        controller.analytics.calculatePlatesPerSide(
                      targetWeight: set.weight,
                      barWeight: prefs.barWeightKg,
                    );
                    if (platesMap.isNotEmpty) {
                      final parts = <String>[];
                      for (final pe in platesMap.entries) {
                        for (var c = 0; c < pe.value; c++) {
                          parts.add(
                            pe.key % 1 == 0
                                ? '${pe.key.toInt()}'
                                : pe.key.toString(),
                          );
                        }
                      }
                      plateBreakdown =
                          '${parts.join(' + ')} per side (${prefs.barWeightKg.toStringAsFixed(0)} $unit bar)';
                    }
                  }
                  final row = _StepperSetRow(
                    key: ValueKey<String>(set.id),
                    setNumber: setIdx + 1,
                    set: set,
                    prs: prs,
                    effortMode: effortMode,
                    plateHint: plateBreakdown,
                    onWeightChanged: (w) => controller.updateSet(
                      entryIndex,
                      setIdx,
                      weight: w,
                    ),
                    onRepsChanged: (r) => controller.updateSet(
                      entryIndex,
                      setIdx,
                      reps: r,
                    ),
                    onEffortChanged: (val) => controller.updateSet(
                      entryIndex,
                      setIdx,
                      rpe: effortMode == 'rpe' ? val.toDouble() : null,
                      rir: effortMode == 'rir' ? val : null,
                    ),
                    onToggleWarmup: () => controller.updateSet(
                      entryIndex,
                      setIdx,
                      isWarmup: !set.isWarmup,
                    ),
                    onToggleDone: () {
                      final earned = controller.toggleSetCompleted(
                        entryIndex,
                        setIdx,
                      );
                      if (earned.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'New PR on ${entry.exerciseName}!',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onDelete: () => controller.removeSet(entryIndex, setIdx),
                  );

                  if (!swipeEnabled) return row;

                  return Dismissible(
                    key: ValueKey<String>('swipe_${set.id}'),
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 12),
                      color: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.copy,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 12),
                      color: colorScheme.errorContainer,
                      child: Icon(
                        Icons.delete_outline,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        controller.duplicateSet(entryIndex, setIdx);
                        return false;
                      }
                      controller.removeSet(entryIndex, setIdx);
                      return false;
                    },
                    child: row,
                  );
                }),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => controller.addSet(entryIndex),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add set'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFocusSection(
    BuildContext context, {
    required int entryIndex,
    required WorkoutEntry entry,
    required String unit,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = widget.controller;
    final nextIdx = entry.sets.indexWhere((s) => !s.isCompleted);
    final activeSetIdx = nextIdx >= 0 ? nextIdx : (entry.sets.length - 1);
    final set = entry.sets.isNotEmpty ? entry.sets[activeSetIdx] : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.exerciseName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Exercise options',
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => showExerciseMenuSheet(
                    context,
                    controller: controller,
                    entryIndex: entryIndex,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (set == null)
              FilledButton.icon(
                onPressed: () => controller.addSet(entryIndex),
                icon: const Icon(Icons.add),
                label: const Text('Add set'),
              )
            else ...<Widget>[
              Text(
                nextIdx < 0
                    ? 'All ${entry.sets.length} sets completed!'
                    : 'Set ${activeSetIdx + 1} of ${entry.sets.length}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text('Weight ($unit)', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              _NumericStepperPill(
                displayText: set.weight % 1 == 0
                    ? set.weight.toInt().toString()
                    : set.weight.toStringAsFixed(1),
                onMinus: () => controller.updateSet(
                  entryIndex,
                  activeSetIdx,
                  weight: (set.weight - 2.5).clamp(0, 999),
                ),
                onPlus: () => controller.updateSet(
                  entryIndex,
                  activeSetIdx,
                  weight: set.weight + 2.5,
                ),
              ),
              const SizedBox(height: 14),
              Text('Reps', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              _NumericStepperPill(
                displayText: '${set.reps}',
                onMinus: () => controller.updateSet(
                  entryIndex,
                  activeSetIdx,
                  reps: (set.reps - 1).clamp(0, 999),
                ),
                onPlus: () => controller.updateSet(
                  entryIndex,
                  activeSetIdx,
                  reps: set.reps + 1,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  controller.toggleSetCompleted(entryIndex, activeSetIdx);
                },
                icon: Icon(
                  set.isCompleted ? Icons.check_circle : Icons.check,
                ),
                label: Text(
                  set.isCompleted ? 'Completed' : 'Complete Set',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PausedWorkoutBanner extends StatelessWidget {
  const _PausedWorkoutBanner({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Card(
        color: colorScheme.tertiaryContainer,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.tertiary,
                foregroundColor: colorScheme.onTertiary,
                child: const Icon(Icons.pause, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Workout paused',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'The clock and the rest wait for you.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Resume'),
              ),
            ],
          ),
        ),
      ),
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

class _StepperSetRow extends StatelessWidget {
  const _StepperSetRow({
    super.key,
    required this.setNumber,
    required this.set,
    required this.prs,
    required this.effortMode,
    this.plateHint,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onEffortChanged,
    required this.onToggleWarmup,
    required this.onToggleDone,
    required this.onDelete,
  });

  final int setNumber;
  final ExerciseSet set;
  final List<RecordKind> prs;
  final String effortMode;
  final String? plateHint;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final ValueChanged<int> onEffortChanged;
  final VoidCallback onToggleWarmup;
  final VoidCallback onToggleDone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
        children: <Widget>[
          SizedBox(
            width: 36,
            child: InkWell(
              onTap: onToggleWarmup,
              onLongPress: onDelete,
              borderRadius: BorderRadius.circular(18),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: colorScheme.surfaceContainerHighest,
                child: prs.isNotEmpty
                    ? Icon(Icons.emoji_events,
                        size: 16, color: colorScheme.primary)
                    : Text(
                        set.isWarmup ? 'W' : '$setNumber',
                        style: theme.textTheme.labelMedium,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _NumericStepperPill(
              displayText: set.weight % 1 == 0
                  ? set.weight.toInt().toString()
                  : set.weight.toStringAsFixed(1),
              onMinus: () =>
                  onWeightChanged((set.weight - 2.5).clamp(0, 999)),
              onPlus: () => onWeightChanged(set.weight + 2.5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NumericStepperPill(
              displayText: '${set.reps}',
              onMinus: () => onRepsChanged((set.reps - 1).clamp(0, 999)),
              onPlus: () => onRepsChanged(set.reps + 1),
            ),
          ),
          if (effortMode != 'off') ...<Widget>[
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: PopupMenuButton<int>(
                tooltip: effortMode.toUpperCase(),
                onSelected: onEffortChanged,
                itemBuilder: (_) => effortMode == 'rir'
                    ? List<PopupMenuEntry<int>>.generate(
                        6,
                        (v) => PopupMenuItem<int>(
                          value: v,
                          child: Text('$v RIR'),
                        ),
                      )
                    : List<PopupMenuEntry<int>>.generate(
                        5,
                        (i) {
                          final v = 6 + i;
                          return PopupMenuItem<int>(
                            value: v,
                            child: Text('RPE $v'),
                          );
                        },
                      ),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    effortMode == 'rir'
                        ? (set.rir?.toString() ?? '—')
                        : (set.rpe != null
                            ? set.rpe!.toInt().toString()
                            : '—'),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          InkWell(
            onTap: onToggleDone,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: set.isCompleted
                    ? colorScheme.primary
                    : Colors.transparent,
                border: Border.all(
                  color: set.isCompleted
                      ? colorScheme.primary
                      : colorScheme.outline,
                  width: 2,
                ),
              ),
              child: set.isCompleted
                  ? Icon(Icons.check, size: 18, color: colorScheme.onPrimary)
                  : null,
            ),
          ),
        ],
      ),
          if (plateHint != null) ...<Widget>[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Text(
                plateHint!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NumericStepperPill extends StatelessWidget {
  const _NumericStepperPill({
    required this.displayText,
    required this.onMinus,
    required this.onPlus,
  });

  final String displayText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 38),
            icon: const Icon(Icons.remove, size: 16),
            onPressed: onMinus,
          ),
          Expanded(
            child: Center(
              child: Text(
                displayText,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 38),
            icon: const Icon(Icons.add, size: 16),
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }
}
