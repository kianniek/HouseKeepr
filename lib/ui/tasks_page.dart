import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../cubits/task_cubit.dart';
import '../models/task.dart';
import 'task_add_dialog.dart';
import 'widgets/task_card.dart';

class TasksPage extends StatefulWidget {
  final String? householdId;
  final fb.User? currentUser;
  const TasksPage({super.key, this.householdId, this.currentUser});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _RepeatConfig {
  final int interval;
  final String unit; // day, week, month
  const _RepeatConfig(this.interval, this.unit);
}

class _TaskIconKeyword {
  final IconData icon;
  final List<String> keywords;
  const _TaskIconKeyword(this.icon, this.keywords);
}

class _TasksPageState extends State<TasksPage>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0; // 0 = Regular, 1 = Repeating
  late final TabController _tabController;
  bool _todayCompletedExpanded = false;
  bool _otherCompletedExpanded = false;
  final ExpansibleController _todayController =
      ExpansibleController(); // <--- ADD THIS
  final ExpansibleController _otherController =
      ExpansibleController(); // <--- ADD THIS
  final GlobalKey<AnimatedListState> _todayCompletedListKey =
      GlobalKey<AnimatedListState>();
  final GlobalKey<AnimatedListState> _otherCompletedListKey =
      GlobalKey<AnimatedListState>();
  final GlobalKey _todayCompletedTileKey = GlobalKey();
  final GlobalKey _otherCompletedTileKey = GlobalKey();
  final List<Task> _todayCompletedCache = [];
  final List<Task> _otherCompletedCache = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _tabIndex = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        // --- DEBUG LOGS ---
        debugPrint(
          'TasksPage: REBUILDING. Total tasks in Cubit: ${state.tasks.length}',
        );
        // ------------------

        // We rely on TaskCubit to contain ALL tasks (User + Household).
        // FirestoreSyncService merges them. We simply filter here.
        final regularTasks = state.tasks.where((t) => !t.isRepeating).toList();
        final repeatingTasks = state.tasks.where((t) => t.isRepeating).toList();

