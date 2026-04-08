import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/task_cubit.dart';
import '../models/task.dart';
import 'settings_page.dart';
import 'tasks_page.dart';
import 'widgets/task_card.dart';
// removed unused imports

class DashboardPage extends StatefulWidget {
  final fb.User? currentUser;
  final String? householdId;

  const DashboardPage({super.key, this.currentUser, this.householdId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedRoom = 'Alles';
  final List<String> _rooms = [
    'Alles',
    'Badkamer',
    'Keuken',
    'Slaapkamer',
    'Woonkamer',
  ];

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
                        'Welkom terug, $userName 👋',
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

                    // Daily Progress Card
                    _buildDailyProgressCard(),

                    const SizedBox(height: 24),

                    const SizedBox(height: 24),

                    // Rooms Filter Section
                    Text(
                      'Ruimtes',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildRoomFilters(),

                    const SizedBox(height: 16),

                    // Filtered Tasks
                    _buildFilteredTasksList(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyProgressCard() {
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
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dagelijkse voortgang',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      remaining > 0
                          ? 'Nog $remaining ${remaining == 1 ? 'taak' : 'taken'} te gaan voor vandaag!'
                          : 'Alle taken van vandaag voltooid! 🎉',
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Bekijk details'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                height: 100,
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
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 10,
                              backgroundColor: scheme.onPrimary.withValues(
                                alpha: 0.3,
                              ),
                              strokeCap: StrokeCap.round,
                              trackGap: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scheme.primary,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '$animatedPercent%',
                            style: textTheme.headlineSmall?.copyWith(
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

  Widget _buildRoomFilters() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final textTheme = theme.textTheme;
          final room = _rooms[index];
          final isSelected = room == _selectedRoom;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(room),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedRoom = room;
                });
              },
              selectedColor: scheme.primaryContainer,
              backgroundColor: scheme.surfaceContainerHighest,
              checkmarkColor: scheme.primary,
              labelStyle: textTheme.bodySmall?.copyWith(
                color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilteredTasksList() {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        var tasks = state.tasks.where((task) => !task.completed).toList();

        if (_selectedRoom != 'Alles') {
          tasks = tasks.where((task) => task.room == _selectedRoom).toList();
        }

        if (tasks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Geen taken gevonden',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        return Column(
          children: tasks.take(5).map((task) {
            final recurrence = task.repeatRule;
            final subtitle = recurrence != null
                ? '${task.room ?? 'Algemeen'} • $recurrence'
                : task.room ?? 'Algemeen';

            return TaskCard(
              task: task,
              icon: _getTaskIcon(task),
              isCompleted: task.completed,
              subtitle: Text(subtitle),
              onToggleComplete: () {
                if (task.isRepeating) {
                  final todayStr = DateTime.now()
                      .toUtc()
                      .toIso8601String()
                      .split('T')[0];
                  final cubit = context.read<TaskCubit>();
                  if (task.completed) {
                    cubit.uncompleteOccurrence(task.id, todayStr);
                  } else {
                    cubit.completeOccurrence(task.id, todayStr);
                  }
                } else {
                  context.read<TaskCubit>().updateTask(
                    task.copyWith(completed: !task.completed),
                  );
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  IconData _getTaskIcon(Task task) {
    IconData? match;
    final title = task.title.toLowerCase();
    match = _matchIcon(title);
    if (match != null) return match;
    final description = (task.description ?? '').toLowerCase();
    match = _matchIcon(description);
    return match ?? Icons.home;
  }

  IconData? _matchIcon(String text) {
    if (text.isEmpty) return null;
    for (final entry in _taskIconKeywords) {
      for (final keyword in entry.keywords) {
        if (text.contains(keyword)) return entry.icon;
      }
    }
    return null;
  }

  static final List<_TaskIconKeyword> _taskIconKeywords = [
    _TaskIconKeyword(Icons.bathroom, [
      'bath',
      'badkamer',
      'shower',
      'douche',
      'toilet',
      'wc',
      'sink',
      'wasbak',
    ]),
    _TaskIconKeyword(Icons.kitchen, [
      'kitchen',
      'keuken',
      'cook',
      'koken',
      'dish',
      'afwas',
      'vaat',
      'fridge',
      'koelkast',
    ]),
    _TaskIconKeyword(Icons.bed, ['bed', 'slaapkamer', 'sleep', 'sleeping']),
    _TaskIconKeyword(Icons.weekend, [
      'living',
      'woonkamer',
      'lounge',
      'sofa',
      'couch',
    ]),
    _TaskIconKeyword(Icons.local_laundry_service, [
      'laundry',
      'wash',
      'was',
      'wassen',
      'clothes',
      'kleding',
    ]),
    _TaskIconKeyword(Icons.cleaning_services, [
      'clean',
      'schoon',
      'stof',
      'dweil',
      'mop',
      'vacuum',
      'stofzuig',
    ]),
    _TaskIconKeyword(Icons.shopping_cart, [
      'shop',
      'shopping',
      'boodschap',
      'boodschappen',
      'grocery',
    ]),
    _TaskIconKeyword(Icons.delete, [
      'trash',
      'garbage',
      'vuilnis',
      'prullenbak',
      'afval',
    ]),
    _TaskIconKeyword(Icons.grass, [
      'garden',
      'tuin',
      'plant',
      'plants',
      'lawn',
      'gras',
    ]),
    _TaskIconKeyword(Icons.pets, [
      'pet',
      'huisdier',
      'hond',
      'kat',
      'dog',
      'cat',
    ]),
    _TaskIconKeyword(Icons.directions_car, [
      'car',
      'auto',
      'vehicle',
      'garage',
    ]),
    _TaskIconKeyword(Icons.receipt_long, [
      'bill',
      'bills',
      'invoice',
      'rekening',
      'factuur',
    ]),
    _TaskIconKeyword(Icons.build, [
      'fix',
      'repair',
      'reparatie',
      'maintenance',
      'onderhoud',
    ]),
  ];
}

class _TaskIconKeyword {
  final IconData icon;
  final List<String> keywords;
  const _TaskIconKeyword(this.icon, this.keywords);
}
