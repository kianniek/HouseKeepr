import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/exercise_catalog.dart';
import '../../models/exercise_set.dart';
import '../../models/workout_template.dart';
import '../../state/open_gym_controller.dart';
import '../../state/progression_service.dart';
import '../programmes_screen.dart';
import 'routine_glyph_icon.dart';
import 'undo_toast.dart';

/// Human-readable label for a `WorkoutTemplate.routineType`.
String routineTypeLabel(String type) {
  return switch (type) {
    'circuit' => 'Circuit',
    'amrap' => 'AMRAP',
    'emom' => 'EMOM',
    'intervals' => 'Intervals',
    'runwalk' => 'Run/walk program',
    _ => 'Regular',
  };
}

/// Opens the top-right Plan options sheet matching
/// `Plan/plan_routines_share_sheet.png`.
Future<void> showPlanOptionsSheet(
  BuildContext context, {
  required OpenGymController controller,
  required ValueChanged<WorkoutTemplate> onOpenRoutine,
}) {
  final hasRoutines = controller.templates.any((t) => t.entries.isNotEmpty);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final colorScheme = theme.colorScheme;

      Widget optionCard({
        required IconData icon,
        required String title,
        String? subtitle,
        bool enabled = true,
        required VoidCallback onTap,
      }) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            enabled: enabled,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20),
            ),
            title: Text(title),
            subtitle: subtitle != null ? Text(subtitle) : null,
            onTap: enabled ? onTap : null,
          ),
        );
      }

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: <Widget>[
            Text(
              'Plan',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!hasRoutines) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Add an exercise to a routine first. An empty plan has nothing to share.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            optionCard(
              icon: Icons.ios_share_rounded,
              title: 'Export plan file',
              subtitle:
                  'A small file a friend can import into their own openGym. Routines only, none of your workouts or weigh-ins.',
              enabled: hasRoutines,
              onTap: () async {
                final payload = jsonEncode(<String, dynamic>{
                  'format': 'opengym_plan_v1',
                  'routines':
                      controller.templates.map((t) => t.toJson()).toList(),
                });
                await Clipboard.setData(ClipboardData(text: payload));
                if (sheetCtx.mounted) {
                  Navigator.of(sheetCtx).pop();
                  showOpenGymUndoToast(
                    context,
                    message: 'Plan JSON copied to clipboard.',
                  );
                }
              },
            ),
            optionCard(
              icon: Icons.description_outlined,
              title: 'Print / Save as PDF',
              enabled: hasRoutines,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _showPrintablePlanDialog(context, controller);
              },
            ),
            optionCard(
              icon: Icons.download_outlined,
              title: 'Import a plan file',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _showImportPlanDialog(context, controller);
              },
            ),
            optionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan a QR code',
              subtitle:
                  'A routine from a friend’s phone, the website or the poster by the squat rack.',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _showImportPlanDialog(
                  context,
                  controller,
                  title: 'Paste Routine QR Payload',
                );
              },
            ),
            optionCard(
              icon: Icons.assignment_outlined,
              title: 'Load starter plan',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                showStarterPlanSheet(context, controller: controller);
              },
            ),
            optionCard(
              icon: Icons.history_rounded,
              title: 'Routine from a past workout',
              enabled: controller.history.isNotEmpty,
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _showRoutineFromPastWorkoutSheet(
                  context,
                  controller: controller,
                  onOpenRoutine: onOpenRoutine,
                );
              },
            ),
            optionCard(
              icon: Icons.calendar_today_outlined,
              title: 'Programmes',
              subtitle:
                  'Your routines as a block of weeks, with starter programmes to try.',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ProgrammesScreen(controller: controller),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showPrintablePlanDialog(
  BuildContext context,
  OpenGymController controller,
) {
  final buffer = StringBuffer();
  for (final t in controller.templates) {
    buffer.writeln('${t.name} (${t.entries.length} exercises)');
    for (final e in t.entries) {
      buffer.writeln(
        '  • ${e.exerciseName}: ${e.prescriptionSummary(controller.preferences.weightUnit)}',
      );
    }
    buffer.writeln();
  }
  return showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Training Plan Summary'),
      content: SingleChildScrollView(
        child: SelectableText(buffer.toString().trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: buffer.toString()));
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
          },
          child: const Text('Copy text'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> _showImportPlanDialog(
  BuildContext context,
  OpenGymController controller, {
  String title = 'Import Plan JSON',
}) async {
  final textCtrl = TextEditingController();
  final raw = await showDialog<String>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: textCtrl,
        maxLines: 6,
        decoration: const InputDecoration(
          hintText: 'Paste exported OpenGym plan JSON...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogCtx).pop(textCtrl.text),
          child: const Text('Import'),
        ),
      ],
    ),
  );
  if (raw == null || raw.trim().isEmpty) return;

  try {
    final decoded = jsonDecode(raw.trim());
    final rawList = decoded is Map && decoded['routines'] is List
        ? decoded['routines'] as List<dynamic>
        : (decoded is List ? decoded : <dynamic>[decoded]);
    int imported = 0;
    for (final item in rawList) {
      if (item is Map) {
        final parsed = WorkoutTemplate.fromJson(Map<String, dynamic>.from(item));
        final fresh = WorkoutTemplate.create(
          name: parsed.name,
          goal: parsed.goal,
          split: parsed.split,
          description: parsed.description,
          iconKey: parsed.iconKey,
          progressionPolicy: parsed.progressionPolicy,
          routineType: parsed.routineType,
          isDeload: parsed.isDeload,
          entries: parsed.entries,
        );
        await controller.saveTemplate(fresh);
        imported++;
      }
    }
    if (context.mounted) {
      showOpenGymUndoToast(
        context,
        message: 'Imported $imported routine${imported == 1 ? '' : 's'}.',
      );
    }
  } catch (e) {
    if (context.mounted) {
      showOpenGymUndoToast(context, message: 'Import failed: $e');
    }
  }
}

