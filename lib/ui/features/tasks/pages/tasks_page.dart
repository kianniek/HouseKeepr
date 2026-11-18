import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/core/extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../cubits/task_cubit.dart';
import '../../../../home_screen.dart';
import '../../../../models/task.dart';
import '../../../../services/task_rescheduler.dart';
import '../../../common/app_theme.dart';
import '../../../common/widgets/assignee_avatar.dart';
import '../../../common/widgets/task_card.dart';
import '../../../common/widgets/undo_toast.dart';
import '../utils/task_date_utils.dart';
import '../widgets/task_add_dialog.dart';

class _TaskIconKeyword {
  final IconData icon;
  final List<String> keywords;
  const _TaskIconKeyword(this.icon, this.keywords);
}

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

class _TasksPageState extends State<TasksPage> {
  static const String _selectedRoomKey = 'tasks_selected_room_v1';
  static const String _myTasksOnlyKey = 'tasks_my_tasks_only_v1';

  String _selectedRoom = 'Everything';
  bool _hasUserSelectedRoom = false;
  bool _myTasksOnly = false;
  bool _dueSoonExpanded = true;
  bool _upcomingExpanded = true;
  bool _wheneverExpanded = true;
  bool _doneExpanded = false;
  bool _highlightAutoBalance = false;
  final List<String> _rooms = [
    'Everything',
    'Bathroom',
    'Kitchen',
    'Bedroom',
    'Living Room',
  ];
  final TextEditingController _bulkImportController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFilters();
    HomeScreen.highlightAutoBalanceNotifier.addListener(
      _onHighlightAutoBalance,
    );
  }

  @override
  void dispose() {
    HomeScreen.highlightAutoBalanceNotifier.removeListener(
      _onHighlightAutoBalance,
    );
    _bulkImportController.dispose();
    super.dispose();
  }

  void _onHighlightAutoBalance() {
    if (!mounted) return;
    setState(() => _highlightAutoBalance = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _highlightAutoBalance = false);
      }
    });
  }

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRoom = prefs.getString(_selectedRoomKey);
    final savedMyTasks = prefs.getBool(_myTasksOnlyKey) ?? false;
    if (!mounted) return;
    setState(() {
      if (!_hasUserSelectedRoom &&
          savedRoom != null &&
          _rooms.contains(savedRoom)) {
        _selectedRoom = savedRoom;
      }
      _myTasksOnly = savedMyTasks;
    });
  }

  Future<void> _toggleMyTasks() async {
    final next = !_myTasksOnly;
    setState(() => _myTasksOnly = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_myTasksOnlyKey, next);
  }

  Future<void> _selectRoom(String room) async {
    setState(() {
      _hasUserSelectedRoom = true;
      _selectedRoom = room;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedRoomKey, room);
  }

  String _bulkTemplateJson() {
    final template = [
      {
        'title': "String (e.g., 'Dweil de vloer')",
        'description': 'String (Optional - extra details about the task)',
        'priority': 'Integer (0=low, 1=medium, 2=high, 3=urgent)',
        'deadline': "String (ISO 8601 format: '2026-04-20T12:00:00Z')",
        'room':
            "String (Options: 'Bathroom', 'Kitchen', 'Bedroom', 'Living Room')",
        'isRepeating': 'Boolean (true or false)',
        'repeatRule':
            "String (Format: 'every:1:day', 'every:2:week', or 'monthly')",
        'repeatDays':
            'Array of Integers (1=Mon through 7=Sun; e.g., [1, 3] for Mon/Wed)',
      },
    ];

    return const JsonEncoder.withIndent('  ').convert(template);
  }

  Future<void> _copyBulkTemplate() async {
    try {
      final jsonStr = _bulkTemplateJson();
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template copied to clipboard')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to copy template: $e')));
    }
  }

  Future<void> _confirmBulkImport(BuildContext sheetContext) async {
    final raw = _bulkImportController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a JSON array of tasks')),
      );
      return;
    }

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expected a JSON array of task objects'),
          ),
        );
        return;
      }

      final rawEntries = <Map<String, dynamic>>[];
      final tasks = <Task>[];

      for (final e in decoded) {
        try {
          if (e is Map) {
            final map = Map<String, dynamic>.from(e);
            rawEntries.add(map);
            tasks.add(Task.fromMap(map));
          } else if (e is String) {
            final m = Map<String, dynamic>.from(json.decode(e) as Map);
            rawEntries.add(m);
            tasks.add(Task.fromMap(m));
          }
        } catch (_) {}
      }

      if (tasks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid task objects found')),
        );
        return;
      }

      Navigator.of(sheetContext).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => _BulkImportConfirmationPage(
            tasks: tasks,
            rawEntries: rawEntries,
            taskCubit: context.read<TaskCubit>(),
            householdId: widget.householdId,
            currentUser: widget.currentUser,
            buildPreviewCard: (c, task) =>
                _buildTaskCard(c, task, isRepeating: task.isRepeating),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid JSON: $e')));
    }
  }

  Future<void> _showBulkImportSheet() async {
    _bulkImportController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Import Mode',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Paste a JSON array of task objects.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _copyBulkTemplate,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Template'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bulkImportController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Task JSON array',
                    hintText: '[{"title":"Vacuum living room"}]',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _confirmBulkImport(sheetContext),
                    child: const Text('Confirm & Preview'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Tasks')),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildRoomFilters(),
              const SizedBox(height: 8),
              Expanded(child: _buildTaskList(context, state.tasks)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              showTaskAddEditDialog(
                context,
                householdId: widget.householdId,
                currentUser: widget.currentUser,
                onBulkImportTap: _showBulkImportSheet,
              );
            },
            tooltip: 'Add Task',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildRoomFilters() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                Icons.person_outline,
                size: 16,
                color: _myTasksOnly
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
              label: const Text('My Tasks'),
              selected: _myTasksOnly,
              onSelected: (_) => _toggleMyTasks(),
              selectedColor: scheme.secondaryContainer,
              backgroundColor: scheme.surfaceContainerHighest,
              checkmarkColor: scheme.onSecondaryContainer,
              labelStyle: theme.textTheme.bodySmall?.copyWith(
                color: _myTasksOnly
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: _myTasksOnly ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          ..._rooms.map((room) {
            final isSelected = room == _selectedRoom;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(room),
                selected: isSelected,
                onSelected: (_) => _selectRoom(room),
                selectedColor: scheme.primaryContainer,
                backgroundColor: scheme.surfaceContainerHighest,
                checkmarkColor: scheme.onPrimaryContainer,
                labelStyle: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }),
        ],
      ),
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

  Widget _buildTaskList(BuildContext context, List<Task> tasks) {
    // Filter tasks by selected room and optional My Tasks toggle (#7)
    var filtered = tasks.where((t) => !t.archived).toList();
    if (_selectedRoom != 'Everything') {
      filtered = filtered.where((t) => t.room == _selectedRoom).toList();
    }
    if (_myTasksOnly) {
      final uid = widget.currentUser?.uid;
      if (uid != null) {
        filtered = filtered.where((t) => t.assignedToId == uid).toList();
      } else {
        filtered = [];
      }
    }

    bool isDoneForToday(Task t, String todayStr) {
      if (t.isRepeating) {
        return (t.completedDates ?? []).contains(todayStr);
      }
      return t.completed;
    }

    final nowUtc = DateTime.now().toUtc();
    final todayStr = nowUtc.toIso8601String().split('T')[0];

    final dueSoonTasks = <Task>[];
    final upcomingTasks = <Task>[];
    final wheneverTasks = <Task>[];
    final doneTasks = <Task>[];

    for (final t in filtered) {
      if (isDoneForToday(t, todayStr)) {
        doneTasks.add(t);
        continue;
      }
      switch (classifyTimeHorizon(t)) {
        case TimeHorizon.dueSoon:
          dueSoonTasks.add(t);
          break;
        case TimeHorizon.upcoming:
          upcomingTasks.add(t);
          break;
        case TimeHorizon.whenever:
          wheneverTasks.add(t);
          break;
      }
    }

    int compareByEffectiveDue(Task a, Task b) {
      final aDue = effectiveDueDate(a);
      final bDue = effectiveDueDate(b);
      if (aDue == null && bDue == null) return a.title.compareTo(b.title);
      if (aDue == null) return 1;
      if (bDue == null) return -1;
      return aDue.compareTo(bDue);
    }

    dueSoonTasks.sort(compareByEffectiveDue);
    upcomingTasks.sort(compareByEffectiveDue);
    wheneverTasks.sort((a, b) => a.title.compareTo(b.title));

    if (dueSoonTasks.isEmpty &&
        upcomingTasks.isEmpty &&
        wheneverTasks.isEmpty &&
        doneTasks.isEmpty) {
      return const Center(child: Text('No tasks found'));
    }

    final listChildren = <Widget>[];

    final overdueTasks = dueSoonTasks.where((t) {
      final due = effectiveDueDate(t);
      return due != null && isOverdue(due);
    }).toList();

    if (overdueTasks.length >= 3) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      listChildren.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: _highlightAutoBalance
                  ? scheme.primaryContainer
                  : scheme.secondaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: _highlightAutoBalance
                  ? Border.all(color: scheme.primary, width: 2)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${overdueTasks.length} tasks piled up. Spread them across this week?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () async {
                      final cubit = context.read<TaskCubit>();
                      final targetIds = overdueTasks.map((t) => t.id).toSet();
                      final updates = TaskRescheduler.rebalanceOverduePileup(
                        cubit.state.tasks,
                        targetTaskIds: targetIds,
                      );
                      if (updates.isEmpty) return;
                      final previous = await cubit.batchRescheduleTasks(
                        updates,
                      );
                      if (!context.mounted || previous.isEmpty) return;
                      showUndoToast(
                        context,
                        message:
                            'Balanced ${previous.length} overdue ${previous.length == 1 ? 'task' : 'tasks'}',
                        icon: Icons.auto_awesome,
                        onUndo: () => cubit.restoreTasks(previous),
                      );
                    },
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: const Text('Auto-Balance'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    void addSection({
      required String title,
      required List<Task> items,
      required bool expanded,
      required VoidCallback onToggle,
      bool isDoneSection = false,
    }) {
      if (items.isEmpty) return;
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      listChildren.add(
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (expanded) {
        listChildren.addAll(
          items.map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildTaskCard(
                context,
                t,
                isRepeating: t.isRepeating,
                isInactive: isDoneSection,
                taskSection: isDoneSection
                    ? _TaskSection.done
                    : _TaskSection.active,
              ),
            ),
          ),
        );
      }
    }

    addSection(
      title: 'Due Soon',
      items: dueSoonTasks,
      expanded: _dueSoonExpanded,
      onToggle: () => setState(() => _dueSoonExpanded = !_dueSoonExpanded),
    );
    addSection(
      title: 'Upcoming',
      items: upcomingTasks,
      expanded: _upcomingExpanded,
      onToggle: () => setState(() => _upcomingExpanded = !_upcomingExpanded),
    );
    addSection(
      title: 'Whenever',
      items: wheneverTasks,
      expanded: _wheneverExpanded,
      onToggle: () => setState(() => _wheneverExpanded = !_wheneverExpanded),
    );
    addSection(
      title: 'Done',
      items: doneTasks,
      expanded: _doneExpanded,
      onToggle: () => setState(() => _doneExpanded = !_doneExpanded),
      isDoneSection: true,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: listChildren,
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    Task t, {
    bool isRepeating = false,
    bool isInactive = false,
    _TaskSection taskSection = _TaskSection.active,
  }) {
    final todayStr = DateTime.now().toUtc().toIso8601String().split('T')[0];
    final isCompleted = t.isRepeating
        ? (t.completedDates ?? []).contains(todayStr)
        : t.completed;
    final cubit = context.read<TaskCubit>();
    final displayTitle = sanitizeTaskTitle(t.title);

    Future<void> toggleCompletion() async {
      final nextCompleted = !isCompleted;
      if (t.isRepeating) {
        if (nextCompleted) {
          await cubit.completeOccurrence(t.id, todayStr);
        } else {
          await cubit.uncompleteOccurrence(t.id, todayStr);
        }
      } else {
        await cubit.updateTask(t.copyWith(completed: nextCompleted));
      }

      if (!context.mounted) return;
      showUndoToast(
        context,
        message: nextCompleted
            ? 'Completed "$displayTitle"'
            : 'Reopened "$displayTitle"',
        icon: nextCompleted ? Icons.check_circle_outline : Icons.undo,
        onUndo: () {
          if (t.isRepeating) {
            if (nextCompleted) {
              cubit.uncompleteOccurrence(t.id, todayStr);
            } else {
              cubit.completeOccurrence(t.id, todayStr);
            }
          } else {
            cubit.updateTask(t.copyWith(completed: !nextCompleted));
          }
        },
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final due = effectiveDueDate(t);
    final overdue = due != null && isOverdue(due) && !isCompleted;
    final dueLabel = due != null ? formatRelativeDueDate(due) : null;
    final freqLabel = t.isRepeating ? repeatFrequencyLabel(t) : null;

    Widget buildSubtitle() {
      final semantic = AppSemanticColors.of(context);
      final amberBg = semantic.warningContainer;
      final amberFg = semantic.onWarningContainer;

      final parts = <Widget>[];
      if (dueLabel != null) {
        if (overdue) {
          parts.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: amberBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                dueLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: amberFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        } else {
          parts.add(
            Text(
              dueLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          );
        }
      }

      if (freqLabel != null && freqLabel.isNotEmpty) {
        if (parts.isNotEmpty) {
          parts.add(
            Text(
              ' · ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          );
        }
        parts.add(
          Flexible(
            child: Text(
              freqLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      if (parts.isEmpty) {
        parts.add(
          Text(
            (t.room != null && t.room!.isNotEmpty) ? t.room! : 'Whenever',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      }

      return Row(mainAxisSize: MainAxisSize.min, children: parts);
    }

    Widget card = TaskCard(
      task: t,
      icon: _getTaskIcon(t),
      isCompleted: isCompleted,
      subtitle: buildSubtitle(),
      onToggleComplete: toggleCompletion,
      onTap: () => _showTaskDetailSheet(context, t, isCompleted: isCompleted),
      onSnooze: () => _showSnoozeSheet(context, t),
      onLongPress: () => showTaskAddEditDialog(
        context,
        taskToEdit: t,
        currentUser: widget.currentUser,
        householdId: widget.householdId,
      ),
      enableSnooze: !isCompleted,
      isRetrying: t.isRetrying,
      elevation: 0,
      isInactive: false,
    );

    if (isCompleted) {
      card = Opacity(opacity: 0.65, child: card);
    }

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
      child: KeyedSubtree(key: ValueKey(t.id), child: card),
    );
  }

  Future<void> _showSnoozeSheet(BuildContext context, Task t) async {
    final cubit = context.read<TaskCubit>();
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    // Upcoming Saturday (or Sunday if today is Saturday)
    final daysUntilSat = (DateTime.saturday - today.weekday) % 7;
    final thisWeekend = today.add(
      Duration(days: daysUntilSat == 0 ? 1 : daysUntilSat),
    );
    final cfg = _parseRepeatRule(t.repeatRule);
    final DateTime nextCycle;
    if (t.isRepeating) {
      if (cfg.unit == 'month') {
        nextCycle = DateTime.utc(
          today.year,
          today.month + cfg.interval,
          today.day,
        );
      } else if (cfg.unit == 'week') {
        nextCycle = today.add(Duration(days: 7 * cfg.interval));
      } else {
        nextCycle = today.add(Duration(days: cfg.interval));
      }
    } else {
      nextCycle = today.add(const Duration(days: 7));
    }

    Future<void> applySnooze(DateTime target, String label) async {
      final previous = t;
      final updated = t.copyWith(
        deadline: target,
        inactiveUntil: t.isRepeating ? target : t.inactiveUntil,
        putOffCount: t.putOffCount + 1,
      );
      await cubit.updateTask(updated);
      if (!context.mounted) return;
      showUndoToast(
        context,
        message: 'Snoozed "${sanitizeTaskTitle(t.title)}" to $label',
        icon: Icons.snooze,
        onUndo: () => cubit.updateTask(previous),
      );
    }

    final smartPick = TaskRescheduler.suggestBestDate(t, cubit.state.tasks);
    final smartLabel = formatRelativeDueDate(smartPick.targetDate);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Snooze "${sanitizeTaskTitle(t.title)}"',
                  style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.auto_awesome, size: 18),
                      label: Text('Smart: $smartLabel (${smartPick.reason})'),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        applySnooze(smartPick.targetDate, smartLabel);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
                      label: const Text('Tomorrow'),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        applySnooze(tomorrow, 'Tomorrow');
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.weekend_outlined, size: 18),
                      label: const Text('This Weekend'),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        applySnooze(thisWeekend, 'This Weekend');
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.update, size: 18),
                      label: const Text('Next Cycle'),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        applySnooze(nextCycle, 'Next Cycle');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTaskDetailSheet(
    BuildContext context,
    Task t, {
    required bool isCompleted,
  }) async {
    final cubit = context.read<TaskCubit>();
    final displayTitle = sanitizeTaskTitle(t.title);
    final lastCompleted =
        (t.completedDates != null && t.completedDates!.isNotEmpty)
        ? t.completedDates!.last
        : null;
    final due = effectiveDueDate(t);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final scheme = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getTaskIcon(t),
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (t.room != null && t.room!.isNotEmpty)
                            Text(
                              t.room!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!t.isHouseholdTask &&
                        (t.assignedToId != null || t.assignedToName != null))
                      AssigneeAvatar(
                        userId: t.assignedToId,
                        displayName: t.assignedToName,
                        radius: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (t.description != null && t.description!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      t.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                if (due != null)
                  _detailRow(
                    sheetCtx,
                    Icons.event_outlined,
                    'Due: ${formatRelativeDueDate(due)} (${due.toLocalIsoDate()})',
                  ),
                if (t.isRepeating)
                  _detailRow(sheetCtx, Icons.repeat, _repeatLabel(t)),
                _detailRow(
                  sheetCtx,
                  Icons.person_outline,
                  t.isHouseholdTask
                      ? 'Assigned to: Household'
                      : 'Assigned to: ${t.assignedToName ?? 'Member'}',
                ),
                if (lastCompleted != null)
                  _detailRow(
                    sheetCtx,
                    Icons.history,
                    'Last completed: $lastCompleted',
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: Icon(Icons.delete_outline, color: scheme.error),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: scheme.error),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        cubit.deleteTask(t.id);
                        showUndoToast(
                          context,
                          message: 'Deleted "$displayTitle"',
                          icon: Icons.delete_outline,
                          onUndo: () => cubit.addTask(t),
                        );
                      },
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        showTaskAddEditDialog(
                          context,
                          taskToEdit: t,
                          currentUser: widget.currentUser,
                          householdId: widget.householdId,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  IconData _getTaskIcon(Task task) {
    switch ((task.room ?? '').toLowerCase().trim()) {
      case 'bathroom':
        return Icons.bathroom;
      case 'kitchen':
        return Icons.kitchen;
      case 'bedroom':
        return Icons.bed;
      case 'living room':
        return Icons.weekend;
    }
    final title = task.title.toLowerCase();
    final description = (task.description ?? '').toLowerCase();
    final match1 = _matchIcon(title);
    if (match1 != null) return match1;
    final match2 = _matchIcon(description);
    return match2 ?? Icons.home;
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

enum _TaskSection { active, done }

class _BulkImportConfirmationPage extends StatefulWidget {
  final List<Task> tasks;
  final List<Map<String, dynamic>> rawEntries;
  final TaskCubit taskCubit;
  final String? householdId;
  final fb.User? currentUser;
  final Widget Function(BuildContext context, Task task) buildPreviewCard;

  const _BulkImportConfirmationPage({
    required this.tasks,
    required this.rawEntries,
    required this.taskCubit,
    required this.householdId,
    required this.currentUser,
    required this.buildPreviewCard,
  });

  @override
  State<_BulkImportConfirmationPage> createState() =>
      _BulkImportConfirmationPageState();
}

class _BulkImportConfirmationPageState
    extends State<_BulkImportConfirmationPage> {
  bool _isFinalizing = false;

  Future<void> _finalizeImport() async {
    setState(() => _isFinalizing = true);
    try {
      const uuid = Uuid();

      for (int i = 0; i < widget.tasks.length; i++) {
        var task = widget.tasks[i];
        final raw = widget.rawEntries[i];

        if (task.id.trim().isEmpty) {
          task = task.copyWith(id: uuid.v4());
        }

        final currentHouseholdId = task.householdId;
        if ((currentHouseholdId == null || currentHouseholdId.trim().isEmpty) &&
            widget.householdId != null) {
          task = task.copyWith(householdId: widget.householdId);
        }

        final rawCreatedBy =
            raw['createdBy']?.toString() ?? raw['created_by']?.toString();
        final fallbackCreator =
            (rawCreatedBy == null || rawCreatedBy.trim().isEmpty)
            ? widget.currentUser?.uid
            : rawCreatedBy;

        final currentAssignedToId = task.assignedToId;
        if (!task.isHouseholdTask &&
            (currentAssignedToId == null ||
                currentAssignedToId.trim().isEmpty) &&
            fallbackCreator != null &&
            fallbackCreator.isNotEmpty) {
          task = task.copyWith(
            assignedToId: fallbackCreator,
            assignedToName:
                task.assignedToName ??
                widget.currentUser?.displayName ??
                widget.currentUser?.email,
          );
        }

        await widget.taskCubit.addTask(task);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${widget.tasks.length} tasks.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isFinalizing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Preview Import (${widget.tasks.length})')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: widget.tasks.length,
        itemBuilder: (context, index) {
          return widget.buildPreviewCard(context, widget.tasks[index]);
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isFinalizing ? null : _finalizeImport,
            child: _isFinalizing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('FINALIZE IMPORT'),
          ),
        ),
      ),
    );
  }
}
