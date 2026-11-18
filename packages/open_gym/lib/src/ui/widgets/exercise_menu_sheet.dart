import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/exercise.dart';
import '../../models/workout_log.dart';
import '../../state/open_gym_controller.dart';
import '../../state/progression_service.dart';
import '../tools_screen.dart';
import 'exercise_media_view.dart';
import 'workout_session_sheets.dart';

/// Opens the per-exercise `...` menu bottom sheet matching the
/// `GymExerciseEdit` screenshots.
Future<void> showExerciseMenuSheet(
  BuildContext context, {
  required OpenGymController controller,
  required int entryIndex,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => _ExerciseMenuSheetBody(
      controller: controller,
      entryIndex: entryIndex,
    ),
  );
}

class _ExerciseMenuSheetBody extends StatefulWidget {
  const _ExerciseMenuSheetBody({
    required this.controller,
    required this.entryIndex,
  });

  final OpenGymController controller;
  final int entryIndex;

  @override
  State<_ExerciseMenuSheetBody> createState() => _ExerciseMenuSheetBodyState();
}

class _ExerciseMenuSheetBodyState extends State<_ExerciseMenuSheetBody> {
  bool _moreExpanded = false;

  String _progressionLabel(String mode) {
    if (mode == 'rpe') return 'RPE based';
    return ProgressionService.policyTitle(mode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final workout = widget.controller.activeWorkout;
        if (workout == null ||
            widget.entryIndex < 0 ||
            widget.entryIndex >= workout.entries.length) {
          return const SizedBox.shrink();
        }

        final entry = workout.entries[widget.entryIndex];
        final prefs = widget.controller.preferences;
        final isFirst = widget.entryIndex == 0;
        final isLast = widget.entryIndex >= workout.entries.length - 1;
        final hasNextSuperset = !isLast &&
            entry.supersetId != null &&
            entry.supersetId == workout.entries[widget.entryIndex + 1].supersetId;
        final restIsDefault = entry.restSeconds == prefs.defaultRestSeconds;
        final restSubtitle = restIsDefault
            ? 'Default (${formatRestLabel(entry.restSeconds)})'
            : formatRestLabel(entry.restSeconds);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: _moreExpanded ? 0.85 : 0.68,
          maxChildSize: 0.94,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: <Widget>[
              Text(
                entry.exerciseName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.sticky_note_2_outlined),
                      title: Text(
                        (entry.notes?.isNotEmpty ?? false)
                            ? 'Edit note'
                            : 'Add note',
                      ),
                      subtitle: (entry.notes?.isNotEmpty ?? false)
                          ? Text(
                              entry.notes!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () async {
                        final navCtx = Navigator.of(context).context;
                        Navigator.of(context).pop();
                        await _showEntryNoteSheet(
                          navCtx,
                          controller: widget.controller,
                          entryIndex: widget.entryIndex,
                          entry: entry,
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.swap_horiz),
                      title: const Text('Swap exercise'),
                      onTap: () async {
                        final navCtx = Navigator.of(context).context;
                        Navigator.of(context).pop();
                        final picked = await showAddExerciseSheet(
                          navCtx,
                          controller: widget.controller,
                        );
                        if (picked != null) {
                          widget.controller.swapExerciseInActiveWorkout(
                            widget.entryIndex,
                            picked,
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.wb_twilight_outlined),
                      title: const Text('Add warm-up set'),
                      onTap: () {
                        widget.controller.addWarmupSet(widget.entryIndex);
                        Navigator.of(context).pop();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Rest timer'),
                      subtitle: Text(restSubtitle),
                      onTap: () async {
                        final navCtx = Navigator.of(context).context;
                        Navigator.of(context).pop();
                        await _showEntryRestTimerSheet(
                          navCtx,
                          controller: widget.controller,
                          entryIndex: widget.entryIndex,
                          currentSeconds: entry.restSeconds,
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('History'),
                      onTap: () async {
                        final navCtx = Navigator.of(context).context;
                        Navigator.of(context).pop();
                        await _showExerciseHistorySheet(
                          navCtx,
                          controller: widget.controller,
                          entry: entry,
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (!_moreExpanded)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.more_horiz),
                    title: const Text('More'),
                    subtitle: const Text(
                      'Exercise settings, Plate loading, How to do it, Watch on YouTube',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.keyboard_arrow_down),
                    onTap: () => setState(() => _moreExpanded = true),
                  ),
                )
              else ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                  child: Text(
                    'Exercise',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.tune_outlined),
                        title: const Text('Exercise settings'),
                        subtitle: Text(_progressionLabel(entry.progressionMode)),
                        onTap: () async {
                          final navCtx = Navigator.of(context).context;
                          Navigator.of(context).pop();
                          await _showEntryProgressionSheet(
                            navCtx,
                            controller: widget.controller,
                            entryIndex: widget.entryIndex,
                            currentMode: entry.progressionMode,
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.adjust_outlined),
                        title: const Text('Plate loading'),
                        subtitle: Text(
                          'Bar ${prefs.barWeightKg.toStringAsFixed(0)} ${prefs.weightUnit}',
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ToolsScreen(controller: widget.controller),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('How to do it'),
                        onTap: () async {
                          final navCtx = Navigator.of(context).context;
                          Navigator.of(context).pop();
                          await _showHowToDoItSheet(
                            navCtx,
                            controller: widget.controller,
                            entry: entry,
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.play_arrow_outlined),
                        title: const Text('Watch on YouTube'),
                        subtitle: const Text('Opens a search for good form'),
                        onTap: () async {
                          Navigator.of(context).pop();
                          final query = Uri.encodeComponent(
                            '${entry.exerciseName} proper form',
                          );
                          final uri = Uri.parse(
                            'https://www.youtube.com/results?search_query=$query',
                          );
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                  child: Text(
                    'Order and supersets',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.link),
                        title: Text(
                          hasNextSuperset
                              ? 'Remove superset'
                              : 'Make superset with next',
                        ),
                        enabled: !isLast,
                        onTap: isLast
                            ? null
                            : () {
                                widget.controller.toggleSupersetWithNext(
                                  widget.entryIndex,
                                );
                                Navigator.of(context).pop();
                              },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.keyboard_arrow_up),
                        title: const Text('Move up'),
                        enabled: !isFirst,
                        onTap: isFirst
                            ? null
                            : () {
                                widget.controller.moveEntryUp(
                                  widget.entryIndex,
                                );
                                Navigator.of(context).pop();
                              },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.keyboard_arrow_down),
                        title: const Text('Move down'),
                        enabled: !isLast,
                        onTap: isLast
                            ? null
                            : () {
                                widget.controller.moveEntryDown(
                                  widget.entryIndex,
                                );
                                Navigator.of(context).pop();
                              },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                  child: Text(
                    'This session',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      entry.countForProgression
                          ? Icons.trending_down_outlined
                          : Icons.trending_up_outlined,
                    ),
                    title: Text(
                      entry.countForProgression
                          ? 'Don\'t count for progression'
                          : 'Count for progression',
                    ),
                    subtitle: const Text('This exercise, this session only'),
                    onTap: () {
                      widget.controller.setEntryCountForProgression(
                        widget.entryIndex,
                        !entry.countForProgression,
                      );
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
              Card(
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: Text(
                    'Remove exercise',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    widget.controller.removeExerciseFromActiveWorkout(
                      widget.entryIndex,
                    );
                    Navigator.of(context).pop();
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

Future<void> _showEntryNoteSheet(
  BuildContext context, {
  required OpenGymController controller,
  required int entryIndex,
  required WorkoutEntry entry,
}) {
  final textCtrl = TextEditingController(text: entry.notes ?? '');
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${entry.exerciseName} note',
                style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              FilledButton(
                onPressed: () {
                  controller.setEntryNote(entryIndex, textCtrl.text);
                  Navigator.of(sheetCtx).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: textCtrl,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Cue, seat pin, or tempo reminder...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showEntryRestTimerSheet(
  BuildContext context, {
  required OpenGymController controller,
  required int entryIndex,
  required int currentSeconds,
}) {
  int selectedMin = (currentSeconds ~/ 60).clamp(0, 10);
  int selectedSec = ((currentSeconds % 60) ~/ 5) * 5;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (context, setSheetState) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Exercise rest timer',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      controller.setEntryRestSeconds(
                        entryIndex,
                        (selectedMin * 60) + selectedSec,
                      );
                      Navigator.of(sheetCtx).pop();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: FixedExtentScrollController(
                          initialItem: selectedMin,
                        ),
                        itemExtent: 42,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (idx) =>
                            setSheetState(() => selectedMin = idx),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 11,
                          builder: (_, idx) => Center(
                            child: Text('$idx min'),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: FixedExtentScrollController(
                          initialItem: selectedSec ~/ 5,
                        ),
                        itemExtent: 42,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (idx) =>
                            setSheetState(() => selectedSec = idx * 5),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 12,
                          builder: (_, idx) => Center(
                            child: Text('${idx * 5} sec'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _showExerciseHistorySheet(
  BuildContext context, {
  required OpenGymController controller,
  required WorkoutEntry entry,
}) {
  final pastSessions = <({String date, WorkoutEntry entry})>[];
  for (final log in controller.history) {
    for (final e in log.entries) {
      if (e.exerciseId == entry.exerciseId ||
          e.exerciseName.toLowerCase() == entry.exerciseName.toLowerCase()) {
        pastSessions.add((date: log.startedAt, entry: e));
      }
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final unit = controller.preferences.weightUnit;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          Text(
            '${entry.exerciseName} History',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (pastSessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No previous sessions logged yet.')),
            )
          else
            ...pastSessions.take(10).map((item) {
              final setsText = item.entry.sets
                  .where((s) => s.isCompleted)
                  .map((s) => '${s.weight.toStringAsFixed(0)}$unit × ${s.reps}')
                  .join('  •  ');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.date.split('T').first),
                  subtitle: Text(
                    setsText.isEmpty ? 'No completed sets' : setsText,
                  ),
                ),
              );
            }),
        ],
      );
    },
  );
}

Future<void> _showEntryProgressionSheet(
  BuildContext context, {
  required OpenGymController controller,
  required int entryIndex,
  required String currentMode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          Text(
            'Exercise settings',
            style: Theme.of(sheetCtx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          ...ProgressionService.policies.map(
            (opt) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(opt.title),
                subtitle: Text(opt.description),
                trailing: opt.key == currentMode
                    ? Icon(
                        Icons.check,
                        color: Theme.of(sheetCtx).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  controller.setEntryProgressionMode(entryIndex, opt.key);
                  Navigator.of(sheetCtx).pop();
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showHowToDoItSheet(
  BuildContext context, {
  required OpenGymController controller,
  required WorkoutEntry entry,
}) {
  final Exercise? ex = controller.exercises
      .where((e) => e.id == entry.exerciseId)
      .firstOrNull;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final instructions = ex?.instructions ?? const <String>[];
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.94,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: <Widget>[
            Text(
              entry.exerciseName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ExerciseAnimationView(
              exerciseId: entry.exerciseId,
              controller: controller,
              height: 220,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: <Widget>[
                Chip(label: Text(entry.bodyPart)),
                Chip(label: Text(entry.equipment)),
                if (ex != null && ex.target.isNotEmpty)
                  Chip(label: Text('Target: ${ex.target}')),
              ],
            ),
            const SizedBox(height: 12),
            if (instructions.isEmpty)
              Text(
                'Focus on controlled eccentric tempo and full range of motion.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...instructions.asMap().entries.map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 12,
                            child: Text(
                              '${step.key + 1}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(step.value)),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      );
    },
  );
}