Future<void> _showRoutineFromPastWorkoutSheet(
  BuildContext context, {
  required OpenGymController controller,
  required ValueChanged<WorkoutTemplate> onOpenRoutine,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          Text(
            'Routine from a past workout',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...controller.history.take(15).map((log) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(log.title),
                subtitle: Text('${log.entries.length} exercises'),
                trailing: const Icon(Icons.add),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  final created =
                      await controller.createRoutineFromWorkoutLog(log);
                  onOpenRoutine(created);
                },
              ),
            );
          }),
        ],
      );
    },
  );
}

/// Opens the Starter Plan chooser sheet matching `starterPlanSheet`.
Future<void> showStarterPlanSheet(
  BuildContext context, {
  required OpenGymController controller,
}) {
  final plans = ExerciseCatalog.starterPlans();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          Text(
            'Load starter plan',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Adds balanced starter routines and schedules them for you.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...plans.map((plan) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const RoutineGlyphBadge(iconKey: 'barbell'),
                title: Text(plan.title),
                subtitle: Text(plan.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await controller.loadStarterPlan(
                    plan.templates,
                    weekdayMap: plan.weeklySchedule,
                  );
                  if (context.mounted) {
                    showOpenGymUndoToast(
                      context,
                      message: 'Loaded "${plan.title}".',
                    );
                  }
                },
              ),
            );
          }),
        ],
      );
    },
  );
}

/// Opens the "Add to the rotation" sheet matching
/// `Plan/plan_schedule_rotation_edit_add_sheet.png`.
Future<void> showAddToRotationSheet(
  BuildContext context, {
  required OpenGymController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final seq = controller.rotationSequence;

      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          Text(
            'Add to the rotation',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (seq.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const RoutineGlyphBadge(
                  iconKey: 'moon',
                  isRestDay: true,
                ),
                title: const Text('Rest day'),
                subtitle: const Text('A day off before the next one'),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await controller.addStopToRotation(
                    OpenGymController.restStopId,
                  );
                },
              ),
            ),
          ...controller.templates.map((t) {
            final alreadyInLoop = seq.contains(t.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(routineGlyphIconData(t.iconKey), size: 20),
                ),
                title: Text(t.name),
                subtitle: Text(
                  alreadyInLoop
                      ? 'Already in the loop: adds it again'
                      : '${t.entries.length} exercises',
                ),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await controller.addStopToRotation(t.id);
                },
              ),
            );
          }),
        ],
      );
    },
  );
}

