import 'package:flutter/material.dart';
// cloud_firestore is used inside MemberPicker; tasks_page no longer needs a direct import.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../cubits/task_cubit.dart';
import '../models/task.dart';
import 'member_picker.dart';
import 'package:uuid/uuid.dart';

class TasksPage extends StatefulWidget {
  final String? householdId;
  final fb.User? currentUser;
  const TasksPage({super.key, this.householdId, this.currentUser});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  int _tabIndex = 0; // 0 = Regular, 1 = Repeating

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        final regularTasks = state.tasks.where((t) => !t.isRepeating).toList();
        final repeatingTasks = state.tasks.where((t) => t.isRepeating).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tasks'),
            bottom: TabBar(
              controller: TabController(
                length: 2,
                vsync: ScaffoldMessenger.of(context),
              ),
              tabs: const [
                Tab(text: 'Regular'),
                Tab(text: 'Repeating'),
              ],
              onTap: (idx) => setState(() => _tabIndex = idx),
            ),
          ),
          body: _tabIndex == 0
              ? _buildTaskList(context, regularTasks)
              : _buildTaskList(context, repeatingTasks, isRepeating: true),
          // FAB is shown by the parent HomeScreen so TasksPage doesn't define
          // its own FloatingActionButton when it's embedded inside HomeScreen.
        );
      },
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    List<Task> tasks, {
    bool isRepeating = false,
  }) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks yet'));
    }
    final today = DateTime.now();
    bool isToday(DateTime? d) {
      if (d == null) return false;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }

    bool isRepeatingToday(Task t) {
      if (!t.isRepeating || t.repeatRule == null) return false;
      switch (t.repeatRule) {
        case 'daily':
          return true;
        case 'weekly':
          // If the task specifies repeatDays (list of DateTime.weekday values),
          // use those to determine if it repeats today. Otherwise fall back to
          // using the deadline's weekday for backward compatibility.
          if (t.repeatDays != null && t.repeatDays!.isNotEmpty) {
            return t.repeatDays!.contains(today.weekday);
          }
          return t.deadline != null
              ? t.deadline!.weekday == today.weekday
              : false;
        case 'monthly':
          return t.deadline != null ? t.deadline!.day == today.day : false;
        default:
          return false;
      }
    }

    // Tasks for today: due today or repeating today
    final tasksForToday = tasks
        .where((t) => isToday(t.deadline) || isRepeatingToday(t))
        .toList();
    final otherTasks = tasks
        .where((t) => !(isToday(t.deadline) || isRepeatingToday(t)))
        .toList();
    int priorityValue(TaskPriority p) {
      switch (p) {
        case TaskPriority.urgent:
          return 3;
        case TaskPriority.high:
          return 2;
        case TaskPriority.medium:
          return 1;
        case TaskPriority.low:
          return 0;
      }
    }

    tasksForToday.sort(
      (a, b) => priorityValue(b.priority).compareTo(priorityValue(a.priority)),
    );
    otherTasks.sort(
      (a, b) => priorityValue(b.priority).compareTo(priorityValue(a.priority)),
    );

    return ListView(
      children: [
        if (tasksForToday.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Tasks for Today',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ...tasksForToday.map(
            (t) => _buildTaskCard(context, t, isRepeating: isRepeating),
          ),
        ],
        if (otherTasks.isNotEmpty) ...[
          if (tasksForToday.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Other Tasks',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ...otherTasks.map(
            (t) => _buildTaskCard(context, t, isRepeating: isRepeating),
          ),
        ],
      ],
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    Task t, {
    bool isRepeating = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(t.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t.isHouseholdTask)
              const Text('Assigned to: Household (anyone can pick up)'),
            if (!t.isHouseholdTask && t.assignedToName != null)
              Text('Assigned to: ${t.assignedToName}'),
            if (t.description != null) Text(t.description!),
            if (t.deadline != null)
              Text('Due: ${t.deadline!.toLocal()}'.split(' ')[0]),
            if (isRepeating && t.repeatRule != null) ...[
              if (t.repeatRule == 'weekly' && t.repeatDays != null)
                Text(
                  'Repeats weekly on: ${t.repeatDays!.map((d) {
                    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    if (d >= 1 && d <= 7) return names[d - 1];
                    return d.toString();
                  }).join(', ')}',
                )
              else
                Text('Repeats: ${t.repeatRule}'),
            ],
          ],
        ),
        isThreeLine:
            (t.assignedToName != null || t.isHouseholdTask) &&
            t.description != null,
        leading: Checkbox(
          value: t.completed,
          onChanged: (v) {
            context.read<TaskCubit>().updateTask(
              t.copyWith(completed: v ?? false),
            );
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showAddDialog(context, t),
            ),
            if (t.isHouseholdTask &&
                (t.assignedToId == null || t.assignedToId!.isEmpty))
              ElevatedButton(
                onPressed: () async {
                  // Simulate picking up: assign to current user (replace with real user info)
                  final userId = 'currentUserId';
                  final userName = 'You';
                  context.read<TaskCubit>().updateTask(
                    t.copyWith(
                      assignedToId: userId,
                      assignedToName: userName,
                      isHouseholdTask: false,
                    ),
                  );
                },
                child: const Text('Pick up'),
              ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => context.read<TaskCubit>().deleteTask(t.id),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, [Task? taskToEdit]) {
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
    // repeatDays stores DateTime.weekday values (1..7)
    final Set<int> repeatDaysSel = taskToEdit?.repeatDays?.toSet() ?? <int>{};

    // Try to default to current signed-in user when available. Wrap in
    // try/catch so widget tests (which don't initialize Firebase) don't
    // throw.
    // Prefer an explicitly-passed user (from the app) to FirebaseAuth.
    fb.User? currentUser = widget.currentUser;
    if (currentUser == null) {
      try {
        currentUser = fb.FirebaseAuth.instance.currentUser;
      } catch (_) {
        currentUser = null;
      }
    }
    final defaultName =
        currentUser?.displayName ?? currentUser?.email ?? currentUser?.uid;
    if (widget.householdId != null) {
      // For household flows, default member picker to current user if not already set
      selectedMemberId ??= currentUser?.uid;
      selectedMemberName ??= defaultName;
    } else {
      // For non-household flows, prefill the free-text assignee to self if empty
      if (selectedMemberName == null && defaultName != null) {
        assignedCtl.text = defaultName;
        selectedMemberName = defaultName;
      } else if (taskToEdit != null && taskToEdit.assignedToName != null) {
        assignedCtl.text = taskToEdit.assignedToName!;
      }
    }

    showDialog(
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
                    if (widget.householdId != null) ...[
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
                          const Text(
                            'Assign to household (anyone can pick up)',
                          ),
                        ],
                      ),
                      if (!isHouseholdTask)
                        MemberPicker(
                          householdId: widget.householdId!,
                          initialMemberId: selectedMemberId,
                          onChanged: (id, display) {
                            setStateSB(() {
                              selectedMemberId = id;
                              selectedMemberName = display;
                            });
                          },
                        ),
                    ] else ...[
                      // Free-text assignee for non-household flows. Placed before
                      // description so tests that reference TextField.at(1) match.
                      TextField(
                        controller: assignedCtl,
                        decoration: const InputDecoration(
                          labelText: 'Assigned to (optional)',
                        ),
                        onChanged: (v) => setStateSB(() {
                          selectedMemberName = v.trim().isEmpty
                              ? null
                              : v.trim();
                        }),
                      ),
                    ],
                    // Description moved below assigned field so assigned is TextField index 1
                    TextField(
                      controller: descCtl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
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
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text('Daily'),
                          ),
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
                                final selected = repeatDaysSel.contains(
                                  weekday,
                                );
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
                          // If editing, update the existing task; otherwise create a new one
                          if (taskToEdit != null) {
                            final updated = taskToEdit.copyWith(
                              title: titleCtl.text.trim(),
                              description: descCtl.text.isEmpty
                                  ? null
                                  : descCtl.text,
                              assignedToId: isHouseholdTask
                                  ? null
                                  : selectedMemberId,
                              assignedToName: widget.householdId == null
                                  ? (assignedCtl.text.trim().isEmpty
                                        ? null
                                        : assignedCtl.text.trim())
                                  : (isHouseholdTask
                                        ? null
                                        : selectedMemberName),
                              priority: selectedPriority,
                              deadline: deadline,
                              isRepeating: isRepeating,
                              repeatRule: isRepeating ? repeatRule : null,
                              repeatDays: isRepeating && repeatRule == 'weekly'
                                  ? repeatDaysSel.toList()
                                  : null,
                              isHouseholdTask: isHouseholdTask,
                            );
                            context.read<TaskCubit>().updateTask(updated);
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
                              assignedToName: widget.householdId == null
                                  ? (assignedCtl.text.trim().isEmpty
                                        ? null
                                        : assignedCtl.text.trim())
                                  : (isHouseholdTask
                                        ? null
                                        : selectedMemberName),
                              priority: selectedPriority,
                              deadline: deadline,
                              isRepeating: isRepeating,
                              repeatRule: isRepeating ? repeatRule : null,
                              repeatDays: isRepeating && repeatRule == 'weekly'
                                  ? repeatDaysSel.toList()
                                  : null,
                              isHouseholdTask: isHouseholdTask,
                            );
                            context.read<TaskCubit>().addTask(task);
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
}
