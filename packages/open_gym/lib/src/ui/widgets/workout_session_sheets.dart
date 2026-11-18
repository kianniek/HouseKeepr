import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/exercise.dart';
import '../../models/progress_photo.dart';
import '../../models/workout_log.dart';
import '../../state/open_gym_controller.dart';
import '../exercise_library_screen.dart';
import '../open_gym_settings_screen.dart';
import 'body_map_widget.dart';
import 'undo_toast.dart';

/// Human-readable label for a workout layout key.
String workoutLayoutLabel(String layout) {
  return switch (layout) {
    'list' => 'List',
    'compact' => 'Compact',
    'focus' => 'Focus',
    _ => 'Cards',
  };
}

/// Formats rest seconds concisely (e.g. `30s`, `1m 30s`, `Off`).
String formatRestLabel(int seconds) {
  if (seconds <= 0) return 'Off';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m == 0) return '${s}s';
  if (s == 0) return '${m}m';
  return '${m}m ${s}s';
}

/// Actions returned by [showWorkoutMenuSheet] when the caller handles
/// navigation/picker flows directly in `ActiveWorkoutScreen`.
enum WorkoutMenuAction {
  addExercise,
}

/// Opens the 3-dots (`...`) workout menu bottom sheet matching
/// `02_workout_menu_sheet.png` and `08_workout_menu_more_expanded.png`.
Future<WorkoutMenuAction?> showWorkoutMenuSheet(
  BuildContext context, {
  required OpenGymController controller,
}) {
  return showModalBottomSheet<WorkoutMenuAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => _WorkoutMenuSheetBody(controller: controller),
  );
}

class _WorkoutMenuSheetBody extends StatefulWidget {
  const _WorkoutMenuSheetBody({required this.controller});

  final OpenGymController controller;

  @override
  State<_WorkoutMenuSheetBody> createState() => _WorkoutMenuSheetBodyState();
}

class _WorkoutMenuSheetBodyState extends State<_WorkoutMenuSheetBody> {
  bool _moreExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final prefs = widget.controller.preferences;
        final workout = widget.controller.activeWorkout;
        final isPaused = widget.controller.isPaused;
        final countForProgression = workout?.countForProgression ?? true;
        final hasNote = workout?.notes?.isNotEmpty ?? false;