/// Centered confirmation dialog matching
/// `Plan/plan_schedule_rotation_to_fixed_week_dialog.png`.
Future<bool> showBackToFixedWeekDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) {
      final theme = Theme.of(dialogCtx);
      return AlertDialog(
        title: const Text(
          'Back to a fixed week?',
          textAlign: TextAlign.center,
        ),
        content: Text(
          'The loop stops. Your weekdays stay as they are, and the loop is saved for later.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: <Widget>[
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('Use Fixed Week'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Assigns one or more routines (or Rest day) to a weekday in Fixed Week mode.
Future<void> showDayAssignSheet(
  BuildContext context, {
  required OpenGymController controller,
  required int weekday,
  required String weekdayName,
}) {
  final selectedIds = List<String>.from(
    controller.preferences.weeklySchedule[weekday] ?? const <String>[],
  );
  bool trainSeparately =
      controller.preferences.weeklyTrainSeparately[weekday] ?? false;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (context, setSheetState) {
        final theme = Theme.of(context);
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: <Widget>[
            Text(
              weekdayName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const RoutineGlyphBadge(
                  iconKey: 'moon',
                  isRestDay: true,
                ),
                title: const Text('Rest day'),
                trailing: selectedIds.isEmpty
                    ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                    : null,
                onTap: () {
                  setSheetState(selectedIds.clear);
                },
              ),
            ),
            ...controller.templates.map((t) {
              final checked = selectedIds.contains(t.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  secondary: RoutineGlyphBadge(iconKey: t.iconKey),
                  title: Text(t.name),
                  subtitle: Text('${t.entries.length} exercises'),
                  value: checked,
                  onChanged: (v) {
                    setSheetState(() {
                      if (v == true && !selectedIds.contains(t.id)) {
                        selectedIds.add(t.id);
                      } else {
                        selectedIds.remove(t.id);
                      }
                    });
                  },
                ),
              );
            }),
            if (selectedIds.length >= 2) ...<Widget>[
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Together'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Separately'),
                  ),
                ],
                selected: <bool>{trainSeparately},
                onSelectionChanged: (s) =>
                    setSheetState(() => trainSeparately = s.first),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                Navigator.of(sheetCtx).pop();
                await controller.setWeekdaySchedule(
                  weekday,
                  selectedIds,
                  trainSeparately: trainSeparately,
                );
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    ),
  );
}

