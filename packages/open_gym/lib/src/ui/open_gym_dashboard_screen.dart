import 'package:flutter/material.dart';

import '../models/weigh_in.dart';
import '../models/workout_template.dart';
import '../state/open_gym_controller.dart';
import 'active_workout_screen.dart';
import 'community_routines_screen.dart';
import 'exercise_library_screen.dart';
import 'measurements_screen.dart';
import 'open_gym_settings_screen.dart';
import 'programmes_screen.dart';
import 'routine_builder_screen.dart';
import 'stats_screen.dart';
import 'widgets/body_map_widget.dart';
import 'widgets/line_chart_widget.dart';
import 'widgets/plan_sheets.dart';
import 'widgets/routine_glyph_icon.dart';
import 'widgets/undo_toast.dart';

/// Main dashboard for OpenGym matching the `[Home, Plan, Start, Stats, Exercises]`
/// navigation bar and Material 3 design.
class OpenGymDashboardScreen extends StatefulWidget {
  const OpenGymDashboardScreen({
    super.key,
    required this.controller,
    required this.onExitModule,
  });

  final OpenGymController controller;
  final VoidCallback onExitModule;

  @override
  State<OpenGymDashboardScreen> createState() => _OpenGymDashboardScreenState();
}

class _OpenGymDashboardScreenState extends State<OpenGymDashboardScreen> {
  // 0: Home, 1: Plan, 2: Stats, 3: Exercises
  int _tabIndex = 0;

