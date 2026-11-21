import 'package:flutter/material.dart';

import '../../../../models/task.dart';
import '../../../../services/task_rescheduler.dart';
import '../utils/task_date_utils.dart';

/// Shows a bottom sheet previewing proposed dates for redistributing overdue
/// and due-today tasks, returning the confirmed `{taskId: targetDate}` map or
/// `null` if cancelled.
Future<Map<String, DateTime>?> showRebalanceTasksSheet(
  BuildContext context, {
  required List<Task> allTasks,
  Set<String>? targetTaskIds,
  bool initialKeepTodayCapacity = true,
}) {
  return showModalBottomSheet<Map<String, DateTime>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) => _RebalanceTasksSheetContent(
        allTasks: allTasks,
        targetTaskIds: targetTaskIds,
        initialKeepTodayCapacity: initialKeepTodayCapacity,
        scrollController: scrollController,
      ),
    ),
  );
}

class _RebalanceTasksSheetContent extends StatefulWidget {
  final List<Task> allTasks;
  final Set<String>? targetTaskIds;
  final bool initialKeepTodayCapacity;
  final ScrollController scrollController;

  const _RebalanceTasksSheetContent({
    required this.allTasks,
    required this.targetTaskIds,
    required this.initialKeepTodayCapacity,
    required this.scrollController,
  });

  @override
  State<_RebalanceTasksSheetContent> createState() =>
      _RebalanceTasksSheetContentState();
}

class _RebalanceTasksSheetContentState
    extends State<_RebalanceTasksSheetContent> {
  late bool _keepTodayCapacity;
  late Map<String, RescheduleSuggestion> _suggestions;
  late Set<String> _selectedIds;
  late Map<String, Task> _taskById;

  @override
  void initState() {
    super.initState();
    _keepTodayCapacity = widget.initialKeepTodayCapacity;
    _taskById = {for (final t in widget.allTasks) t.id: t};
    _recompute();
  }

  void _recompute() {
    _suggestions = TaskRescheduler.previewRebalance(
      widget.allTasks,
      targetTaskIds: widget.targetTaskIds,
      includeToday: true,
      keepTodayCapacity: _keepTodayCapacity,
    );
    _selectedIds = _suggestions.keys.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = _suggestions.entries.toList();
    final selectedCount = _selectedIds.length;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Balance Tasks',
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        'Spread overdue and today\'s tasks into lighter days.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SwitchListTile(
              value: _keepTodayCapacity,
              onChanged: (val) {
                setState(() {
                  _keepTodayCapacity = val;
                  _recompute();
                });
              },
              title: const Text('Keep up to 4 tasks for today'),
              subtitle: Text(
                _keepTodayCapacity
                    ? 'Highest-priority tasks stay on today; overflow moves'
                    : 'Push all eligible tasks to tomorrow or later',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              dense: true,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _keepTodayCapacity
                            ? 'All tasks fit within today\'s 4-task limit. Toggle off "Keep up to 4 tasks for today" to push them to upcoming days.'
                            : 'No overdue or today tasks to redistribute.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final task = _taskById[entry.key];
                      if (task == null) return const SizedBox.shrink();
                      final suggestion = entry.value;
                      final checked = _selectedIds.contains(task.id);
                      final currentDue = effectiveDueDate(task);
                      final currentLabel = currentDue != null
                          ? formatRelativeDueDate(currentDue)
                          : 'Unscheduled';
                      final targetLabel = formatRelativeDueDate(
                        suggestion.targetDate,
                      );
                      final overdue =
                          currentDue != null && isOverdue(currentDue);

                      return CheckboxListTile(
                        value: checked,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(task.id);
                            } else {
                              _selectedIds.remove(task.id);
                            }
                          });
                        },
                        title: Text(
                          sanitizeTaskTitle(task.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  currentLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: overdue
                                        ? scheme.error
                                        : scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    size: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  targetLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              suggestion.reason,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: selectedCount == 0
                      ? null
                      : () {
                          final updates = <String, DateTime>{
                            for (final id in _selectedIds)
                              if (_suggestions.containsKey(id))
                                id: _suggestions[id]!.targetDate,
                          };
                          Navigator.of(context).pop(updates);
                        },
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    selectedCount == 0
                        ? 'Select tasks'
                        : 'Reschedule $selectedCount ${selectedCount == 1 ? 'task' : 'tasks'}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