/// Opens the 9-policy Progression chooser bottom sheet matching
/// `Plan/plan_routines_new_routine_progression_sheet.png`.
Future<String?> showRoutineProgressionSheet(
  BuildContext context, {
  required String currentPolicy,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final colorScheme = theme.colorScheme;

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.94,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: <Widget>[
            Text(
              'Progression',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: ProgressionService.policies.asMap().entries.map((e) {
                  final idx = e.key;
                  final policy = e.value;
                  final selected = policy.key == currentPolicy;
                  return Column(
                    children: <Widget>[
                      if (idx > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(
                          policy.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(policy.description),
                        trailing: selected
                            ? Icon(
                                Icons.check_rounded,
                                color: colorScheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.of(sheetCtx).pop(policy.key),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Opens the Folder chooser bottom sheet matching
/// `Plan/plan_routines_new_routine_folder_sheet.png`.
Future<String?> showRoutineFolderSheet(
  BuildContext context, {
  required String? currentFolder,
  required List<String> existingFolders,
}) {
  final ctrl = TextEditingController(text: currentFolder ?? '');
  final quickChips = <String>{'Archive', ...existingFolders}.toList();

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (context, setSheetState) {
        final theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Folder',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Group routines by block or by goal. Put old ones in Archive, it stays folded.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: 'Folder name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  ...quickChips.map(
                    (f) => ActionChip(
                      label: Text(f),
                      onPressed: () => setSheetState(() => ctrl.text = f),
                    ),
                  ),
                  if (ctrl.text.isNotEmpty)
                    ActionChip(
                      label: const Text('Clear'),
                      onPressed: () => setSheetState(() => ctrl.clear()),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(sheetCtx).pop(ctrl.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Opens the Routine type chooser bottom sheet matching
/// `Plan/plan_routines_new_routine_type_sheet.png`.
Future<String?> showRoutineTypeSheet(
  BuildContext context, {
  required String currentType,
}) {
  const options = <({String key, String title, String subtitle})>[
    (
      key: 'regular',
      title: 'Regular',
      subtitle: 'Set by set, at your own pace. Supersets welcome.',
    ),
    (
      key: 'circuit',
      title: 'Circuit',
      subtitle: 'Rounds over your stations. Tap Done, move on, repeat.',
    ),
    (
      key: 'amrap',
      title: 'AMRAP',
      subtitle: 'As many rounds as you can before the clock says stop.',
    ),
    (
      key: 'emom',
      title: 'EMOM',
      subtitle:
          'A new interval every minute on the minute. Finish early, rest the rest.',
    ),
    (
      key: 'intervals',
      title: 'Intervals',
      subtitle: 'Work, rest, repeat. Tabata is 20 on, 10 off, 8 times.',
    ),
    (
      key: 'runwalk',
      title: 'Run/walk program',
      subtitle:
          'Run a bit, walk a bit, run a little more each level. Three finished runs move you up.',
    ),
  ];

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final colorScheme = theme.colorScheme;

      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          Text(
            'Routine type',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: options.asMap().entries.map((item) {
                final idx = item.key;
                final opt = item.value;
                final selected = opt.key == currentType;
                return Column(
                  children: <Widget>[
                    if (idx > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(
                        opt.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(opt.subtitle),
                      trailing: selected
                          ? Icon(
                              Icons.check_rounded,
                              color: colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(sheetCtx).pop(opt.key),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      );
    },
  );
}

/// Opens the per-slot Exercise configuration bottom sheet (`ExConfig`).
Future<void> showExerciseConfigSheet(
  BuildContext context, {
  required OpenGymController controller,
  required WorkoutTemplateEntry entry,
  required ValueChanged<WorkoutTemplateEntry> onSave,
  VoidCallback? onRemove,
}) {
  var current = entry;
  final weightCtrl = TextEditingController(
    text: entry.defaultWeight > 0 ? entry.defaultWeight.toString() : '',
  );
  final noteCtrl = TextEditingController(text: entry.note ?? '');
  final unit = controller.preferences.weightUnit;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (context, setSheetState) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.94,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      current.exerciseName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      final w = double.tryParse(
                              weightCtrl.text.replaceAll(',', '.')) ??
                          0;
                      onSave(
                        current.copyWith(
                          defaultWeight: w,
                          note: noteCtrl.text.trim(),
                          clearNote: noteCtrl.text.trim().isEmpty,
                        ),
                      );
                      Navigator.of(sheetCtx).pop();
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Logging mode', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<ExerciseMode>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<ExerciseMode>>[
                  ButtonSegment<ExerciseMode>(
                    value: ExerciseMode.reps,
                    label: Text('Reps'),
                  ),
                  ButtonSegment<ExerciseMode>(
                    value: ExerciseMode.time,
                    label: Text('Time'),
                  ),
                  ButtonSegment<ExerciseMode>(
                    value: ExerciseMode.distance,
                    label: Text('Dist'),
                  ),
                  ButtonSegment<ExerciseMode>(
                    value: ExerciseMode.cardio,
                    label: Text('Cardio'),
                  ),
                ],
                selected: <ExerciseMode>{current.mode},
                onSelectionChanged: (s) => setSheetState(
                  () => current = current.copyWith(mode: s.first),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: weightCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Start weight ($unit)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: current.progressionPolicy,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Progression',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Routine default'),
                        ),
                        ...ProgressionService.policies.map(
                          (p) => DropdownMenuItem<String?>(
                            value: p.key,
                            child: Text(p.title),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setSheetState(() {
                          current = v == null
                              ? current.copyWith(clearProgressionPolicy: true)
                              : current.copyWith(progressionPolicy: v);
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ConfigCounter(
                      label: 'Sets',
                      value: current.targetSets,
                      onChanged: (v) => setSheetState(
                        () => current = current.copyWith(targetSets: v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ConfigCounter(
                      label: current.mode == ExerciseMode.time ? 'Sec' : 'Reps',
                      value: current.mode == ExerciseMode.time
                          ? (current.targetDurationSeconds ?? 30)
                          : current.targetReps,
                      step: current.mode == ExerciseMode.time ? 5 : 1,
                      onChanged: (v) => setSheetState(() {
                        if (current.mode == ExerciseMode.time) {
                          current = current.copyWith(targetDurationSeconds: v);
                        } else {
                          current = current.copyWith(targetReps: v);
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ConfigCounter(
                      label: 'Rest (s)',
                      value: current.restSeconds,
                      min: 0,
                      step: 15,
                      onChanged: (v) => setSheetState(
                        () => current = current.copyWith(restSeconds: v),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Exercise note (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              if (onRemove != null) ...<Widget>[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    onRemove();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove from routine'),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _ConfigCounter extends StatelessWidget {
  const _ConfigCounter({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          children: <Widget>[
            Text(label, style: theme.textTheme.labelSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: value - step >= min
                      ? () => onChanged(value - step)
                      : null,
                ),
                Text(
                  '$value',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => onChanged(value + step),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
