// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../cubits/task_cubit.dart';
import '../models/task.dart';
import '../services/household_service.dart';

/// Shows the add/edit Task dialog and saves via TaskCubit.
Future<void> showTaskAddEditDialog(
  BuildContext context, {
  Task? taskToEdit,
  String? householdId,
  fb.User? currentUser,
  Future<void> Function()? onBulkImportTap,
}) async {
  final cubit = context.read<TaskCubit>();
  final titleCtl = TextEditingController(text: taskToEdit?.title ?? '');
  final descCtl = TextEditingController(text: taskToEdit?.description ?? '');
  TaskPriority selectedPriority = taskToEdit?.priority ?? TaskPriority.medium;
  String? selectedMemberId = taskToEdit?.assignedToId;
  String? selectedMemberName = taskToEdit?.assignedToName;
  bool isHouseholdTask = taskToEdit?.isHouseholdTask ?? false;
  String? selectedAssigneeValue = taskToEdit?.isHouseholdTask == true
      ? 'household'
      : taskToEdit?.assignedToId;
  DateTime? deadline = taskToEdit?.deadline;
  bool isRepeating = taskToEdit?.isRepeating ?? true;
  int repeatInterval = 1;
  String repeatUnit = 'day';
  final Set<int> selectedRepeatDays = {
    ...(taskToEdit?.repeatDays?.where((d) => d >= 1 && d <= 7).toSet() ??
        const <int>{}),
  };
  bool reminderEnabled = taskToEdit?.reminderEnabled ?? false;
  int? reminderOffset = taskToEdit?.reminderOffsetMinutes; // minutes

  String normalizeTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  String normalizeRepeatUnit(String? value) {
    final raw = (value ?? '').toLowerCase().trim();
    switch (raw) {
      case 'day':
      case 'daily':
        return 'day';
      case 'week':
      case 'weekly':
        return 'week';
      case 'month':
      case 'monthly':
        return 'month';
      default:
        return 'day';
    }
  }

  void parseRepeatRule(String? rule) {
    final raw = (rule ?? '').toLowerCase().trim();
    if (raw.startsWith('every:')) {
      final parts = raw.split(':');
      if (parts.length >= 3) {
        final parsedInterval = int.tryParse(parts[1]) ?? 1;
        repeatInterval = parsedInterval < 1 ? 1 : parsedInterval;
        repeatUnit = normalizeRepeatUnit(parts[2]);
      }
      return;
    }
    switch (raw) {
      case 'daily':
      case 'day':
        repeatInterval = 1;
        repeatUnit = 'day';
        break;
      case 'weekly':
      case 'week':
        repeatInterval = 1;
        repeatUnit = 'week';
        break;
      case 'monthly':
      case 'month':
        repeatInterval = 1;
        repeatUnit = 'month';
        break;
      default:
        repeatInterval = 1;
        repeatUnit = 'day';
        break;
    }
  }

  parseRepeatRule(taskToEdit?.repeatRule);
  final repeatIntervalCtl = TextEditingController(
    text: repeatInterval.toString(),
  );
  final deadlineCtl = TextEditingController(
    text: deadline != null ? '${deadline.toLocal()}'.split(' ')[0] : '',
  );

  // Try to default to provided currentUser, otherwise try FirebaseAuth (guarded).
  fb.User? cu = currentUser;
  if (cu == null) {
    try {
      cu = fb.FirebaseAuth.instance.currentUser;
    } catch (_) {
      cu = null;
    }
  }
  // If caller didn't provide householdId, try to discover it from the
  // households collection (members array). This makes the dialog resilient
  // when callers forget to pass household context or when users have a
  // households.members entry but no users/{uid}.householdId set.
  if (householdId == null && cu != null) {
    try {
      final svc = HouseholdService(FirebaseFirestore.instance);
      householdId = await svc.findHouseholdForUser(cu.uid);
      debugPrint('Dialog fallback detected household: $householdId');
    } catch (e) {
      debugPrint('Dialog household discovery failed: $e');
    }
  }
  final defaultName = cu?.displayName ?? cu?.email ?? cu?.uid;
  if (householdId != null) {
    selectedMemberId ??= cu?.uid;
    selectedMemberName ??= defaultName;
  } else {
    if (selectedMemberName == null && defaultName != null) {
      selectedMemberName = defaultName;
      selectedMemberId ??= cu?.uid;
    }
  }

  // Calling showModalBottomSheet after awaiting potential async work above can
  // trigger `use_build_context_synchronously` analyzer warnings. The builder
  // receives the provided context intentionally; it's safe in this flow.
  // The file may be audited later for a full refactor; for now treat this as
  // an intentional, documented use of the caller's `context`.
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (dialogContext) {
      bool canAdd() {
        final titleOk = titleCtl.text.trim().isNotEmpty;
        if (householdId != null) {
          final assignee = selectedAssigneeValue ?? 'household';
          return titleOk && assignee.isNotEmpty;
        }
        return titleOk;
      }

      List<int>? buildRepeatDaysForSave() {
        if (!isRepeating) return null;
        if (repeatUnit != 'week') return null;
        if (selectedRepeatDays.isEmpty) return null;
        final days = selectedRepeatDays.where((d) => d >= 1 && d <= 7).toList()
          ..sort();
        return days;
      }

      return StatefulBuilder(
        builder: (contextSB, setStateSB) {
          final theme = Theme.of(contextSB);
          titleCtl.addListener(() => setStateSB(() {}));
          // Cache members to avoid flashing empty chips while streams reload.
          final cachedMembers = <Map<String, String?>>[];
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(contextSB).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (taskToEdit == null && onBulkImportTap != null)
                        const SizedBox(width: 8),
                      Text(
                        taskToEdit == null ? 'New Task' : 'Edit Task',
                        style: Theme.of(contextSB).textTheme.titleLarge,
                      ),
                      if (taskToEdit == null && onBulkImportTap != null)
                        TextButton.icon(
                          onPressed: () async {
                            Navigator.pop(contextSB);
                            await onBulkImportTap();
                          },
                          icon: const Icon(Icons.playlist_add_check),
                          label: const Text('Bulk Import'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Priority',
                      style: Theme.of(contextSB).textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 40,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: TaskPriority.values.map((p) {
                          final label =
                              p.name[0].toUpperCase() + p.name.substring(1);
                          IconData icon;
                          switch (p) {
                            case TaskPriority.low:
                              icon = Icons.horizontal_rule;
                              break;
                            case TaskPriority.medium:
                              icon = Icons.drag_handle;
                              break;
                            case TaskPriority.high:
                              icon = Icons.dehaze;
                              break;
                            case TaskPriority.urgent:
                              icon = Icons.priority_high;
                              break;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 18),
                                  const SizedBox(width: 6),
                                  Text(label),
                                ],
                              ),
                              selected: selectedPriority == p,
                              onSelected: (_) =>
                                  setStateSB(() => selectedPriority = p),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (householdId != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Assign to',
                        style: Theme.of(contextSB).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('households')
                          .doc(householdId)
                          .snapshots(),
                      builder: (context, hhSnap) {
                        final membersIds = hhSnap.hasData
                            ? ((hhSnap.data!.data()
                                              as Map<
                                                String,
                                                dynamic
                                              >?)?['members']
                                          as List<dynamic>?)
                                      ?.map((e) => e?.toString() ?? '')
                                      .where((s) => s.isNotEmpty)
                                      .toList() ??
                                  <String>[]
                            : <String>[];

                        Widget buildChips(List<Map<String, String?>> members) {
                          return Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.group, size: 18),
                                    SizedBox(width: 6),
                                    Text('Household'),
                                  ],
                                ),
                                selected:
                                    (selectedAssigneeValue ?? 'household') ==
                                    'household',
                                onSelected: (_) => setStateSB(() {
                                  selectedAssigneeValue = 'household';
                                  isHouseholdTask = true;
                                  selectedMemberId = null;
                                  selectedMemberName = null;
                                }),
                              ),
                              ...members.map((member) {
                                final id = member['id'] ?? '';
                                final display = member['display'] ?? 'Member';
                                final photoUrl = member['photoUrl'];
                                log(display);
                                return ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundImage:
                                            (photoUrl == null ||
                                                photoUrl.isEmpty)
                                            ? null
                                            : NetworkImage(photoUrl),
                                        child:
                                            (photoUrl == null ||
                                                photoUrl.isEmpty)
                                            ? Text(
                                                display.isNotEmpty
                                                    ? display[0].toUpperCase()
                                                    : '?',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(fontSize: 12),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(display),
                                    ],
                                  ),
                                  selected: selectedAssigneeValue == id,
                                  onSelected: (_) => setStateSB(() {
                                    selectedAssigneeValue = id;
                                    isHouseholdTask = false;
                                    selectedMemberId = id;
                                    selectedMemberName = display;
                                  }),
                                );
                              }),
                            ],
                          );
                        }

                        if (membersIds.isEmpty) {
                          if (cachedMembers.isNotEmpty) {
                            return buildChips(cachedMembers);
                          }
                          return buildChips(const []);
                        }

                        if (membersIds.length <= 10) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .where(
                                  FieldPath.documentId,
                                  whereIn: membersIds,
                                )
                                .snapshots(),
                            builder: (context, snap) {
                              final members = <Map<String, String?>>[];
                              if (snap.hasData) {
                                for (final d in snap.data!.docs) {
                                  final m = d.data() as Map<String, dynamic>;
                                  final display =
                                      m['displayName'] as String? ??
                                      m['email'] as String? ??
                                      d.id;
                                  members.add({
                                    'id': d.id,
                                    'display': display,
                                    'photoUrl': m['photoURL'] as String?,
                                  });
                                }
                                members.sort(
                                  (a, b) => membersIds
                                      .indexOf(a['id'] ?? '')
                                      .compareTo(
                                        membersIds.indexOf(b['id'] ?? ''),
                                      ),
                                );
                                cachedMembers
                                  ..clear()
                                  ..addAll(members);
                              }
                              if (members.isEmpty && cachedMembers.isNotEmpty) {
                                return buildChips(cachedMembers);
                              }
                              return buildChips(members);
                            },
                          );
                        }

                        final futureUsers = Future.wait(
                          membersIds.map(
                            (id) => FirebaseFirestore.instance
                                .collection('users')
                                .doc(id)
                                .get(),
                          ),
                        );
                        return FutureBuilder<List<DocumentSnapshot>>(
                          future: futureUsers,
                          builder: (context, snap) {
                            final members = <Map<String, String?>>[];
                            if (snap.hasData) {
                              for (final d in snap.data!) {
                                if (d.exists) {
                                  final m = d.data() as Map<String, dynamic>?;
                                  final display = m == null
                                      ? d.id
                                      : (m['displayName'] ?? m['email'] ?? d.id)
                                            .toString();
                                  members.add({
                                    'id': d.id,
                                    'display': display,
                                    'photoUrl': m?['photoURL'] as String?,
                                  });
                                }
                              }
                              cachedMembers
                                ..clear()
                                ..addAll(members);
                            }
                            if (members.isEmpty && cachedMembers.isNotEmpty) {
                              return buildChips(cachedMembers);
                            }
                            return buildChips(members);
                          },
                        );
                      },
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Assign to',
                        style: Theme.of(contextSB).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (cu != null)
                          ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundImage:
                                      (cu.photoURL == null ||
                                          cu.photoURL!.isEmpty)
                                      ? null
                                      : NetworkImage(cu.photoURL!),
                                  child:
                                      (cu.photoURL == null ||
                                          cu.photoURL!.isEmpty)
                                      ? Text(
                                          (defaultName?.isNotEmpty ?? false)
                                              ? defaultName![0].toUpperCase()
                                              : '?',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(fontSize: 12),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                Text(defaultName ?? 'Me'),
                              ],
                            ),
                            selected: selectedMemberId == cu.uid,
                            onSelected: (_) => setStateSB(() {
                              selectedMemberId = cu?.uid;
                              selectedMemberName = defaultName;
                            }),
                          ),
                        ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.person_off, size: 18),
                              SizedBox(width: 6),
                              Text('Unassigned'),
                            ],
                          ),
                          selected: selectedMemberId == null,
                          onSelected: (_) => setStateSB(() {
                            selectedMemberId = null;
                            selectedMemberName = null;
                          }),
                        ),
                      ],
                    ),
                  ],
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: deadlineCtl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Deadline',
                      suffixIcon: IconButton(
                        tooltip: 'Pick date',
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: contextSB,
                            initialDate: deadline ?? now,
                            firstDate: now,
                            lastDate: DateTime(now.year + 5),
                          );
                          if (picked != null) {
                            setStateSB(() {
                              deadline = picked;
                              deadlineCtl.text = '${picked.toLocal()}'.split(
                                ' ',
                              )[0];
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Repeat'),
                    value: isRepeating,
                    onChanged: (v) => setStateSB(() => isRepeating = v),
                  ),
                  if (isRepeating) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: repeatIntervalCtl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Every',
                            ),
                            onChanged: (v) => setStateSB(() {
                              final parsed = int.tryParse(v) ?? 1;
                              repeatInterval = parsed < 1 ? 1 : parsed;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: repeatUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'day',
                                child: Text('Day'),
                              ),
                              DropdownMenuItem(
                                value: 'week',
                                child: Text('Week'),
                              ),
                              DropdownMenuItem(
                                value: 'month',
                                child: Text('Month'),
                              ),
                            ],
                            onChanged: (v) => setStateSB(() {
                              repeatUnit = v ?? 'day';
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Repeat days (weekly)',
                        style: Theme.of(contextSB).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: List.generate(7, (index) {
                        const labels = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun',
                        ];
                        final weekday = index + 1;
                        return FilterChip(
                          label: Text(labels[index]),
                          selected: selectedRepeatDays.contains(weekday),
                          onSelected: repeatUnit == 'week'
                              ? (selected) => setStateSB(() {
                                  if (selected) {
                                    selectedRepeatDays.add(weekday);
                                  } else {
                                    selectedRepeatDays.remove(weekday);
                                  }
                                })
                              : null,
                        );
                      }),
                    ),
                    if (repeatUnit != 'week')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Set Unit to Week to apply selected repeat days.',
                          style: Theme.of(contextSB).textTheme.bodySmall,
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reminder'),
                    value: reminderEnabled,
                    onChanged: (v) => setStateSB(() => reminderEnabled = v),
                  ),
                  if (reminderEnabled) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: reminderOffset ?? 60,
                            decoration: const InputDecoration(
                              labelText: 'Notify',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 0,
                                child: Text('At due time'),
                              ),
                              DropdownMenuItem(
                                value: 15,
                                child: Text('15 minutes before'),
                              ),
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30 minutes before'),
                              ),
                              DropdownMenuItem(
                                value: 60,
                                child: Text('1 hour before'),
                              ),
                              DropdownMenuItem(
                                value: 120,
                                child: Text('2 hours before'),
                              ),
                            ],
                            onChanged: (v) =>
                                setStateSB(() => reminderOffset = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: canAdd()
                            ? () {
                                if (taskToEdit != null) {
                                  final updated = taskToEdit.copyWith(
                                    title: normalizeTitle(titleCtl.text),
                                    description: descCtl.text.isEmpty
                                        ? null
                                        : descCtl.text,
                                    assignedToId: isHouseholdTask
                                        ? null
                                        : selectedMemberId,
                                    assignedToName: householdId == null
                                        ? selectedMemberName
                                        : (isHouseholdTask
                                              ? null
                                              : selectedMemberName),
                                    priority: selectedPriority,
                                    deadline: deadline,
                                    isRepeating: isRepeating,
                                    repeatRule: isRepeating
                                        ? 'every:$repeatInterval:$repeatUnit'
                                        : null,
                                    repeatDays: buildRepeatDaysForSave(),
                                    isHouseholdTask: isHouseholdTask,
                                    reminderEnabled: reminderEnabled,
                                    reminderOffsetMinutes: reminderOffset,
                                  );
                                  cubit.updateTask(updated);
                                } else {
                                  final id = const Uuid().v4();
                                  final task = Task(
                                    id: id,
                                    title: normalizeTitle(titleCtl.text),
                                    description: descCtl.text.isEmpty
                                        ? null
                                        : descCtl.text,
                                    assignedToId: isHouseholdTask
                                        ? null
                                        : selectedMemberId,
                                    assignedToName: householdId == null
                                        ? selectedMemberName
                                        : (isHouseholdTask
                                              ? null
                                              : selectedMemberName),
                                    priority: selectedPriority,
                                    deadline: deadline,
                                    isRepeating: isRepeating,
                                    repeatRule: isRepeating
                                        ? 'every:$repeatInterval:$repeatUnit'
                                        : null,
                                    repeatDays: buildRepeatDaysForSave(),
                                    isHouseholdTask: isHouseholdTask,
                                    householdId: householdId,
                                    reminderEnabled: reminderEnabled,
                                    reminderOffsetMinutes: reminderOffset,
                                  );
                                  cubit.addTask(task);
                                }
                                Navigator.pop(context);
                              }
                            : null,
                        child: Text(taskToEdit == null ? 'Add' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
