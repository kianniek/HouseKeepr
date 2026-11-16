import 'package:flutter/material.dart';

import '../models/workout_template.dart';
import '../state/open_gym_controller.dart';
import 'active_workout_screen.dart';
import 'exercise_library_screen.dart';
import 'routine_builder_screen.dart';
import 'workout_history_screen.dart';

/// Main dashboard for OpenGym with 4 tabs: Workout, Routines, Exercises, History.
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
  int _tabIndex = 0;

  void _openActiveWorkout() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActiveWorkoutScreen(controller: widget.controller),
      ),
    );
  }

  void _startEmptyWorkout() {
    widget.controller.startEmptyWorkout();
    _openActiveWorkout();
  }

  void _startTemplate(WorkoutTemplate template) {
    widget.controller.startFromTemplate(template);
    _openActiveWorkout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final loading = widget.controller.isLoading;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back to HealthKeepr',
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onExitModule,
            ),
            title: const Text('OpenGym'),
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(
                  index: _tabIndex,
                  children: <Widget>[
                    _WorkoutTab(
                      controller: widget.controller,
                      onStartEmpty: _startEmptyWorkout,
                      onResumeActive: _openActiveWorkout,
                      onStartTemplate: _startTemplate,
                    ),
                    _RoutinesTab(
                      controller: widget.controller,
                      onStartTemplate: _startTemplate,
                    ),
                    ExerciseLibraryScreen(controller: widget.controller),
                    WorkoutHistoryScreen(controller: widget.controller),
                  ],
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.play_circle_outline),
                selectedIcon: Icon(Icons.play_circle),
                label: 'Workout',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: 'Routines',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Exercises',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
            ],
          ),
          floatingActionButton: _tabIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => RoutineBuilderScreen(
                          controller: widget.controller,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Routine'),
                )
              : null,
          bottomSheet: widget.controller.hasActiveWorkout && _tabIndex != 0
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

class _WorkoutTab extends StatelessWidget {
  const _WorkoutTab({
    required this.controller,
    required this.onStartEmpty,
    required this.onResumeActive,
    required this.onStartTemplate,
  });

  final OpenGymController controller;
  final VoidCallback onStartEmpty;
  final VoidCallback onResumeActive;
  final ValueChanged<WorkoutTemplate> onStartTemplate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final active = controller.activeWorkout;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (active != null) ...<Widget>[
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Active Session: ${active.title}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${active.completedSetsCount}/${active.totalSetsCount} sets completed',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onResumeActive,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume Workout'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          onPressed: active != null ? onResumeActive : onStartEmpty,
          icon: const Icon(Icons.add),
          label: Text(
            active != null ? 'Return to Active Workout' : 'Start Empty Workout',
          ),
        ),
        const SizedBox(height: 24),
        Text('Quick Start Routines', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...controller.templates.map((template) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(template.name),
              subtitle: Text(
                '${template.entries.length} exercises • ${template.goal}',
              ),
              trailing: FilledButton.tonal(
                onPressed: () => onStartTemplate(template),
                child: const Text('Start'),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _RoutinesTab extends StatelessWidget {
  const _RoutinesTab({
    required this.controller,
    required this.onStartTemplate,
  });

  final OpenGymController controller;
  final ValueChanged<WorkoutTemplate> onStartTemplate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = controller.templates;

    if (templates.isEmpty) {
      return const Center(
        child: Text('No routines yet. Tap + to build one.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final t = templates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        t.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit routine',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => RoutineBuilderScreen(
                              controller: controller,
                              existingTemplate: t,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete routine',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => controller.deleteTemplate(t.id),
                    ),
                  ],
                ),
                if (t.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(t.description, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: t.entries
                      .map(
                        (e) => Chip(
                          label: Text(
                            '${e.exerciseName} (${e.targetSets}×${e.targetReps})',
                            style: theme.textTheme.labelSmall,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => onStartTemplate(t),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Routine'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
