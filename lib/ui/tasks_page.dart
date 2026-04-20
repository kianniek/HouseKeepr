import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../cubits/task_cubit.dart';
import '../models/task.dart';
import 'task_add_dialog.dart';
import 'widgets/task_card.dart';

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
  final TextEditingController _bulkImportController = TextEditingController();

  String _bulkTemplateJson() {
    // Provide a concise template that only exposes fields users should edit.
    // Internal/sync fields (ids, versions, timestamps) will be generated
    // or injected during import.
    final template = [
      {
        "title": "String (e.g., 'Dweil de vloer')",
        "description": "String (Optional - extra details about the task)",
        "priority": "Integer (0=low, 1=medium, 2=high, 3=urgent)",
        "deadline": "String (ISO 8601 format: '2026-04-20T12:00:00Z')",
        "room":
            "String (Options: 'Badkamer', 'Keuken', 'Slaapkamer', 'Woonkamer')",
        "isRepeating": "Boolean (true or false)",
        "repeatRule":
            "String (Format: 'every:1:day', 'every:2:week', or 'monthly')",
        "repeatDays":
            "Array of Integers (1=Mon through 7=Sun; e.g., [1, 3] for Mon/Wed)",
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
        } catch (_) {
          // skip malformed entry
        }
      }

      if (tasks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid task objects found')),
        );
        return;
      }

      // Close the sheet and show a confirmation preview page
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
        // --- DEBUG LOGS ---
        debugPrint(
          'TasksPage: REBUILDING. Total tasks in Cubit: ${state.tasks.length}',
        );
        // ------------------

        final repeatingTasksCount = state.tasks
            .where((t) => t.isRepeating)
            .length;
        final regularTasksCount = state.tasks.length - repeatingTasksCount;

        debugPrint('TasksPage: Regular tasks count: $regularTasksCount');
        debugPrint('TasksPage: Repeating tasks count: $repeatingTasksCount');

        return Scaffold(
          appBar: AppBar(title: const Text('Tasks')),
          body: _buildTaskList(context, state.tasks),
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

  DateTime? _nextOccurrence(Task task) {
    if (!task.isRepeating) return null;
    final cfg = _parseRepeatRule(task.repeatRule);
    final now = DateTime.now().toUtc();
    final deadline = (task.deadline ?? now).toUtc();
    final startDate = DateTime.utc(deadline.year, deadline.month, deadline.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    final todayStr = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).toIso8601String().split('T')[0];
    final completedToday = (task.completedDates ?? []).contains(todayStr);

    if (cfg.unit == 'day') {
      final diffDays = today.difference(startDate).inDays;
      if (diffDays < 0) return startDate;
      final remainder = diffDays % cfg.interval;
      final offset = remainder == 0 ? 0 : cfg.interval - remainder;
      final candidate = today.add(Duration(days: offset));
      if (completedToday && candidate.isAtSameMomentAs(today)) {
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
        if (completedToday && offset == 0) continue;
        if (!days.contains(check.weekday)) continue;
        final diff = check.difference(startDate).inDays;
        if (diff < 0) continue;
        final weekIndex = diff ~/ 7;
        if (weekIndex % cfg.interval != 0) continue;
        return DateTime.utc(check.year, check.month, check.day);
      }
      return null;
    }

    if (cfg.unit == 'month') {
      final days = task.repeatDays?.isNotEmpty ?? false
          ? task.repeatDays!
          : <int>[startDate.day];
      for (int m = 0; m <= 24; m++) {
        final monthCandidate = DateTime.utc(now.year, now.month + m, 1);
        final monthDiff =
            (monthCandidate.year - startDate.year) * 12 +
            (monthCandidate.month - startDate.month);
        if (monthDiff < 0 || monthDiff % cfg.interval != 0) continue;
        for (final d in days) {
          try {
            final candidate = DateTime.utc(
              monthCandidate.year,
              monthCandidate.month,
              d,
            );
            if (completedToday && candidate.isAtSameMomentAs(today)) continue;
            if (!candidate.isBefore(now)) return candidate;
          } catch (_) {
            // skip invalid day
          }
        }
      }
    }
    return null;
  }

  int _compareByNextOccurrence(Task a, Task b) {
    final aNext = _nextOccurrence(a);
    final bNext = _nextOccurrence(b);
    if (aNext == null && bNext == null) return a.title.compareTo(b.title);
    if (aNext == null) return 1;
    if (bNext == null) return -1;
    return aNext.compareTo(bNext);
  }

  Widget _buildTaskList(BuildContext context, List<Task> tasks) {
    // Helper: determine if a repeating task is active today
    bool isRepeatingActiveToday(Task t) {
      if (!t.isRepeating) return false;
      // Respect explicit inactiveUntil flag if set — task remains inactive until then
      try {
        final iu = t.inactiveUntil;
        if (iu != null) {
          final nowUtc = DateTime.now().toUtc();
          if (nowUtc.isBefore(iu)) return false;
        }
      } catch (_) {}
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

    bool isDoneForToday(Task t, String todayStr) {
      if (t.isRepeating) {
        return (t.completedDates ?? []).contains(todayStr);
      }
      return t.completed;
    }

    bool isInactiveFutureRepeating(Task t) {
      if (!t.isRepeating) return false;
      final next = _nextOccurrence(t);
      if (next == null) return false;
      final nowUtc = DateTime.now().toUtc();
      final todayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final nextDayUtc = DateTime.utc(next.year, next.month, next.day);
      return nextDayUtc.isAfter(todayUtc);
    }

    final nowUtc = DateTime.now().toUtc();
    final todayStr = nowUtc.toIso8601String().split('T')[0];

    final activeTasks = <Task>[];
    final inactiveFutureTasks = <Task>[];
    final doneTasks = <Task>[];

    for (final t in tasks) {
      final done = isDoneForToday(t, todayStr);
      if (done) {
        doneTasks.add(t);
        continue;
      }

      if (!t.isRepeating) {
        activeTasks.add(t);
        continue;
      }

      if (isRepeatingActiveToday(t)) {
        activeTasks.add(t);
      } else if (isInactiveFutureRepeating(t)) {
        inactiveFutureTasks.add(t);
      }
    }

    inactiveFutureTasks.sort(_compareByNextOccurrence);

    if (activeTasks.isEmpty &&
        inactiveFutureTasks.isEmpty &&
        doneTasks.isEmpty) {
      return const Center(child: Text('No tasks yet'));
    }

    final listChildren = <Widget>[];

    if (activeTasks.isNotEmpty) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Active Tasks',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      );
      listChildren.addAll(
        activeTasks.map(
          (t) => _buildTaskCard(
            context,
            t,
            isRepeating: t.isRepeating,
            isInactive: false,
            taskSection: _TaskSection.active,
          ),
        ),
      );
    }

    if (inactiveFutureTasks.isNotEmpty) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Future (${inactiveFutureTasks.length})',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
      listChildren.addAll(
        inactiveFutureTasks.map(
          (t) => _buildTaskCard(
            context,
            t,
            isRepeating: true,
            isInactive: true,
            taskSection: _TaskSection.future,
          ),
        ),
      );
    }

    if (doneTasks.isNotEmpty) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Done (${doneTasks.length})',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
      listChildren.addAll(
        doneTasks.map(
          (t) => _buildTaskCard(
            context,
            t,
            isRepeating: t.isRepeating,
            isInactive: true,
            taskSection: _TaskSection.done,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
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

    Future<void> toggleCompletion() async {
      if (isInactive) return;

      final nextCompleted = !isCompleted;
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

    Future<void> putOffTask() async {
      if (taskSection != _TaskSection.active) {
        return;
      }

      // Move deadline to tomorrow's date.
      final now = DateTime.now().toUtc();
      final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);

      // Increment putOffCount (keeps initialPriority unchanged)
      final updated = t.copyWith(
        deadline: tomorrow,
        putOffCount: t.putOffCount + 1,
      );

      context.read<TaskCubit>().updateTask(updated);
    }

    Future<void> doingItNow() async {
      if (taskSection != _TaskSection.future) {
        return;
      }

      // Pull task back to today's date and decrease put-off pressure.
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);

      final updated = t.copyWith(
        deadline: today,
        putOffCount: t.putOffCount > 0 ? t.putOffCount - 1 : 0,
      );

      context.read<TaskCubit>().updateTask(updated);
    }

    Future<void> undoDone() async {
      if (taskSection != _TaskSection.done) {
        return;
      }

      if (t.isRepeating) {
        await context.read<TaskCubit>().uncompleteOccurrence(t.id, todayStr);
      } else {
        context.read<TaskCubit>().updateTask(t.copyWith(completed: false));
      }
    }

    String smartActionLabel() {
      switch (taskSection) {
        case _TaskSection.active:
          return 'Put Off';
        case _TaskSection.done:
          return 'Undo';
        case _TaskSection.future:
          return 'Do It Now';
      }
    }

    IconData smartActionIcon() {
      switch (taskSection) {
        case _TaskSection.active:
          return Icons.schedule;
        case _TaskSection.done:
          return Icons.undo;
        case _TaskSection.future:
          return Icons.task;
      }
    }

    VoidCallback? smartActionHandler() {
      switch (taskSection) {
        case _TaskSection.active:
          return putOffTask;
        case _TaskSection.done:
          return undoDone;
        case _TaskSection.future:
          return doingItNow;
      }
    }

    String friendlyDate(DateTime d) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dt = DateTime(d.year, d.month, d.day);
      final diff = dt.difference(today).inDays;
      final local = d.toLocal();

      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      if (diff > 1 && diff < 7) return 'In $diff days';
      final datePart =
          '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      return datePart;
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
            Text(t.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (t.deadline != null)
            Text('Due: ${t.deadline!.toLocal()}'.split(' ')[0]),
          if (isRepeating && t.repeatRule != null) ...[
            Text(_repeatLabel(t), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (t.isRepeating)
              Builder(
                builder: (ctx) {
                  final next = _nextOccurrence(t);
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
      onPutOff: smartActionHandler(),
      onLongPress: () => showTaskAddEditDialog(
        context,
        taskToEdit: t,
        currentUser: widget.currentUser,
        householdId: widget.householdId,
      ),
      onDelete: () => context.read<TaskCubit>().deleteTask(t.id),
      enableDismiss: true,
      isRetrying: t.isRetrying,
      elevation: (isCompleted || isInactive) ? 0 : 2,
      isThreeLine:
          (t.assignedToName != null || t.isHouseholdTask) &&
          t.description != null,
      isInactive: isInactive,
      putOffLabel: smartActionLabel(),
      putOffIcon: smartActionIcon(),
      showDoneAction: taskSection == _TaskSection.active,
    );

    if (isInactive) {
      card = Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: card,
        ),
      );
    }

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
      child: KeyedSubtree(key: ValueKey(t.id), child: card),
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

enum _TaskSection { active, future, done }

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

        // Task has no createdBy field, so use assignedToId as the closest local field.
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
