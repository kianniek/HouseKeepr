import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/services/recurrence_generator.dart';
import 'package:intl/intl.dart';

import '../../../../cubits/task_cubit.dart';
import '../../../../models/task.dart';
import '../profile/pages/settings_page.dart';
import '../tasks/pages/tasks_page.dart';

class DashboardPage extends StatefulWidget {
  final fb.User? currentUser;
  final String? householdId;

  const DashboardPage({super.key, this.currentUser, this.householdId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final userName =
        widget.currentUser?.displayName?.split(' ').first ??
        widget.currentUser?.email?.split('@').first ??
        'User';

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'House Keepr',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Welcome back, $userName 👋',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Bento Grid Layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Use a column for narrow screens, or a 2-column bento row layout for wider screens
                        return Column(
                          children: [
                            // Full-width Daily Progress Bento Box
                            _buildDailyProgressCard(context),
                            const SizedBox(height: 16),

                            // Two-column Bento Row for Weather & Calendar Events
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildWeatherCard(context)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildCalendarCard(context)),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyProgressCard(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final textTheme = theme.textTheme;
        final today = DateTime.now();
        final todayTasks = state.tasks.where((task) {
          if (task.isRepeating) return false;
          if (task.deadline == null) return false;
          final due = task.deadline!;
          return due.year == today.year &&
              due.month == today.month &&
              due.day == today.day;
        }).toList();

        final completedToday = todayTasks.where((t) => t.completed).length;
        final totalToday = todayTasks.length;
        final percentage = totalToday > 0
            ? ((completedToday / totalToday) * 100).round()
            : 100;
        final remaining = totalToday - completedToday;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Progress',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      remaining > 0
                          ? '$remaining ${remaining == 1 ? 'Task' : 'Tasks'} left for today!'
                          : 'You finished all the tasks for today! 🎉',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        final taskCubit = context.read<TaskCubit>();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: taskCubit,
                              child: TasksPage(
                                householdId: widget.householdId,
                                currentUser: widget.currentUser,
                              ),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('View Details'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 90,
                height: 90,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(percentage),
                  tween: Tween<double>(begin: 0, end: percentage / 100),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    final animatedPercent = (value * 100).round();
                    return Stack(
                      children: [
                        Center(
                          child: SizedBox(
                            width: 90,
                            height: 90,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 9,
                              backgroundColor: scheme.onPrimary.withValues(
                                alpha: 0.3,
                              ),
                              strokeCap: StrokeCap.round,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scheme.primary,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '$animatedPercent%',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildWeatherCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      height: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weather',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 24),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '14°C',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Utrecht, Netherlands',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Text(
            'Partly cloudy today',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Note: To make this fully live with Google Calendar events, you can wrap this
    // in a FutureBuilder or a Calendar Bloc if available, or hook it to your calendar data source.
    return Container(
      height: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next Event',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                color: scheme.primary,
                size: 20,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gym',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Tomorrow, 05:15 AM',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            'Shared Calendar',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
