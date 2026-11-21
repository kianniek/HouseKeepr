import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../cubits/task_cubit.dart';
import '../../../../home_screen.dart';
import '../../../../models/task.dart';
import '../../../../services/app_haptics.dart';
import '../../../../services/task_rescheduler.dart';
import '../../../common/app_theme.dart';
import '../../../common/widgets/keyboard_inset_padding.dart';
import '../../../common/widgets/task_card.dart';
import '../../../common/widgets/undo_toast.dart';
import '../utils/task_date_utils.dart';
import '../widgets/rebalance_tasks_sheet.dart';
import '../widgets/task_add_dialog.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/workload_calendar_card.dart';

class TasksPage extends StatefulWidget {
  final String? householdId;
  final fb.User? currentUser;
  final DateTime? initialSelectedDate;
  const TasksPage({
    super.key,
    this.householdId,
    this.currentUser,
    this.initialSelectedDate,
  });

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
  bool _overdueExpanded = true;
  bool _dayScheduledExpanded = true;
  bool _highlightAutoBalance = false;
  DateTime? _selectedCalendarDate;
  DateTime _focusedCalendarDate = DateTime.now();
  bool _isCalendarMonthView = false;
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
    _selectedCalendarDate = widget.initialSelectedDate;
    if (widget.initialSelectedDate != null) {
      _focusedCalendarDate = widget.initialSelectedDate!;
    }
    _loadFilters();
    HomeScreen.highlightAutoBalanceNotifier.addListener(
      _onHighlightAutoBalance,
    );
    HomeScreen.openRebalanceSheetNotifier.addListener(
      _onOpenRebalanceSheetSignal,
    );
    HomeScreen.openNewTaskSheetNotifier.addListener(_onOpenNewTaskSheet);
    HomeScreen.selectTasksDateNotifier.addListener(_onSelectTasksDate);
    if (HomeScreen.openRebalanceSheetNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _consumePendingRebalanceSheet();
      });
    }
  }

  @override
  void dispose() {
    HomeScreen.highlightAutoBalanceNotifier.removeListener(
      _onHighlightAutoBalance,
    );
    HomeScreen.openRebalanceSheetNotifier.removeListener(
      _onOpenRebalanceSheetSignal,
    );
    HomeScreen.openNewTaskSheetNotifier.removeListener(_onOpenNewTaskSheet);
    HomeScreen.selectTasksDateNotifier.removeListener(_onSelectTasksDate);
    _bulkImportController.dispose();
    super.dispose();
  }

  void _onSelectTasksDate() {
    final target = HomeScreen.selectTasksDateNotifier.value;
    if (!mounted || target == null) return;
    HomeScreen.selectTasksDateNotifier.value = null;
    setState(() {
      _selectedCalendarDate = target;
      _focusedCalendarDate = target;
    });
  }

  void _onOpenNewTaskSheet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showTaskAddEditDialog(
        context,
        householdId: widget.householdId,
        currentUser: widget.currentUser,
        onBulkImportTap: _showBulkImportSheet,
        initialDeadline: _selectedCalendarDate,
      );
    });
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

  void _onOpenRebalanceSheetSignal() {
    if (!HomeScreen.openRebalanceSheetNotifier.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingRebalanceSheet();
    });
  }

  Future<void> _consumePendingRebalanceSheet() async {
    if (!mounted || !HomeScreen.openRebalanceSheetNotifier.value) return;
    HomeScreen.openRebalanceSheetNotifier.value = false;
    final cubit = context.read<TaskCubit>();
    await cubit.initializationFuture;
    if (!mounted) return;
    await _openRebalanceSheet(fromNotification: true);
  }

  Future<void> _openRebalanceSheet({
    Set<String>? targetTaskIds,
    bool fromNotification = false,
  }) async {
    final cubit = context.read<TaskCubit>();
    final allTasks = cubit.state.tasks;
    final eligible = TaskRescheduler.getEligibleRebalanceTasks(
      targetTaskIds == null
          ? allTasks
          : allTasks.where((t) => targetTaskIds.contains(t.id)).toList(),
    );
    if (eligible.isEmpty) {
      if (fromNotification && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No overdue or due-today tasks to auto-balance.'),
          ),
        );
      }
      return;
    }

    final updates = await showRebalanceTasksSheet(
      context,
      allTasks: allTasks,
      targetTaskIds: targetTaskIds,
    );
    if (!mounted || updates == null || updates.isEmpty) return;

    final previous = await cubit.batchRescheduleTasks(updates);
    AppHaptics.instance.confirm();
    if (!mounted || previous.isEmpty) return;
    showUndoToast(
      context,
      message:
          'Balanced ${previous.length} ${previous.length == 1 ? 'task' : 'tasks'}',
      icon: Icons.auto_awesome,
      onUndo: () => cubit.restoreTasks(previous),
    );
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
        return KeyboardInsetPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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

  List<Task> _filterTasks(List<Task> tasks) {
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
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        final filtered = _filterTasks(state.tasks);
        final eligibleForRebalance = TaskRescheduler.getEligibleRebalanceTasks(
          filtered,
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tasks'),
            actions: [
              if (eligibleForRebalance.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'Auto-balance tasks',
                  onPressed: () => _openRebalanceSheet(
                    targetTaskIds: eligibleForRebalance
                        .map((t) => t.id)
                        .toSet(),
                  ),
                ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildRoomFilters(),
              WorkloadCalendarCard(
                tasks: filtered,
                focusedDate: _focusedCalendarDate,
                selectedDate: _selectedCalendarDate,
                isMonthView: _isCalendarMonthView,
                onDateSelected: (date) {
                  setState(() {
                    _selectedCalendarDate = date;
                    if (date != null && _isCalendarMonthView) {
                      _focusedCalendarDate = date;
                    }
                  });
                },
                onFocusedDateChanged: (date) {
                  setState(() => _focusedCalendarDate = date);
                },
                onViewModeChanged: (isMonth) {
                  setState(() {
                    _isCalendarMonthView = isMonth;
                    if (!isMonth) {
                      _focusedCalendarDate = DateTime.now();
                    }
                  });
                },
              ),
              Expanded(child: _buildTaskList(context, filtered)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              showTaskAddEditDialog(
                context,
                householdId: widget.householdId,
                currentUser: widget.currentUser,
                onBulkImportTap: _showBulkImportSheet,
                initialDeadline: _selectedCalendarDate,
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

  Widget _buildTaskList(BuildContext context, List<Task> filtered) {
    final selectedDay = _selectedCalendarDate;
    if (selectedDay != null) {
      return _buildDayFilteredTaskList(context, filtered, selectedDay);
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
                    onPressed: () {
                      final eligibleIds =
                          TaskRescheduler.getEligibleRebalanceTasks(
                            filtered,
                          ).map((t) => t.id).toSet();
                      _openRebalanceSheet(targetTaskIds: eligibleIds);
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
      padding: EdgeInsets.only(
        bottom: 88 + MediaQuery.paddingOf(context).bottom,
      ),
      children: listChildren,
    );
  }

  Widget _buildDayFilteredTaskList(
    BuildContext context,
    List<Task> filtered,
    DateTime selectedDay,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final isToday = targetDay == today;

    final overdueTasks = <Task>[];
    final scheduledTasks = <Task>[];
    final doneTasks = <Task>[];

    for (final t in filtered) {
      final completedOnDay = isTaskCompletedOnDate(t, targetDay);
      if (doesTaskOccurOnDate(t, targetDay, now: now)) {
        if (completedOnDay) {
          doneTasks.add(t);
        } else {
          scheduledTasks.add(t);
        }
        continue;
      }

      if (isToday && !completedOnDay) {
        final due = effectiveDueDate(t, now: now);
        if (due != null && isOverdue(due, now: now)) {
          overdueTasks.add(t);
        }
      }
    }

    overdueTasks.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    scheduledTasks.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    if (overdueTasks.isEmpty && scheduledTasks.isEmpty && doneTasks.isEmpty) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final dateLabel = isToday
          ? 'Today'
          : DateFormat('EEE, MMM d').format(targetDay);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 36,
                color: scheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                'No tasks scheduled for $dateLabel',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _selectedCalendarDate = null),
                child: const Text('Show all tasks'),
              ),
            ],
          ),
        ),
      );
    }

    final listChildren = <Widget>[];

    void addDaySection({
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

    if (isToday) {
      addDaySection(
        title: 'Overdue',
        items: overdueTasks,
        expanded: _overdueExpanded,
        onToggle: () => setState(() => _overdueExpanded = !_overdueExpanded),
      );
    }

    addDaySection(
      title: isToday
          ? 'Due Today'
          : 'Due ${DateFormat('EEE, MMM d').format(targetDay)}',
      items: scheduledTasks,
      expanded: _dayScheduledExpanded,
      onToggle: () =>
          setState(() => _dayScheduledExpanded = !_dayScheduledExpanded),
    );

    addDaySection(
      title: 'Done',
      items: doneTasks,
      expanded: _doneExpanded,
      onToggle: () => setState(() => _doneExpanded = !_doneExpanded),
      isDoneSection: true,
    );

    return ListView(
      padding: EdgeInsets.only(
        bottom: 88 + MediaQuery.paddingOf(context).bottom,
      ),
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
      if (nextCompleted) {
        AppHaptics.instance.confirm();
      } else {
        AppHaptics.instance.toggleOff();
      }
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
      icon: getTaskIcon(t),
      isCompleted: isCompleted,
      subtitle: buildSubtitle(),
      onToggleComplete: toggleCompletion,
      onTap: () => showTaskDetailSheet(
        context,
        t,
        householdId: widget.householdId,
        currentUser: widget.currentUser,
      ),
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
      AppHaptics.instance.confirm();
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