        debugPrint('TasksPage: Regular tasks count: ${regularTasks.length}');
        debugPrint(
          'TasksPage: Repeating tasks count: ${repeatingTasks.length}',
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tasks'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Regular'),
                Tab(text: 'Repeating'),
              ],
            ),
          ),
          body: _tabIndex == 0
              ? _buildTaskList(context, regularTasks)
              : _buildTaskList(context, repeatingTasks, isRepeating: true),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              showTaskAddEditDialog(
                context,
                householdId: widget.householdId,
                currentUser: widget.currentUser,
              );
            },
            tooltip: 'Add Task',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  _RepeatConfig _parseRepeatRule(String? rule) {
    final raw = (rule ?? '').toLowerCase().trim();
    if (raw.startsWith('every:')) {
      final parts = raw.split(':');
      if (parts.length >= 3) {
        final interval = int.tryParse(parts[1]) ?? 1;
        final unit = parts[2];
        return _RepeatConfig(interval < 1 ? 1 : interval, unit);
      }
    }
    switch (raw) {
      case 'daily':
      case 'day':
      case '':
        return const _RepeatConfig(1, 'day');
      case 'weekly':
      case 'week':
        return const _RepeatConfig(1, 'week');
      case 'monthly':
      case 'month':
        return const _RepeatConfig(1, 'month');
      default:
        return const _RepeatConfig(1, 'day');
    }
  }

  String _repeatLabel(Task t) {
    final cfg = _parseRepeatRule(t.repeatRule);
    if (cfg.unit == 'week' && (t.repeatDays?.isNotEmpty ?? false)) {
      final repeatDaysStr = t.repeatDays!
          .map((d) {
            const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            if (d >= 1 && d <= 7) return names[d - 1];
            return d.toString();
          })
          .join(', ');
      return 'Repeats weekly on: $repeatDaysStr';
    }
    final unitLabel = cfg.interval == 1 ? cfg.unit : '${cfg.unit}s';
    return 'Repeats every ${cfg.interval} $unitLabel';
  }

  Widget _buildTaskList(
    BuildContext context,
    List<Task> tasks, {
    bool isRepeating = false,
  }) {
    // Helper: determine if a repeating task is active today
    bool isRepeatingActiveToday(Task t) {
      if (!t.isRepeating) return false;
      final cfg = _parseRepeatRule(t.repeatRule);
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      final startRaw = (t.deadline ?? now).toUtc();
      final start = DateTime.utc(startRaw.year, startRaw.month, startRaw.day);
      if (today.isBefore(start)) return false;
      final diffDays = today.difference(start).inDays;

      if (cfg.unit == 'day') {
        return diffDays % cfg.interval == 0;
      }
      if (cfg.unit == 'week') {
        final weekIndex = diffDays ~/ 7;
        final weekdayMatches = (t.repeatDays?.isNotEmpty ?? false)
            ? t.repeatDays!.contains(now.weekday)
            : startRaw.weekday == now.weekday;
        return weekdayMatches && weekIndex % cfg.interval == 0;
      }
      if (cfg.unit == 'month') {
        final monthDiff =
            (today.year - start.year) * 12 + (today.month - start.month);
        final dayMatches = (t.repeatDays?.isNotEmpty ?? false)
            ? t.repeatDays!.contains(today.day)
            : start.day == today.day;
        return dayMatches && monthDiff % cfg.interval == 0;
      }
      return false;
    }

    // Filter out repeating tasks that aren't active today (deactivate them)
    final activeTasks = tasks.where((t) {
      if (t.isRepeating && !isRepeating) return false; // Tab filter
      if (isRepeating && !t.isRepeating) return false; // Tab filter
      if (t.isRepeating && !isRepeatingActiveToday(t)) {
        return false; // Hide repeating tasks not active today
      }
      return true;
    }).toList();

    if (activeTasks.isEmpty) {
      return const Center(child: Text('No tasks yet'));
    }

    // Normalize "today" to UTC for comparison
    final today = DateTime.now().toUtc();
    bool isToday(DateTime? d) {
      if (d == null) return false;
      final du = d.toUtc();
      return du.year == today.year &&
          du.month == today.month &&
          du.day == today.day;
    }

    // Tasks for today: due today (regular tasks are not shown if not today unless in Other)
    final tasksForToday = activeTasks
        .where((t) => isToday(t.deadline))
        .toList();
    // Other tasks: non-repeating tasks without a deadline or future deadline
    final otherTasks = activeTasks
        .where((t) => !tasksForToday.contains(t))
        .toList();

    // Helper: determine whether a task is considered completed for grouping.
    bool isTaskCompleted(Task t) {
      if (t.isRepeating) {
        final todayStr = DateTime.now().toUtc().toIso8601String().split('T')[0];
        return (t.completedDates ?? []).contains(todayStr);
      }
      return t.completed;
    }

    Widget buildSection(String title, List<Task> list) {
      final incomplete = list.where((t) => !isTaskCompleted(t)).toList();
      final children = <Widget>[];
      if (incomplete.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Active (${incomplete.length})',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
        children.addAll(
          incomplete.map(
            (t) => _buildTaskCard(context, t, isRepeating: isRepeating),
          ),
        );
      }
      if (children.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    Widget buildCompletedSection(String title, List<Task> list) {
      if (list.isEmpty) return const SizedBox.shrink();
      const taskRowHeight = 80.0;
      final screenHeight = MediaQuery.of(context).size.height;
      final isTodaySection = title == 'Today';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isTodaySection) {
          _syncCompletedSection(
            list,
            _todayCompletedCache,
            _todayCompletedListKey,
            sectionKey: 'Today',
          );
        } else {
          _syncCompletedSection(
            list,
            _otherCompletedCache,
            _otherCompletedListKey,
            sectionKey: 'Other',
          );
        }
      });

      return ExpansionTile(
        key: isTodaySection ? _todayCompletedTileKey : _otherCompletedTileKey,
        controller: isTodaySection ? _todayController : _otherController,
        leading: const Icon(Icons.check_circle_outline),
        title: Text('$title (${list.length})'),
        initiallyExpanded: isTodaySection
            ? _todayCompletedExpanded
            : _otherCompletedExpanded,
        onExpansionChanged: (v) {
          setState(
            () => isTodaySection
                ? _todayCompletedExpanded = v
                : _otherCompletedExpanded = v,
          );
          if (v) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ctx =
                  (isTodaySection
                      ? _todayCompletedTileKey.currentContext
                      : _otherCompletedTileKey.currentContext) ??
                  context;
              Scrollable.ensureVisible(
                ctx,
                alignment: 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            });
          }
        },
        children: [
          SizedBox(
            height: (list.length * taskRowHeight)
                .clamp(taskRowHeight * 2.5, screenHeight * 0.5)
                .toDouble(),
            child: AnimatedList(
              key: isTodaySection
                  ? _todayCompletedListKey
                  : _otherCompletedListKey,
              initialItemCount: isTodaySection
                  ? _todayCompletedCache.length
                  : _otherCompletedCache.length,
              itemBuilder: (ctx, idx, anim) {
                final t = isTodaySection
                    ? _todayCompletedCache[idx]
                    : _otherCompletedCache[idx];
                return _buildCompletedAnimatedItem(
                  ctx,
                  t,
                  anim,
                  sectionKey: isTodaySection ? 'Today' : 'Other',
                );
              },
            ),
          ),
        ],
      );
    }

    final todayCompleted = tasksForToday
        .where((t) => isTaskCompleted(t))
        .toList();
    final otherCompleted = otherTasks.where((t) => isTaskCompleted(t)).toList();

    final activeChildren = <Widget>[];
    if (tasksForToday.isNotEmpty) {
      activeChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Tasks for Today',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      );
      activeChildren.add(buildSection('Today', tasksForToday));
    }
    if (otherTasks.isNotEmpty) {
      if (tasksForToday.isNotEmpty) {
        activeChildren.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Other Tasks',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
      activeChildren.add(buildSection('Other', otherTasks));
    }

    final hasCompleted = todayCompleted.isNotEmpty || otherCompleted.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [...activeChildren, const SizedBox(height: 24)],
          ),
        ),
        if (hasCompleted)
          SafeArea(
            top: false,
            child: Material(
              elevation: 8,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Completed',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (todayCompleted.isNotEmpty)
                      buildCompletedSection('Today', todayCompleted),
                    if (otherCompleted.isNotEmpty)
                      buildCompletedSection('Other', otherCompleted),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    Task t, {
    bool isRepeating = false,
    String? sectionKey,
  }) {
    final todayStr = DateTime.now().toUtc().toIso8601String().split('T')[0];
    final isCompleted = t.isRepeating
        ? (t.completedDates ?? []).contains(todayStr)
        : t.completed;

    Future<void> toggleCompletion() async {
      final nextCompleted = !isCompleted;
      if (nextCompleted && sectionKey != null) {
        setState(() {
          if (sectionKey == 'Today') {
            _todayCompletedExpanded = true;
            _todayController.expand();
          }
          if (sectionKey == 'Other') {
            _otherCompletedExpanded = true;
            _otherController.expand();
          }
        });
      }
      if (t.isRepeating) {
        final cubit = context.read<TaskCubit>();
        if (nextCompleted) {
          await cubit.completeOccurrence(t.id, todayStr);
        } else {
          await cubit.uncompleteOccurrence(t.id, todayStr);
        }
      } else {
        context.read<TaskCubit>().updateTask(
          t.copyWith(completed: nextCompleted),
        );
      }
    }

    DateTime? nextOccurrence(Task task) {
      if (!task.isRepeating) return null;
      final cfg = _parseRepeatRule(task.repeatRule);
      final now = DateTime.now();
      final deadline = task.deadline ?? now;
      final hour = deadline.toLocal().hour;
      final minute = deadline.toLocal().minute;
      final startDate = DateTime(
        deadline.year,
        deadline.month,
        deadline.day,
        hour,
        minute,
      );
      final today = DateTime(now.year, now.month, now.day, hour, minute);

      if (cfg.unit == 'day') {
        final diffDays = today.difference(startDate).inDays;
        if (diffDays < 0) return startDate;
        final remainder = diffDays % cfg.interval;
        final offset = remainder == 0 ? 0 : cfg.interval - remainder;
        final candidate = today.add(Duration(days: offset));
        if (candidate.isBefore(now)) {
          return candidate.add(Duration(days: cfg.interval));
        }
        return candidate;
      }

      if (cfg.unit == 'week') {
        final days = task.repeatDays?.isNotEmpty ?? false
            ? task.repeatDays!
            : <int>[startDate.weekday];
        for (int offset = 0; offset <= 366; offset++) {
          final check = now.add(Duration(days: offset));
          if (!days.contains(check.weekday)) continue;
          final diff = check.difference(startDate).inDays;
          if (diff < 0) continue;
          final weekIndex = diff ~/ 7;
          if (weekIndex % cfg.interval != 0) continue;
          return DateTime(check.year, check.month, check.day, hour, minute);
        }
        return null;
      }

      if (cfg.unit == 'month') {
        final days = task.repeatDays?.isNotEmpty ?? false
            ? task.repeatDays!
            : <int>[startDate.day];
        for (int m = 0; m <= 24; m++) {
          final monthCandidate = DateTime(now.year, now.month + m, 1);
          final monthDiff =
              (monthCandidate.year - startDate.year) * 12 +
              (monthCandidate.month - startDate.month);
          if (monthDiff < 0 || monthDiff % cfg.interval != 0) continue;
          for (final d in days) {
            try {
              final candidate = DateTime(
                monthCandidate.year,
                monthCandidate.month,
                d,
                hour,
                minute,
              );
              if (!candidate.isBefore(now)) return candidate;
            } catch (_) {
              // skip invalid day
            }
          }
        }
      }
      return null;
    }

    String friendlyDate(DateTime d) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dt = DateTime(d.year, d.month, d.day);
      final diff = dt.difference(today).inDays;
      final local = d.toLocal();
      String timePart() {
        final hh = local.hour.toString().padLeft(2, '0');
        final mm = local.minute.toString().padLeft(2, '0');
        return ' at $hh:$mm';
      }

      if (diff == 0) return 'Today${timePart()}';
      if (diff == 1) return 'Tomorrow${timePart()}';
      if (diff > 1 && diff < 7) return 'In $diff days${timePart()}';
      final datePart =
          '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      return '$datePart${timePart()}';
    }

    Widget card = TaskCard(
      task: t,
      icon: _getTaskIcon(t),
      isCompleted: isCompleted,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t.isHouseholdTask)
            const Text('Assigned to: Household (anyone can pick up)')
          else
            Row(
              children: [
                if (t.assignedToName != null)
                  Expanded(
                    child: Text(
                      'Assigned to: ${t.assignedToName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else if (t.assignedToId != null)
                  const Expanded(
                    child: Text(
                      'Assigned to: member',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          if (t.description != null)
            Text(
              t.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (t.deadline != null)
            Text('Due: ${t.deadline!.toLocal()}'.split(' ')[0]),
          if (isRepeating && t.repeatRule != null) ...[
            Text(
              _repeatLabel(t),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (t.isRepeating)
              Builder(
                builder: (ctx) {
                  final next = nextOccurrence(t);
                  if (next != null) {
                    return Text(
                      'Next: ${friendlyDate(next)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            if (t.completedDates != null && t.completedDates!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('Last completed: ${t.completedDates!.last}'),
              ),
          ],
        ],
      ),
      onToggleComplete: toggleCompletion,
      onLongPress: () => showTaskAddEditDialog(
        context,
        taskToEdit: t,
        currentUser: widget.currentUser,
        householdId: widget.householdId,
      ),
      onDelete: () => context.read<TaskCubit>().deleteTask(t.id),
      enableDismiss: true,
      isRetrying: t.isRetrying,
      elevation: isCompleted ? 0 : 2,
      isThreeLine:
          (t.assignedToName != null || t.isHouseholdTask) &&
          t.description != null,
    );

    // Wrap card in AnimatedSwitcher so removals/insertions animate subtly.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) {
        final offsetAnim = Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut)).animate(anim);
        return SlideTransition(
          position: offsetAnim,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(t.id),
        child: card,
      ),
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

  void _syncCompletedSection(
    List<Task> newList,
    List<Task> old,
    GlobalKey<AnimatedListState> listKey, {
    required String sectionKey,
  }) {
    try {
      final newIds = newList.map((t) => t.id).toList();

      // Removals (iterate backwards)
      for (int i = old.length - 1; i >= 0; i--) {
        final id = old[i].id;
        if (!newIds.contains(id)) {
          final removed = old.removeAt(i);
          listKey.currentState?.removeItem(
            i,
            (ctx, anim) => _buildCompletedAnimatedItem(
              ctx,
              removed,
              anim,
              sectionKey: sectionKey,
            ),
            duration: const Duration(milliseconds: 160),
          );
        }
      }

      // Inserts / moves
      for (int i = 0; i < newList.length; i++) {
        final id = newList[i].id;
        final existingIndex = old.indexWhere((t) => t.id == id);
        if (existingIndex == -1) {
          // insert
          old.insert(i, newList[i]);
          listKey.currentState?.insertItem(
            i,
            duration: const Duration(milliseconds: 180),
          );
        } else if (existingIndex != i) {
          final removed = old.removeAt(existingIndex);
          listKey.currentState?.removeItem(
            existingIndex,
            (ctx, anim) => _buildCompletedAnimatedItem(
              ctx,
              removed,
              anim,
              sectionKey: sectionKey,
            ),
            duration: const Duration(milliseconds: 160),
          );
          old.insert(i, removed);
          listKey.currentState?.insertItem(
            i,
            duration: const Duration(milliseconds: 160),
          );
        }
      }
    } catch (_) {}
  }

  Widget _buildCompletedAnimatedItem(
    BuildContext ctx,
    Task t,
    Animation<double> anim, {
    required String sectionKey,
  }) {
    return SizeTransition(
      sizeFactor: anim,
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, child) {
          final scheme = Theme.of(context).colorScheme;
          final highlight = Color.lerp(
            scheme.surface.withAlpha(0),
            scheme.secondaryContainer.withAlpha((0.35 * 255).round()),
            anim.value,
          );
          return Container(color: highlight, child: child);
        },
        child: _buildTaskCard(context, t, sectionKey: sectionKey),
      ),
    );
  }
}
