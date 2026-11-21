import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/core/extensions.dart';

import '../../../../cubits/task_cubit.dart';
import '../../../../models/task.dart';
import '../../../common/widgets/assignee_avatar.dart';
import '../../../common/widgets/undo_toast.dart';
import '../utils/task_date_utils.dart';
import 'task_add_dialog.dart';

class _TaskIconKeyword {
  final IconData icon;
  final List<String> keywords;
  const _TaskIconKeyword(this.icon, this.keywords);
}

const List<_TaskIconKeyword> _taskIconKeywords = [
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

IconData? _matchIcon(String text) {
  if (text.isEmpty) return null;
  for (final entry in _taskIconKeywords) {
    for (final keyword in entry.keywords) {
      if (text.contains(keyword)) return entry.icon;
    }
  }
  return null;
}

/// Returns the best matching Material icon for [task] based on its room, title, and description.
IconData getTaskIcon(Task task) {
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

String _repeatLabel(Task t) {
  final (:interval, :unit) = parseRepeatRule(t.repeatRule);
  if (unit == 'week' && (t.repeatDays?.isNotEmpty ?? false)) {
    final repeatDaysStr = t.repeatDays!
        .map((d) {
          const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          if (d >= 1 && d <= 7) return names[d - 1];
          return d.toString();
        })
        .join(', ');
    return 'Repeats weekly on: $repeatDaysStr';
  }
  final unitLabel = interval == 1 ? unit : '${unit}s';
  return 'Repeats every $interval $unitLabel';
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

/// Shows the task detail modal bottom sheet with due date, recurrence,
/// assignee, completion history, Delete (with undo), and Edit actions.
Future<void> showTaskDetailSheet(
  BuildContext context,
  Task t, {
  String? householdId,
  fb.User? currentUser,
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
                      getTaskIcon(t),
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
                        currentUser: currentUser,
                        householdId: householdId,
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