        final settingsSubtitle =
            '${formatRestLabel(prefs.defaultRestSeconds)} rest • '
            '${prefs.soundEnabled ? 'Sound' : 'Muted'}';

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.settings_outlined),
                  ),
                  title: Text(
                    'Workout settings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(settingsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final navCtx = Navigator.of(context).context;
                    Navigator.of(context).pop();
                    await showWorkoutSettingsSheet(
                      navCtx,
                      controller: widget.controller,
                    );
                  },
                ),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: Icon(
                        isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      title: Text(
                        isPaused ? 'Resume workout' : 'Pause workout',
                      ),
                      subtitle: isPaused
                          ? null
                          : const Text('The clock and the rest wait for you'),
                      onTap: () {
                        widget.controller.togglePause();
                        Navigator.of(context).pop();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Add exercise'),
                      onTap: () => Navigator.of(context)
                          .pop(WorkoutMenuAction.addExercise),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.sticky_note_2_outlined),
                      title: Text(
                        hasNote ? 'Edit session note' : 'Add session note',
                      ),
                      subtitle: hasNote
                          ? Text(
                              workout!.notes!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () async {
                        final navCtx = Navigator.of(context).context;
                        Navigator.of(context).pop();
                        await showSessionNoteSheet(
                          navCtx,
                          controller: widget.controller,
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.view_agenda_outlined),
                      title: const Text('Layout'),
                      subtitle: Text(workoutLayoutLabel(prefs.workoutLayout)),
                      onTap: () async {
                        final navCtx = Navigator.of(context).context;
                        Navigator.of(context).pop();
                        await showLayoutPickerSheet(
                          navCtx,
                          controller: widget.controller,
                        );
                      },
                    ),
                  ],
                ),
              ),
              Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!_moreExpanded)
                      ListTile(
                        leading: const Icon(Icons.more_horiz),
                        title: const Text('More'),
                        subtitle: const Text(
                          'Add routine, Rename workout, Don\'t count for progression',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.keyboard_arrow_down),
                        onTap: () => setState(() => _moreExpanded = true),
                      )
                    else ...<Widget>[
                      ListTile(
                        leading: const Icon(Icons.playlist_add_outlined),
                        title: const Text('Add routine'),
                        subtitle: const Text(
                          'Bring another routine into this session',
                        ),
                        onTap: () async {
                          final navCtx = Navigator.of(context).context;
                          Navigator.of(context).pop();
                          await showAddRoutineSheet(
                            navCtx,
                            controller: widget.controller,
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Rename workout'),
                        onTap: () async {
                          final navCtx = Navigator.of(context).context;
                          Navigator.of(context).pop();
                          await showRenameWorkoutSheet(
                            navCtx,
                            controller: widget.controller,
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          countForProgression
                              ? Icons.trending_down_outlined
                              : Icons.trending_up_outlined,
                        ),
                        title: Text(
                          countForProgression
                              ? 'Don\'t count for progression'
                              : 'Count for progression',
                        ),
                        subtitle: const Text('Every exercise in this workout'),
                        onTap: () {
                          widget.controller.setCountForProgression(
                            !countForProgression,
                          );
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Opens the Workout settings bottom sheet matching
/// `03_workout_settings_sheet.png`.
Future<void> showWorkoutSettingsSheet(
  BuildContext context, {
  required OpenGymController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final prefs = controller.preferences;
        final segmentedLayout = <String>{'cards', 'list', 'compact'}
                .contains(prefs.workoutLayout)
            ? prefs.workoutLayout
            : 'cards';

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.86,
          maxChildSize: 0.94,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Workout settings',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Changes stick for your next workouts too.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Rest timer'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            formatRestLabel(prefs.defaultRestSeconds),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => showRestTimerPickerSheet(
                        context,
                        controller: controller,
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.volume_up_outlined),
                      title: const Text('Play a sound'),
                      value: prefs.soundEnabled,
                      onChanged: (v) => controller.savePreferences(
                        prefs.copyWith(soundEnabled: v),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration),
                      title: const Text('Vibrate'),
                      value: prefs.hapticsEnabled,
                      onChanged: (v) => controller.savePreferences(
                        prefs.copyWith(hapticsEnabled: v),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.wb_sunny_outlined),
                      title: const Text('Flash the screen'),
                      value: prefs.flashScreen,
                      onChanged: (v) => controller.savePreferences(
                        prefs.copyWith(flashScreen: v),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.stay_current_portrait),
                      title: const Text('Keep screen awake'),
                      subtitle: const Text(
                        'The screen stays on while a workout is running, so '
                        'you don\'t have to unlock your phone between sets.',
                      ),
                      value: prefs.keepScreenAwake,
                      onChanged: (v) => controller.savePreferences(
                        prefs.copyWith(keepScreenAwake: v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.view_agenda_outlined),
                        title: const Text('Layout'),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const <ButtonSegment<String>>[
                              ButtonSegment<String>(
                                value: 'cards',
                                label: Text('Cards'),
                              ),
                              ButtonSegment<String>(
                                value: 'list',
                                label: Text('List'),
                              ),
                              ButtonSegment<String>(
                                value: 'compact',
                                label: Text('Compact'),
                              ),
                            ],
                            selected: <String>{segmentedLayout},
                            onSelectionChanged: (sel) =>
                                controller.savePreferences(
                              prefs.copyWith(workoutLayout: sel.first),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.speed_outlined),
                        title: const Text('Effort per set'),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const <ButtonSegment<String>>[
                              ButtonSegment<String>(
                                value: 'off',
                                label: Text('Off'),
                              ),
                              ButtonSegment<String>(
                                value: 'rir',
                                label: Text('RIR'),
                              ),
                              ButtonSegment<String>(
                                value: 'rpe',
                                label: Text('RPE'),
                              ),
                            ],
                            selected: <String>{prefs.effortMode},
                            onSelectionChanged: (sel) =>
                                controller.savePreferences(
                              prefs.copyWith(effortMode: sel.first),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.swap_horiz),
                        title: const Text('Swipe actions'),
                        subtitle: const Text(
                          'Sets, routines and the loop: left removes, right copies',
                        ),
                        value: prefs.swipeActionsEnabled,
                        onChanged: (v) => controller.savePreferences(
                          prefs.copyWith(swipeActionsEnabled: v),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.ondemand_video_outlined),
                        title: const Text('Exercise animations'),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const <ButtonSegment<String>>[
                              ButtonSegment<String>(
                                value: 'full',
                                label: Text('Full'),
                              ),
                              ButtonSegment<String>(
                                value: 'small',
                                label: Text('Small'),
                              ),
                              ButtonSegment<String>(
                                value: 'hidden',
                                label: Text('Hidden'),
                              ),
                            ],
                            selected: <String>{prefs.exerciseAnimationSize},
                            onSelectionChanged: (sel) =>
                                controller.savePreferences(
                              prefs.copyWith(exerciseAnimationSize: sel.first),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('All settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            OpenGymSettingsScreen(controller: controller),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Opens the rest timer wheel picker bottom sheet matching
/// `12_workout_rest_timer_picker_sheet.png`.
Future<void> showRestTimerPickerSheet(
  BuildContext context, {
  required OpenGymController controller,
}) {
  final current = controller.preferences.defaultRestSeconds;
  int selectedMin = (current ~/ 60).clamp(0, 10);
  int selectedSec = ((current % 60) ~/ 5) * 5;

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
                    'Rest timer',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      final total = (selectedMin * 60) + selectedSec;
                      controller.savePreferences(
                        controller.preferences
                            .copyWith(defaultRestSeconds: total),
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
                            child: Text(
                              '$idx min',
                              style: idx == selectedMin
                                  ? theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    )
                                  : theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                            ),
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
                          builder: (_, idx) {
                            final sec = idx * 5;
                            return Center(
                              child: Text(
                                '$sec sec',
                                style: sec == selectedSec
                                    ? theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      )
                                    : theme.textTheme.bodyLarge?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                              ),
                            );
                          },
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

/// Opens the layout picker bottom sheet matching
/// `07_workout_layout_picker_sheet.png`.
Future<void> showLayoutPickerSheet(
  BuildContext context, {
  required OpenGymController controller,
}) {
  const options = <({String key, String label, IconData icon})>[
    (key: 'cards', label: 'Cards', icon: Icons.view_agenda_outlined),
    (key: 'list', label: 'List', icon: Icons.view_list_outlined),
    (key: 'compact', label: 'Compact', icon: Icons.density_small_outlined),
    (key: 'focus', label: 'Focus', icon: Icons.center_focus_strong_outlined),
  ];

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final current = controller.preferences.workoutLayout;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Layout',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...options.map((opt) {
              final selected = opt.key == current;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(opt.icon),
                  title: Text(opt.label),
                  trailing: selected
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () {
                    controller.savePreferences(
                      controller.preferences.copyWith(workoutLayout: opt.key),
                    );
                    Navigator.of(sheetCtx).pop();
                  },
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

/// Opens the Add Routine bottom sheet matching
/// `09_workout_add_routine_sheet.png`.
Future<void> showAddRoutineSheet(
  BuildContext context, {
  required OpenGymController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final activeIds = controller.activeWorkout?.entries
              .map((e) => e.exerciseId)
              .toSet() ??
          const <String>{};

      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          Text(
            'Add routine',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...controller.templates.map((template) {
            final alreadyAdded = template.entries.isNotEmpty &&
                template.entries.every((e) => activeIds.contains(e.exerciseId));
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(template.name),
                subtitle: Text('${template.entries.length} exercises'),
                trailing: alreadyAdded
                    ? Chip(
                        label: const Text('Already Added'),
                        visualDensity: VisualDensity.compact,
                      )
                    : const Icon(Icons.add),
                onTap: alreadyAdded
                    ? null
                    : () {
                        controller.addRoutineToActiveWorkout(template);
                        Navigator.of(sheetCtx).pop();
                      },
              ),
            );
          }),
        ],
      );
    },
  );
}

/// Opens the Session note bottom sheet matching
/// `06_workout_session_note_sheet.png`.
Future<void> showSessionNoteSheet(
  BuildContext context, {
  required OpenGymController controller,
}) {
  final textCtrl = TextEditingController(
    text: controller.activeWorkout?.notes ?? '',
  );
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
                'Session note',
                style: Theme.of(sheetCtx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              FilledButton(
                onPressed: () {
                  controller.setSessionNote(textCtrl.text);
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
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'How the session went as a whole.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Opens the Rename workout bottom sheet matching
/// `10_workout_rename_sheet.png`.
Future<void> showRenameWorkoutSheet(
  BuildContext context, {
  required OpenGymController controller,
}) {
  final textCtrl = TextEditingController(
    text: controller.activeWorkout?.title ?? '',
  );
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
                'Rename workout',
                style: Theme.of(sheetCtx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              FilledButton(
                onPressed: () {
                  controller.renameActiveWorkout(textCtrl.text);
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
            decoration: const InputDecoration(
              labelText: 'Workout name',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Opens the Add exercise modal bottom sheet matching
/// `05_workout_add_exercise_sheet.png`.
Future<Exercise?> showAddExerciseSheet(
  BuildContext context, {
  required OpenGymController controller,
}) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: ExerciseLibraryScreen(
        controller: controller,
        isPicker: true,
      ),
    ),
  );
}

/// Result of [showFinishWorkoutSheet].
enum FinishWorkoutChoice {
  finishAndSave,
  discardWorkout,
}

/// Opens the Finish / Nothing logged yet submenu bottom sheet matching
/// `13_workout_nothing_logged_finish_sheet.png`.
Future<FinishWorkoutChoice?> showFinishWorkoutSheet(
  BuildContext context, {
  required WorkoutLog workout,
}) {
  final doneSets = workout.completedSetsCount;
  final totalSets = workout.totalSetsCount;
  final nothingLogged = doneSets == 0;

  return showModalBottomSheet<FinishWorkoutChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final colorScheme = theme.colorScheme;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              nothingLogged ? 'Nothing logged yet' : 'Finish workout?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nothingLogged
                  ? 'No sets are checked off, so there’s nothing to save. Discard this workout, or go back and tick the sets you did?'
                  : '$doneSets of $totalSets sets completed. Save this session or discard it?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.flag_outlined),
                ),
                title: Text(
                  'Finish and save',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(sheetCtx)
                    .pop(FinishWorkoutChoice.finishAndSave),
              ),
            ),
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                  child: const Icon(Icons.delete_outline),
                ),
                title: Text(
                  'Discard workout',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(sheetCtx)
                    .pop(FinishWorkoutChoice.discardWorkout),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(null),
                child: const Text('Keep going'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Opens the Discard workout confirmation dialog matching
/// `14_workout_discard_confirm_dialog.png`.
Future<bool> showDiscardWorkoutDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Discard workout?'),
      content: const Text('All sets logged in this session will be lost.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogCtx).colorScheme.error,
            foregroundColor: Theme.of(dialogCtx).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return result == true;
}

/// Opens the Workout complete summary sheet matching
/// `15_workout_complete_summary_sheet.png`.
Future<void> showWorkoutCompleteSummarySheet(
  BuildContext context, {
  required OpenGymController controller,
  required WorkoutLog completed,
  required int prCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final colorScheme = theme.colorScheme;
      final unit = controller.preferences.weightUnit;
      final durationMin = (completed.durationSeconds / 60).floor();
      final totalSets = completed.totalSetsCount;
      final doneSets = completed.completedSetsCount;

      final trainedMuscles = <String, int>{
        for (final entry in completed.entries)
          entry.bodyPart: entry.sets.where((s) => s.isCompleted).isEmpty
              ? 1
              : entry.sets.where((s) => s.isCompleted).length,
      };

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.96,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            Align(
              alignment: Alignment.topRight,
              child: IconButton.filledTonal(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(sheetCtx).pop(),
              ),
            ),
            Icon(
              Icons.emoji_events_outlined,
              size: 40,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Workout complete!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryStatCard(
                    label: 'Duration',
                    value: '$durationMin min',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryStatCard(
                    label: 'Volume',
                    value: '${completed.totalVolume.toStringAsFixed(0)} $unit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryStatCard(
                    label: 'Sets',
                    value: '$totalSets sets • $doneSets work',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryStatCard(
                    label: 'PRs',
                    value: prCount > 0 ? '$prCount' : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final comparisons = controller.progressionService
                    .compareAfterWorkout(
                  completed,
                  controller.history,
                  unit: unit,
                );
                if (comparisons.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'LAST TIME AND NEXT TIME',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...comparisons.map(
                      (c) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                c.exerciseName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Today: ${c.todaySummary}'),
                              if (c.lastTimeSummary != null)
                                Text(
                                  'Last time: ${c.lastTimeSummary}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                'Next time · ${c.steppedUp ? 'step up' : 'same again'}: ${c.nextTimeSummary}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            Text(
              'What you just trained',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: BodyMapWidget(
                weeklySetsByBodyPart: trainedMuscles,
                showHeader: false,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Photos & videos',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked == null) return;
                    final bytes = await picked.readAsBytes();
                    await controller.saveProgressPhoto(
                      ProgressPhoto.create(
                        date: DateTime.now().toIso8601String(),
                        base64Image: base64Encode(bytes),
                        note: completed.title,
                      ),
                    );
                    if (sheetCtx.mounted) {
                      showOpenGymUndoToast(
                        sheetCtx,
                        message: 'Photo saved to OpenGym.',
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add photo or video'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final text =
                        '${completed.title} • $durationMin min • ${completed.totalVolume.toStringAsFixed(0)} $unit • $doneSets sets';
                    await Clipboard.setData(ClipboardData(text: text));
                    if (sheetCtx.mounted) {
                      showOpenGymUndoToast(
                        sheetCtx,
                        message: 'Workout summary copied.',
                      );
                    }
                  },
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share workout'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final created =
                        await controller.createRoutineFromWorkoutLog(completed);
                    if (sheetCtx.mounted) {
                      showOpenGymUndoToast(
                        sheetCtx,
                        message: 'Saved “${created.name}” as routine.',
                      );
                    }
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save as routine'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