  void _openActiveWorkout() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActiveWorkoutScreen(controller: widget.controller),
      ),
    );
  }

  void _onStartTap() {
    if (widget.controller.hasActiveWorkout) {
      _openActiveWorkout();
      return;
    }
    final next = widget.controller.todaysScheduledTemplate();
    if (next != null) {
      widget.controller.startFromTemplate(next);
    } else {
      widget.controller.startEmptyWorkout();
    }
    _openActiveWorkout();
  }

  Future<void> _showWorkoutPickerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shrinkWrap: true,
        children: <Widget>[
          Text(
            'Choose a workout',
            style: Theme.of(sheetCtx).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(sheetCtx).pop();
              widget.controller.startEmptyWorkout();
              _openActiveWorkout();
            },
            icon: const Icon(Icons.add),
            label: const Text('Start Empty Workout'),
          ),
          const SizedBox(height: 12),
          ...widget.controller.templates.map(
            (t) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: RoutineGlyphBadge(iconKey: t.iconKey),
                title: Text(t.name),
                subtitle: Text('${t.entries.length} exercises'),
                trailing: const Icon(Icons.play_arrow_rounded),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  widget.controller.startFromTemplate(t);
                  _openActiveWorkout();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final loading = widget.controller.isLoading;
        return Scaffold(
          body: SafeArea(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _tabIndex,
                    children: <Widget>[
                      _HomeTab(
                        controller: widget.controller,
                        onExitModule: widget.onExitModule,
                        onChooseWorkout: _showWorkoutPickerSheet,
                        onStartTemplate: (t) {
                          widget.controller.startFromTemplate(t);
                          _openActiveWorkout();
                        },
                      ),
                      _PlanTab(
                        controller: widget.controller,
                        onOpenMuscleVolume: () =>
                            setState(() => _tabIndex = 2),
                      ),
                      StatsScreen(
                        controller: widget.controller,
                        embedded: true,
                      ),
                      ExerciseLibraryScreen(controller: widget.controller),
                    ],
                  ),
          ),
          bottomNavigationBar: BottomAppBar(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _NavTabItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                _NavTabItem(
                  icon: Icons.calendar_today_outlined,
                  activeIcon: Icons.calendar_today,
                  label: 'Plan',
                  selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
                _CenterStartButton(
                  isActive: widget.controller.hasActiveWorkout,
                  onTap: _onStartTap,
                  onLongPress: _showWorkoutPickerSheet,
                ),
                _NavTabItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Stats',
                  selected: _tabIndex == 2,
                  onTap: () => setState(() => _tabIndex = 2),
                ),
                _NavTabItem(
                  icon: Icons.fitness_center_outlined,
                  activeIcon: Icons.fitness_center,
                  label: 'Exercises',
                  selected: _tabIndex == 3,
                  onTap: () => setState(() => _tabIndex = 3),
                ),
              ],
            ),
          ),
          bottomSheet: widget.controller.hasActiveWorkout
              ? Material(
                  color: colorScheme.primaryContainer,
                  child: ListTile(
                    leading: Icon(
                      Icons.timer_outlined,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    title: Text(
                      widget.controller.activeWorkout!.title,
                      style: TextStyle(color: colorScheme.onPrimaryContainer),
                    ),
                    subtitle: Text(
                      'Workout in progress',
                      style: TextStyle(color: colorScheme.onPrimaryContainer),
                    ),
                    trailing: FilledButton(
                      onPressed: _openActiveWorkout,
                      child: const Text('Resume'),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _NavTabItem extends StatelessWidget {
  const _NavTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(selected ? activeIcon : icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterStartButton extends StatelessWidget {
  const _CenterStartButton({
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });

  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Material(
              color: colorScheme.primary,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                onLongPress: onLongPress,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(
                    isActive ? Icons.timer : Icons.play_arrow_rounded,
                    color: colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isActive ? 'Active' : 'Start',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.controller,
    required this.onExitModule,
    required this.onChooseWorkout,
    required this.onStartTemplate,
  });

  final OpenGymController controller;
  final VoidCallback onExitModule;
  final VoidCallback onChooseWorkout;
  final ValueChanged<WorkoutTemplate> onStartTemplate;

  String _formattedToday() {
    final now = DateTime.now();
    const days = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }

  Future<void> _quickLogWeight(BuildContext context) async {
    final ctrl = TextEditingController();
    final w = await showDialog<double>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Log Body Weight'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Weight (${controller.preferences.weightUnit})',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (parsed != null && parsed > 0) {
                Navigator.of(dialogCtx).pop(parsed);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (w != null) {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await controller.saveWeighIn(WeighIn.create(date: date, weightKg: w));
    }
  }

  Future<void> _editGoalWeight(BuildContext context) async {
    final ctrl = TextEditingController(
      text: controller.preferences.goalWeightKg?.toStringAsFixed(1) ?? '',
    );
    final goal = await showDialog<double?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Goal Weight'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Goal (${controller.preferences.weightUnit})',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.of(dialogCtx).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (goal != null && goal > 0) {
      await controller.savePreferences(
        controller.preferences.copyWith(goalWeightKg: goal),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final upNext = controller.todaysScheduledTemplate();
    final totalInLoop = controller.totalRoutinesInLoop > 0
        ? controller.totalRoutinesInLoop
        : controller.templates.length;
    final doneThisRound = controller.totalRoutinesInLoop > 0
        ? controller.completedInCurrentRound
        : (totalInLoop > 0
            ? controller.preferences.rotationIndex % totalInLoop
            : 0);
    final latestWeighIn =
        controller.weighIns.isNotEmpty ? controller.weighIns.first : null;
    final prevWeighIn =
        controller.weighIns.length > 1 ? controller.weighIns[1] : null;
    final weightDelta = (latestWeighIn != null && prevWeighIn != null)
        ? latestWeighIn.weightKg - prevWeighIn.weightKg
        : null;
    final unit = controller.preferences.weightUnit;
    final goal = controller.preferences.goalWeightKg;
    final chartValues =
        controller.weighIns.reversed.map((w) => w.weightKg).toList();
    final lastWorkout =
        controller.history.isNotEmpty ? controller.history.first : null;
    final streak = controller.weeklyStreak;

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final loggedDays = controller.history
        .map((w) => DateTime.tryParse(w.startedAt)?.toLocal())
        .whereType<DateTime>()
        .map((dt) => '${dt.year}-${dt.month}-${dt.day}')
        .toSet();
    final thisWeekCount = List<int>.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      return loggedDays.contains('${d.year}-${d.month}-${d.day}') ? 1 : 0;
    }).fold<int>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Back to HealthKeepr',
              icon: const Icon(Icons.arrow_back),
              onPressed: onExitModule,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'OpenGym',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _formattedToday(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Settings & Server',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      OpenGymSettingsScreen(controller: controller),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      controller.preferences.trainingMode == 'fixed_week'
                          ? 'This week'
                          : 'Rotation',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      controller.preferences.trainingMode == 'fixed_week'
                          ? '$thisWeekCount workouts this week'
                          : '$doneThisRound of $totalInLoop done this round',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (controller.preferences.trainingMode == 'fixed_week') ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List<Widget>.generate(7, (i) {
                      final day = monday.add(Duration(days: i));
                      const shortDays = <String>[
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ];
                      final isToday = i == now.weekday - 1;
                      final done = loggedDays
                          .contains('${day.year}-${day.month}-${day.day}');
                      final planned =
                          controller.routinesForWeekday(i + 1).isNotEmpty;
                      return Column(
                        children: <Widget>[
                          Text(
                            shortDays[i],
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isToday
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? colorScheme.primaryContainer
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${day.day}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done
                                  ? colorScheme.primary
                                  : (planned
                                      ? colorScheme.tertiary
                                      : Colors.transparent),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 10),
                if (upNext != null)
                  Row(
                    children: <Widget>[
                      RoutineGlyphBadge(iconKey: upNext.iconKey, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Today • Up next',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              upNext.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => onStartTemplate(upNext),
                        child: const Text('Train'),
                      ),
                    ],
                  )
                else
                  Text(
                    'Rest day scheduled for today',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (lastWorkout != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Card.filled(
                    child: ListTile(
                      leading: Icon(
                        Icons.check_circle_outline,
                        color: colorScheme.primary,
                      ),
                      title: Text(lastWorkout.title),
                      subtitle: const Text('Latest completed session'),
                      trailing: const Chip(
                        label: Text('Done'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: onChooseWorkout,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Choose a different workout'),
                  ),
                ),
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
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      child: const Icon(Icons.monitor_weight_outlined, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text('Body weight', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _quickLogWeight(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Log'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          latestWeighIn != null
                              ? '${latestWeighIn.weightKg.toStringAsFixed(1)} $unit'
                              : '— $unit',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (weightDelta != null && weightDelta.abs() >= 0.05) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            '${weightDelta < 0 ? '▼' : '▲'} ${weightDelta.abs().toStringAsFixed(1)}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: weightDelta <= 0
                                  ? colorScheme.primary
                                  : colorScheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (latestWeighIn != null)
                      Text(
                        latestWeighIn.date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                if (goal != null && latestWeighIn != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Goal ${goal.toStringAsFixed(0)} $unit • '
                    '${(latestWeighIn.weightKg - goal).abs().toStringAsFixed(1)} $unit to go',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.tertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OpenGymLineChart(values: chartValues, goalValue: goal),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    ActionChip(
                      avatar: const Icon(Icons.flag_outlined, size: 16),
                      label: Text(
                        goal != null
                            ? '${goal.toStringAsFixed(0)} $unit'
                            : 'Set goal',
                      ),
                      onPressed: () => _editGoalWeight(context),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Body & Weigh-ins')),
                            body: MeasurementsScreen(controller: controller),
                          ),
                        ),
                      ),
                      child: const Text('All weigh-ins >'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: const Icon(Icons.local_fire_department_outlined),
            ),
            title: Text(
              '${streak.currentWeeks} week streak',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${controller.history.length} workouts total • Best ${streak.longestWeeks}w',
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanTab extends StatefulWidget {
  const _PlanTab({
    required this.controller,
    required this.onOpenMuscleVolume,
  });

  final OpenGymController controller;
  final VoidCallback onOpenMuscleVolume;

  @override
  State<_PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<_PlanTab> {
  bool _showRoutines = false;
  bool _editingLoop = false;
  bool _editingRoutines = false;

  static const List<String> _weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _weekdayShort = <String>[
    'Mo',
    'Tu',
    'We',
    'Th',
    'Fr',
    'Sa',
    'Su',
  ];

  void _openRoutineEditor(WorkoutTemplate template) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoutineBuilderScreen(
          controller: widget.controller,
          existingTemplate: template,
        ),
      ),
    );
  }

  Future<void> _createAndOpenNewRoutine() async {
    final created = await widget.controller.createNewRoutine();
    if (mounted) {
      _openRoutineEditor(created);
    }
  }

  Future<void> _deleteRoutineWithUndo(WorkoutTemplate template) async {
    final snapshot =
        await widget.controller.deleteTemplateWithSnapshot(template.id);
    if (snapshot == null || !mounted) return;
    showOpenGymUndoToast(
      context,
      message: '“${template.name}” gone.',
      onUndo: () => widget.controller.restoreTemplateSnapshot(snapshot),
    );
  }

  Future<void> _duplicateRoutineWithUndo(WorkoutTemplate template) async {
    final copy = await widget.controller.duplicateTemplate(
      template.id,
      insertBelowOriginal: true,
    );
    if (!mounted) return;
    showOpenGymUndoToast(
      context,
      message: 'Copied as “${copy.name}”.',
      onUndo: () => widget.controller.deleteTemplate(copy.id),
    );
  }

  Future<void> _removeStopFromLoopWithUndo(int index, String stopName) async {
    final snap = await widget.controller.removeStopFromRotation(index);
    if (!mounted) return;
    showOpenGymUndoToast(
      context,
      message: '“$stopName” is out of the loop.',
      onUndo: () => widget.controller.restoreRotationSnapshot(snap),
    );
  }

  Future<void> _switchTrainingMode(String nextMode) async {
    final current = widget.controller.preferences.trainingMode;
    if (nextMode == current) return;

    if (nextMode == 'fixed_week' &&
        widget.controller.rotationSequence.isNotEmpty) {
      final confirmed = await showBackToFixedWeekDialog(context);
      if (!confirmed) return;
    }

    await widget.controller.savePreferences(
      widget.controller.preferences.copyWith(trainingMode: nextMode),
    );
  }

  String _routineSubtitle(WorkoutTemplate t) {
    final parts = <String>['${t.entries.length} exercises'];
    final days = widget.controller.assignedWeekdaysForTemplate(t.id);
    if (days.isNotEmpty) {
      parts.add(days.map((d) => _weekdayShort[(d - 1).clamp(0, 6)]).join(', '));
    }
    return parts.join(' · ');
  }

  Widget _buildRoutineRow(WorkoutTemplate t) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final partsMap = <String, int>{
      for (final e in t.entries) e.bodyPart: 4,
    };

    final card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: RoutineGlyphBadge(iconKey: t.iconKey),
        title: Row(
          children: <Widget>[
            if (t.isFavorite) ...<Widget>[
              Icon(
                Icons.star_rounded,
                size: 16,
                color: Colors.amber.shade600,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                t.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(_routineSubtitle(t)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (t.entries.isNotEmpty)
              BodyMapWidget(
                weeklySetsByBodyPart: partsMap,
                compact: true,
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _openRoutineEditor(t),
      ),
    );

    if (!widget.controller.preferences.swipeActionsEnabled) return card;

    return Dismissible(
      key: ValueKey<String>('routine_${t.id}'),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.copy_rounded, color: colorScheme.onPrimary),
            const SizedBox(width: 8),
            Text(
              'Duplicate',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              'Delete',
              style: TextStyle(
                color: colorScheme.onError,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline, color: colorScheme.onError),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _duplicateRoutineWithUndo(t);
        } else {
          await _deleteRoutineWithUndo(t);
        }
        return false;
      },
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final templates = widget.controller.templates;
    final mode = widget.controller.preferences.trainingMode;
    final isConnected =
        widget.controller.serverConnection?.isConnected ?? false;

    final seq = widget.controller.rotationSequence;
    final nextLoopIdx = widget.controller.nextRotationStopIndex;
    final completedLoopSet =
        widget.controller.preferences.rotationCompletedIndices.toSet();
    final byId = <String, WorkoutTemplate>{
      for (final t in templates) t.id: t,
    };

    // Group routines for non-edit Routines tab (Favourites, unfoldered, folders).
    final favTemplates = templates.where((t) => t.isFavorite).toList();
    final nonFavTemplates = templates.where((t) => !t.isFavorite).toList();
    final unfoldered = nonFavTemplates
        .where((t) => t.folder == null || t.folder!.trim().isEmpty)
        .toList();
    final folderMap = <String, List<WorkoutTemplate>>{};
    for (final t in nonFavTemplates) {
      final f = t.folder?.trim();
      if (f != null && f.isNotEmpty) {
        folderMap.putIfAbsent(f, () => <WorkoutTemplate>[]).add(t);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Plan',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    mode == 'fixed_week'
                        ? 'Your weekly routine'
                        : 'Your routines in a loop',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isConnected) ...<Widget>[
              IconButton.filledTonal(
                tooltip: 'Community routines',
                icon: const Icon(Icons.public_outlined),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityRoutinesScreen(
                      controller: widget.controller,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            IconButton.filledTonal(
              tooltip: 'Plan options',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => showPlanOptionsSheet(
                context,
                controller: widget.controller,
                onOpenRoutine: _openRoutineEditor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(value: false, label: Text('Schedule')),
              ButtonSegment<bool>(value: true, label: Text('Routines')),
            ],
            selected: <bool>{_showRoutines},
            onSelectionChanged: (s) => setState(() => _showRoutines = s.first),
          ),
        ),
        const SizedBox(height: 16),
        if (!_showRoutines) ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.repeat_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('How you train', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'fixed_week',
                          label: Text('Fixed Week'),
                        ),
                        ButtonSegment<String>(
                          value: 'rotation',
                          label: Text('Rotation'),
                        ),
                      ],
                      selected: <String>{mode},
                      onSelectionChanged: (s) => _switchTrainingMode(s.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mode == 'rotation'
                ? 'Routines in a loop. Whatever is next stays next until you train it, whatever the day.'
                : 'The same routines on the same weekdays, every week.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (mode == 'fixed_week') ...<Widget>[
            Text('This week', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: List<Widget>.generate(7, (i) {
                  final weekday = i + 1;
                  final dayRoutines = widget.controller.routinesForWeekday(weekday);
                  final isRest = dayRoutines.isEmpty;
                  final partsMap = <String, int>{
                    for (final r in dayRoutines)
                      for (final e in r.entries) e.bodyPart: 4,
                  };
                  return Column(
                    children: <Widget>[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SizedBox(
                              width: 30,
                              child: Text(
                                _weekdayShort[i],
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: weekday == DateTime.now().weekday
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            RoutineGlyphBadge(
                              iconKey: isRest
                                  ? 'moon'
                                  : dayRoutines.first.iconKey,
                              isRestDay: isRest,
                              size: 36,
                            ),
                          ],
                        ),
                        title: Text(
                          isRest
                              ? 'Rest day'
                              : dayRoutines.map((r) => r.name).join(' + '),
                        ),
                        subtitle: Text(
                          isRest
                              ? 'Tap to plan something'
                              : dayRoutines.length == 1
                                  ? '${dayRoutines.first.entries.length} exercises'
                                  : '${dayRoutines.length} routines',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (!isRest && partsMap.isNotEmpty)
                              BodyMapWidget(
                                weeklySetsByBodyPart: partsMap,
                                compact: true,
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => showDayAssignSheet(
                          context,
                          controller: widget.controller,
                          weekday: weekday,
                          weekdayName: _weekdayNames[i],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Want two routines on one day? Tap the day and pick both.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Programmes'),
                    subtitle: const Text(
                      'Run a multi-week block with %1RM or RPE targets',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProgrammesScreen(controller: widget.controller),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: const Text('Load a starter plan'),
                    subtitle: const Text('PPL, Upper / Lower, 5×5, Bodyweight'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showStarterPlanSheet(
                      context,
                      controller: widget.controller,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            Row(
              children: <Widget>[
                Text('The loop', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (seq.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        setState(() => _editingLoop = !_editingLoop),
                    child: Text(_editingLoop ? 'Done' : 'Edit'),
                  ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: templates.isEmpty
                      ? null
                      : () => showAddToRotationSheet(
                            context,
                            controller: widget.controller,
                          ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (seq.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No rotation yet. Tap + Add to add routines or rest days in the order you want to train them.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else if (_editingLoop)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: seq.length,
                onReorderItem: (oldIndex, newIndex) =>
                    widget.controller.reorderRotation(
                  oldIndex,
                  newIndex,
                  preAdjusted: true,
                ),
                itemBuilder: (context, idx) {
                  final id = seq[idx];
                  final isRest = id == OpenGymController.restStopId;
                  final t = isRest ? null : byId[id];
                  final stopName = isRest ? 'Rest day' : (t?.name ?? 'Routine');
                  final isNext = idx == nextLoopIdx;

                  return Card(
                    key: ValueKey<String>('edit_loop_${idx}_$id'),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: Icon(
                              Icons.remove_circle,
                              color: colorScheme.error,
                            ),
                            tooltip: 'Remove from loop',
                            onPressed: () =>
                                _removeStopFromLoopWithUndo(idx, stopName),
                          ),
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isNext
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            foregroundColor: isNext
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                            child: Text(
                              '${idx + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          RoutineGlyphBadge(
                            iconKey: isRest ? 'moon' : (t?.iconKey ?? 'barbell'),
                            isRestDay: isRest,
                            size: 38,
                          ),
                        ],
                      ),
                      title: Text(stopName),
                      subtitle: Text(
                        isRest
                            ? 'A day off before the next one'
                            : isNext
                                ? 'Up next'
                                : '${t?.entries.length ?? 0} exercises',
                      ),
                      trailing: ReorderableDragStartListener(
                        index: idx,
                        child: const Icon(Icons.unfold_more_rounded),
                      ),
                    ),
                  );
                },
              )
            else
              ...seq.asMap().entries.map((entry) {
                final idx = entry.key;
                final id = entry.value;
                final isRest = id == OpenGymController.restStopId;
                final t = isRest ? null : byId[id];
                final stopName = isRest ? 'Rest day' : (t?.name ?? 'Routine');
                final isDone = !isRest && completedLoopSet.contains(idx);
                final isNext = idx == nextLoopIdx;
                final partsMap = <String, int>{
                  if (t != null)
                    for (final e in t.entries) e.bodyPart: 4,
                };

                final card = Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: isNext || isDone
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          foregroundColor: isNext || isDone
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                          child: isDone
                              ? const Icon(Icons.check, size: 16)
                              : Text(
                                  '${idx + 1}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        RoutineGlyphBadge(
                          iconKey: isRest ? 'moon' : (t?.iconKey ?? 'barbell'),
                          isRestDay: isRest,
                        ),
                      ],
                    ),
                    title: Text(stopName),
                    subtitle: Text(
                      isRest
                          ? 'A day off before the next one'
                          : isDone
                              ? 'Done'
                              : isNext
                                  ? 'Up next'
                                  : '${t?.entries.length ?? 0} exercises',
                    ),
                    trailing: (!isRest && t != null && t.entries.isNotEmpty)
                        ? BodyMapWidget(
                            weeklySetsByBodyPart: partsMap,
                            compact: true,
                          )
                        : null,
                  ),
                );

                if (!widget.controller.preferences.swipeActionsEnabled) {
                  return card;
                }

                return Dismissible(
                  key: ValueKey<String>('loop_${idx}_$id'),
                  direction: DismissDirection.endToStart,
                  background: const SizedBox.shrink(),
                  secondaryBackground: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.remove, color: colorScheme.onError),
                        Text(
                          'Remove',
                          style: TextStyle(
                            color: colorScheme.onError,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (_) async {
                    await _removeStopFromLoopWithUndo(idx, stopName);
                    return false;
                  },
                  child: card,
                );
              }),
            if (seq.isNotEmpty) ...<Widget>[
              Text(
                '${widget.controller.completedInCurrentRound} of ${widget.controller.totalRoutinesInLoop} done this round. '
                '${_editingLoop ? 'Drag to reorder. Tap the minus to take one out.' : 'Trained out of order? Just pick another routine on Home.'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => widget.controller.resetRotation(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Start the loop over'),
                ),
              ),
            ],
          ],
          if (templates.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade400,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: const Text('Weekly muscle volume'),
                subtitle: const Text('See planned vs. completed sets in Stats'),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onOpenMuscleVolume,
              ),
            ),
          ],
        ] else ...<Widget>[
          Row(
            children: <Widget>[
              if (templates.isNotEmpty)
                TextButton(
                  onPressed: () =>
                      setState(() => _editingRoutines = !_editingRoutines),
                  child: Text(_editingRoutines ? 'Done' : 'Edit'),
                ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _createAndOpenNewRoutine,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New routine'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (templates.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.assignment_outlined,
                      size: 36,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    const Text('No routines yet.'),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => showStarterPlanSheet(
                        context,
                        controller: widget.controller,
                      ),
                      icon: const Icon(Icons.assignment_outlined),
                      label: const Text('Load starter plan'),
                    ),
                  ],
                ),
              ),
            )
          else if (_editingRoutines) ...<Widget>[
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: templates.length,
              onReorderItem: (oldIndex, newIndex) =>
                  widget.controller.reorderTemplates(
                oldIndex,
                newIndex,
                preAdjusted: true,
              ),
              itemBuilder: (context, idx) {
                final t = templates[idx];
                return Card(
                  key: ValueKey<String>('edit_routine_${t.id}'),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle,
                            color: colorScheme.error,
                          ),
                          tooltip: 'Delete routine',
                          onPressed: () => _deleteRoutineWithUndo(t),
                        ),
                        RoutineGlyphBadge(iconKey: t.iconKey),
                      ],
                    ),
                    title: Text(t.name),
                    subtitle: Text(_routineSubtitle(t)),
                    trailing: templates.length > 1
                        ? ReorderableDragStartListener(
                            index: idx,
                            child: const Icon(Icons.unfold_more_rounded),
                          )
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              'Drag to reorder. Tap the minus to delete.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...<Widget>[
            if (favTemplates.isNotEmpty) ...<Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Favourites',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...favTemplates.map(_buildRoutineRow),
              const SizedBox(height: 8),
            ],
            ...unfoldered.map(_buildRoutineRow),
            for (final entry in folderMap.entries) ...<Widget>[
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final folderName = entry.key;
                  final folderRoutines = entry.value;
                  final isOpen = widget.controller.isFolderOpen(folderName);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => widget.controller
                            .setFolderOpen(folderName, !isOpen),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.folder_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  folderName,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                '${folderRoutines.length}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                isOpen
                                    ? Icons.keyboard_arrow_down
                                    : Icons.chevron_right,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isOpen) ...folderRoutines.map(_buildRoutineRow),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Tap a routine to edit it. Reorder and delete are behind Edit.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
