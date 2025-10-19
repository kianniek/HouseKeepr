import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../cubits/task_cubit.dart';
import '../models/task.dart';
import 'member_picker.dart';

/// Shows the add/edit Task dialog and saves via TaskCubit.
Future<void> showTaskAddEditDialog(
  BuildContext context, {
  Task? taskToEdit,
  String? householdId,
  fb.User? currentUser,
}) {
  final cubit = context.read<TaskCubit>();
  final titleCtl = TextEditingController(text: taskToEdit?.title ?? '');
  final descCtl = TextEditingController(text: taskToEdit?.description ?? '');
  final assignedCtl = TextEditingController();
  TaskPriority selectedPriority = taskToEdit?.priority ?? TaskPriority.medium;
  String? selectedMemberId = taskToEdit?.assignedToId;
  String? selectedMemberName = taskToEdit?.assignedToName;
  bool isHouseholdTask = taskToEdit?.isHouseholdTask ?? false;
  DateTime? deadline = taskToEdit?.deadline;
  bool isRepeating = taskToEdit?.isRepeating ?? false;
  String? repeatRule = taskToEdit?.repeatRule;
  final Set<int> repeatDaysSel = taskToEdit?.repeatDays?.toSet() ?? <int>{};

  // Try to default to provided currentUser, otherwise try FirebaseAuth (guarded).
  fb.User? cu = currentUser;
  if (cu == null) {
    try {
      cu = fb.FirebaseAuth.instance.currentUser;
    } catch (_) {
      cu = null;
    }
  }
  final defaultName = cu?.displayName ?? cu?.email ?? cu?.uid;
  if (householdId != null) {
    selectedMemberId ??= cu?.uid;
    selectedMemberName ??= defaultName;
  } else {
    if (selectedMemberName == null && defaultName != null) {
      assignedCtl.text = defaultName;
      selectedMemberName = defaultName;
    } else if (taskToEdit != null && taskToEdit.assignedToName != null) {
      assignedCtl.text = taskToEdit.assignedToName!;
    }
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      bool canAdd() => titleCtl.text.trim().isNotEmpty;
      return StatefulBuilder(
        builder: (contextSB, setStateSB) {
          titleCtl.addListener(() => setStateSB(() {}));
          return AlertDialog(
            title: Text(taskToEdit == null ? 'New Task' : 'Edit Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TaskPriority>(
                    initialValue: selectedPriority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: TaskPriority.values
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p.name[0].toUpperCase() + p.name.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setStateSB(() {
                      if (v != null) selectedPriority = v;
                    }),
                  ),
                  const SizedBox(height: 8),
                  if (householdId != null) ...[
                    Row(
                      children: [
                        Checkbox(
                          value: isHouseholdTask,
                          onChanged: (v) => setStateSB(() {
                            isHouseholdTask = v ?? false;
                            if (isHouseholdTask) {
                              selectedMemberId = null;
                              selectedMemberName = null;
                              assignedCtl.text = '';
                            }
                          }),
                        ),
                        const Text('Assign to household (anyone can pick up)'),
                      ],
                    ),
                    if (!isHouseholdTask)
                      MemberPicker(
                        householdId: householdId,
                        initialMemberId: selectedMemberId,
                        onChanged: (id, display) {
                          setStateSB(() {
                            selectedMemberId = id;
                            selectedMemberName = display;
                          });
                        },
                      ),
                  ] else ...[
                    TextField(
                      controller: assignedCtl,
                      decoration: const InputDecoration(
                        labelText: 'Assigned to (optional)',
                      ),
                      onChanged: (v) => setStateSB(() {
                        selectedMemberName = v.trim().isEmpty ? null : v.trim();
                      }),
                    ),
                  ],
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Deadline',
                          ),
                          child: InkWell(
                            onTap: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: contextSB,
                                initialDate: deadline ?? now,
                                firstDate: now,
                                lastDate: DateTime(now.year + 5),
                              );
                              if (picked != null) {
                                setStateSB(() => deadline = picked);
                              }
                            },
                            child: Text(
                              deadline != null
                                  ? '${deadline!.toLocal()}'.split(' ')[0]
                                  : 'Select date',
                              style: TextStyle(
                                color: deadline != null
                                    ? Colors.black
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isRepeating,
                        onChanged: (v) => setStateSB(() {
                          isRepeating = v ?? false;
                          if (!isRepeating) repeatRule = null;
                        }),
                      ),
                      const Text('Repeat'),
                    ],
                  ),
                  if (isRepeating) ...[
                    DropdownButtonFormField<String>(
                      initialValue: repeatRule,
                      decoration: const InputDecoration(
                        labelText: 'Repeat Rule',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                      ],
                      onChanged: (v) => setStateSB(() => repeatRule = v),
                    ),
                    const SizedBox(height: 8),
                    if (repeatRule == 'weekly')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Repeat on:'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: List.generate(7, (idx) {
                              final weekday = idx + 1; // 1..7
                              const names = [
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri',
                                'Sat',
                                'Sun',
                              ];
                              final selected = repeatDaysSel.contains(weekday);
                              return FilterChip(
                                label: Text(names[idx]),
                                selected: selected,
                                onSelected: (v) => setStateSB(() {
                                  if (v) {
                                    repeatDaysSel.add(weekday);
                                  } else {
                                    repeatDaysSel.remove(weekday);
                                  }
                                }),
                              );
                            }),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: canAdd()
                    ? () {
                        if (taskToEdit != null) {
                          final updated = taskToEdit.copyWith(
                            title: titleCtl.text.trim(),
                            description: descCtl.text.isEmpty
                                ? null
                                : descCtl.text,
                            assignedToId: isHouseholdTask
                                ? null
                                : selectedMemberId,
                            assignedToName: householdId == null
                                ? (assignedCtl.text.trim().isEmpty
                                      ? null
                                      : assignedCtl.text.trim())
                                : (isHouseholdTask ? null : selectedMemberName),
                            priority: selectedPriority,
                            deadline: deadline,
                            isRepeating: isRepeating,
                            repeatRule: isRepeating ? repeatRule : null,
                            repeatDays: isRepeating && repeatRule == 'weekly'
                                ? repeatDaysSel.toList()
                                : null,
                            isHouseholdTask: isHouseholdTask,
                          );
                          cubit.updateTask(updated);
                        } else {
                          final id = const Uuid().v4();
                          final task = Task(
                            id: id,
                            title: titleCtl.text.trim(),
                            description: descCtl.text.isEmpty
                                ? null
                                : descCtl.text,
                            assignedToId: isHouseholdTask
                                ? null
                                : selectedMemberId,
                            assignedToName: householdId == null
                                ? (assignedCtl.text.trim().isEmpty
                                      ? null
                                      : assignedCtl.text.trim())
                                : (isHouseholdTask ? null : selectedMemberName),
                            priority: selectedPriority,
                            deadline: deadline,
                            isRepeating: isRepeating,
                            repeatRule: isRepeating ? repeatRule : null,
                            repeatDays: isRepeating && repeatRule == 'weekly'
                                ? repeatDaysSel.toList()
                                : null,
                            isHouseholdTask: isHouseholdTask,
                          );
                          cubit.addTask(task);
                        }
                        Navigator.pop(context);
                      }
                    : null,
                child: Text(taskToEdit == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
