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

class _TasksPageState extends State<TasksPage>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0; // 0 = Regular, 1 = Repeating
  late final TabController _tabController;

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
        final regularTasks = state.tasks.where((t) => !t.isRepeating).toList();
        final repeatingTasks = state.tasks.where((t) => t.isRepeating).toList();
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
    DateTime? nextOccurrence(Task task) {
      if (!task.isRepeating) return null;
      final now = DateTime.now();
      switch (task.repeatRule) {
        case 'daily':
          // Attach time-of-day from the task.deadline when available.
          final hour = task.deadline?.toLocal().hour ?? 9;
          final minute = task.deadline?.toLocal().minute ?? 0;
          return DateTime(now.year, now.month, now.day, hour, minute);
        case 'weekly':
          final days = task.repeatDays ?? [];
          if (days.isNotEmpty) {
            for (int offset = 0; offset < 7; offset++) {
              final check = now.add(Duration(days: offset));
              if (days.contains(check.weekday)) {
                final hour = task.deadline?.toLocal().hour ?? 9;
                final minute = task.deadline?.toLocal().minute ?? 0;
                return DateTime(
                  check.year,
                  check.month,
                  check.day,
                  hour,
                  minute,
                );
              }
            }
            return null;
          }
          // fallback to deadline weekday
          if (task.deadline != null) {
            final targetWeekday = task.deadline!.weekday;
            for (int offset = 0; offset < 7; offset++) {
              final check = now.add(Duration(days: offset));
              if (check.weekday == targetWeekday) {
                final hour = task.deadline?.toLocal().hour ?? 9;
                final minute = task.deadline?.toLocal().minute ?? 0;
                return DateTime(
                  check.year,
                  check.month,
                  check.day,
                  hour,
                  minute,
                );
              }
            }
          }
          return null;
        case 'monthly':
          if (task.deadline != null) {
            final day = task.deadline!.day;
            final hour = task.deadline?.toLocal().hour ?? 9;
            final minute = task.deadline?.toLocal().minute ?? 0;
            final candidate = DateTime(now.year, now.month, day, hour, minute);
            if (!candidate.isBefore(now)) return candidate;
            // next month
            final nextMonth = DateTime(
              now.year,
              now.month + 1,
              day,
              hour,
              minute,
            );
            return nextMonth;
          }
          return null;
        default:
          return null;
      }
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
      // otherwise return ISO date (YYYY-MM-DD) and time if present
      final datePart =
          '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      return '$datePart${timePart()}';
    }

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
              // show next occurrence when repeating
              if (t.isRepeating)
                Builder(
                  builder: (ctx) {
                    final next = nextOccurrence(t);
                    if (next != null) {
                      return Text('Next: ${friendlyDate(next)}');
                    }
                    return const SizedBox.shrink();
                  },
                ),
              if (t.completedDates != null && t.completedDates!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('Last completed: ${t.completedDates!.last}'),
                ),
              // inline weekly weekday editor
              if (t.repeatRule == 'weekly')
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Wrap(
                    spacing: 6,
                    children: List.generate(7, (idx) {
                      final weekday = idx + 1;
                      const names = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ];
                      final selected = t.repeatDays?.contains(weekday) ?? false;
                      return FilterChip(
                        label: Text(
                          names[idx],
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: selected,
                        onSelected: (v) {
                          final prev = List<int>.from(t.repeatDays ?? <int>[]);
                          final current = Set<int>.from(
                            t.repeatDays ?? <int>{},
                          );
                          if (v) {
                            current.add(weekday);
                          } else {
                            current.remove(weekday);
                          }
                          final updated = t.copyWith(
                            repeatDays: current.toList(),
                          );
                          context.read<TaskCubit>().updateTask(updated);
                          // Show an inline snackbar with Undo to restore previous days
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Updated repeating days'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () {
                                  context.read<TaskCubit>().updateTask(
                                    t.copyWith(repeatDays: prev),
                                  );
                                },
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ),
            ],
          ],
        ),
        isThreeLine:
            (t.assignedToName != null || t.isHouseholdTask) &&
            t.description != null,
        leading: Checkbox(
          value: t.isRepeating
              ? (t.completedDates ?? []).contains(
                  DateTime.now().toUtc().toIso8601String().split('T')[0],
                )
              : t.completed,
          onChanged: (v) async {
            if (t.isRepeating) {
              final todayStr = DateTime.now().toUtc().toIso8601String().split(
                'T',
              )[0];
              final cubit = context.read<TaskCubit>();
              if (v == true) {
                await cubit.completeOccurrence(t.id, todayStr);
              } else {
                await cubit.uncompleteOccurrence(t.id, todayStr);
              }
            } else {
              context.read<TaskCubit>().updateTask(
                t.copyWith(completed: v ?? false),
              );
            }
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showAddDialog(context, t),
            ),
            // Convert one-off task into repeating template
            if (!t.isRepeating)
              IconButton(
                icon: const Icon(Icons.repeat),
                tooltip: 'Make repeating',
                onPressed: () async {
                  final prevIsRepeating = t.isRepeating;
                  final prevRule = t.repeatRule;
                  final prevDays = t.repeatDays;
                  // Capture cubit and messenger before awaiting so we don't use
                  // BuildContext across async gaps.
                  final taskCubit = context.read<TaskCubit>();
                  final messenger = ScaffoldMessenger.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Convert to repeating'),
                      content: const Text(
                        'Convert this task into a repeating template? You can adjust the rule in the next dialog.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Convert'),
                        ),
                      ],
                    ),
                  );
                  if (!mounted) return;
                  if (confirm != true) return;
                  final now = DateTime.now();
                  final edited = t.copyWith(
                    isRepeating: true,
                    repeatRule: 'weekly',
                    repeatDays: [now.weekday],
                  );
                  // We're intentionally passing the current BuildContext into the
                  // dialog helper. We captured context-derived objects (taskCubit
                  // and messenger) above so it's safe to await here.
                  // ignore: use_build_context_synchronously
                  final saved = await _showAddDialog(context, edited);
                  if (!mounted) return;
                  if (saved == true) {
                    // Show snackbar with Undo that will restore previous repeat state
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Converted to repeating'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            // Restore previous repeat state
                            taskCubit.updateTask(
                              t.copyWith(
                                isRepeating: prevIsRepeating,
                                repeatRule: prevRule,
                                repeatDays: prevDays,
                              ),
                            );
                          },
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.cancel),
                tooltip: 'Stop repeating',
                onPressed: () async {
                  final prevRule = t.repeatRule;
                  final prevDays = t.repeatDays;
                  final prevIsRepeating = t.isRepeating;
                  // Capture taskCubit and messenger before awaiting the dialog.
                  final taskCubit = context.read<TaskCubit>();
                  final messenger = ScaffoldMessenger.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Stop repeating'),
                      content: const Text(
                        'Stop repeating this task? This will convert it to a one-off task.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Stop'),
                        ),
                      ],
                    ),
                  );
                  if (!mounted) return;
                  if (confirm != true) return;
                  taskCubit.updateTask(
                    t.copyWith(
                      isRepeating: false,
                      repeatRule: null,
                      repeatDays: null,
                    ),
                  );
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Stopped repeating'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          taskCubit.updateTask(
                            t.copyWith(
                              isRepeating: prevIsRepeating,
                              repeatRule: prevRule,
                              repeatDays: prevDays,
                            ),
                          );
                        },
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
              ),
            if (t.isHouseholdTask &&
                (t.assignedToId == null || t.assignedToId!.isEmpty))
              ElevatedButton(
                onPressed: () async {
                  // Assign to the real current user when possible
                  fb.User? user = widget.currentUser;
                  if (user == null) {
                    try {
                      user = fb.FirebaseAuth.instance.currentUser;
                    } catch (_) {
                      user = null;
                    }
                  }
                  final userId = user?.uid ?? 'currentUserId';
                  final userName = user?.displayName ?? user?.email ?? 'You';
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

  Future<bool?> _showAddDialog(BuildContext context, [Task? taskToEdit]) async {
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

    final result = await showDialog<bool>(
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
                  onPressed: () => Navigator.pop(dialogContext, false),
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
                          Navigator.pop(dialogContext, true);
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
    return result;
  }
}
