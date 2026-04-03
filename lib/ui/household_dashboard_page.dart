import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../cubits/task_cubit.dart';
import '../cubits/shopping_cubit.dart';
import '../models/task.dart';
import '../models/shopping_item.dart';
import '../models/completion_record.dart';
import 'profile_menu.dart';
import 'assignee_dropdown.dart';

class TaskListTile extends StatefulWidget {
  final Task task;
  final Color? tileColor;
  // Optional override for the assignee display name when the caller
  // has already resolved the user document (avoids extra fetches).
  final String? assignedToDisplayName;
  // Optional callback invoked when the task is marked completed via the UI.
  final VoidCallback? onCompleted;
  const TaskListTile({
    super.key,
    required this.task,
    this.tileColor,
    this.assignedToDisplayName,
    this.onCompleted,
  });

  @override
  State<TaskListTile> createState() => _TaskListTileState();
}

class _TaskListTileState extends State<TaskListTile> {
  bool _retrying = false;
  late final FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.space) {
            context.read<TaskCubit>().updateTask(
              task.copyWith(completed: !task.completed),
            );
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.keyH) {
            showDialog<void>(
              context: context,
              builder: (ctx) => TaskHistoryDialog(taskId: task.id),
            );
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.delete) {
            context.read<TaskCubit>().deleteTask(task.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deleted "${task.title}"'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => context.read<TaskCubit>().addTask(task),
                ),
              ),
            );
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        label:
            '${task.title}, ${task.completed ? 'completed' : 'not completed'}, ${task.syncStatus.name}',
        button: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focusNode.requestFocus(),
          child: ListTile(
            selected: _focusNode.hasFocus,
            tileColor: widget.tileColor?.withAlpha((0.18 * 255).round()),
            title: Row(
              children: [
                Expanded(child: Text(task.title)),
                // small sync status badge (pass lastSyncError so badge can show details)
                _SyncBadge(status: task.syncStatus, error: task.lastSyncError),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show 'Household' when this is a household task. Otherwise
                // prefer an explicit resolved display name passed in by the
                // caller, then the task's stored `assignedToName`, then
                // fall back to the raw id if nothing else is available.
                if (task.isHouseholdTask || task.assignedToId == null)
                  const Text('Assigned to: Household')
                else
                  Text(
                    'Assigned to: ${widget.assignedToDisplayName ?? task.assignedToName ?? task.assignedToId ?? ''}',
                  ),
                if (task.description != null) Text(task.description!),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: task.completed,
                  onChanged: (val) {
                    final completed = val ?? false;
                    context.read<TaskCubit>().updateTask(
                      task.copyWith(completed: completed),
                    );
                    if (completed) widget.onCompleted?.call();
                  },
                ),
                Semantics(
                  label: 'Open task history',
                  button: true,
                  child: IconButton(
                    tooltip: 'History',
                    icon: const Icon(Icons.history),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => TaskHistoryDialog(taskId: task.id),
                      );
                    },
                  ),
                ),
                if (task.syncStatus == SyncStatus.failed)
                  _retrying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Retry sync',
                          onPressed: () async {
                            setState(() => _retrying = true);
                            // Capture messenger before awaiting to avoid using BuildContext
                            // across async gaps (analyzer: use_build_context_synchronously).
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await context
                                .read<TaskCubit>()
                                .retryTask(task.id);
                            if (!mounted) return;
                            setState(() => _retrying = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Retry started'
                                      : 'Retry failed to start',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A keyboard-focusable selection-mode row used when the list is in selection mode.
class SelectionTaskRow extends StatefulWidget {
  final Task task;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onCancelSelection;
  final FocusNode? focusNode;

  const SelectionTaskRow({
    super.key,
    required this.task,
    required this.selected,
    required this.onToggle,
    required this.onCancelSelection,
    this.focusNode,
  });

  @override
  State<SelectionTaskRow> createState() => _SelectionTaskRowState();
}

class _SelectionTaskRowState extends State<SelectionTaskRow> {
  late final FocusNode _focusNode;
  late final bool _ownedFocusNode;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      _ownedFocusNode = false;
    } else {
      _focusNode = FocusNode(debugLabel: 'selection-${widget.task.id}');
      _ownedFocusNode = true;
    }
  }

  @override
  void dispose() {
    if (_ownedFocusNode) _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.space ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter) {
        widget.onToggle();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.escape) {
        widget.onCancelSelection();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Semantics(
        selected: widget.selected,
        button: true,
        label: '${t.title}, selectable',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focusNode.requestFocus(),
          child: ListTile(
            selected: _focusNode.hasFocus,
            leading: Checkbox(
              value: widget.selected,
              onChanged: (_) => widget.onToggle(),
            ),
            title: Text(t.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (t.isHouseholdTask || t.assignedToId == null)
                  const Text('Assigned to: Household')
                else
                  Text(
                    'Assigned to: ${t.assignedToName ?? t.assignedToId ?? ''}',
                  ),
                if (t.description != null) Text(t.description!),
              ],
            ),
            onTap: () => widget.onToggle(),
            onLongPress: () => widget.onToggle(),
          ),
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  final SyncStatus status;
  final String? error;
  const _SyncBadge({required this.status, this.error});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case SyncStatus.pending:
        color = scheme.tertiary;
        icon = Icons.hourglass_top;
        label = 'Pending sync';
        break;
      case SyncStatus.syncing:
        color = scheme.primary;
        icon = Icons.sync;
        label = 'Syncing';
        break;
      case SyncStatus.failed:
        color = scheme.error;
        icon = Icons.error;
        label = 'Sync failed';
        break;
      case SyncStatus.synced:
        color = scheme.secondary;
        icon = Icons.check_circle;
        label = 'Synced';
        break;
    }
    final badge = Semantics(
      label: label,
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Icon(icon, size: 16, color: color),
      ),
    );

    if (status == SyncStatus.failed && (error != null && error!.isNotEmpty)) {
      return InkWell(
        onTap: () {
          final msg = error ?? 'Unknown sync error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
          );
        },
        child: Tooltip(message: error, child: badge),
      );
    }
    return badge;
  }
}

class HouseholdDashboardPage extends StatefulWidget {
  final String householdId;
  final fb.User user;
  const HouseholdDashboardPage({
    super.key,
    required this.householdId,
    required this.user,
  });

  @override
  State<HouseholdDashboardPage> createState() => _HouseholdDashboardPageState();
}

class _HouseholdDashboardPageState extends State<HouseholdDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _taskController = TextEditingController();
  final ScrollController _tasksScrollController = ScrollController();
  // ADD THESE TWO CONTROLLERS TO ALLOW programmatic expansion
  final ExpansibleController _tasksController = ExpansibleController();
  final ExpansibleController _shoppingController = ExpansibleController();
  String? _selectedAssigneeValue = 'household';
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tasksScrollController.addListener(_onScrollTasks);
  }

  @override
  void dispose() {
    _taskController.dispose();
    _tasksScrollController.removeListener(_onScrollTasks);
    _tasksScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScrollTasks() {
    final max = _tasksScrollController.position.maxScrollExtent;
    final pos = _tasksScrollController.position.pixels;
    // When within 200px of the bottom, attempt to load more if available
    if (pos >= (max - 200)) {
      _maybeLoadMore();
    }
  }

  Future<void> _maybeLoadMore() async {
    if (_loadingMore) return;
    final cubit = context.read<TaskCubit>();
    final state = cubit.state;
    if (!state.hasMore) return;
    _loadingMore = true;
    try {
      await cubit.loadMore();
    } catch (_) {}
    _loadingMore = false;
  }

  // Selection mode for bulk actions
  final Set<String> _selectedIds = <String>{};

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  bool _tasksCompletedExpanded = false;
  final GlobalKey<AnimatedListState> _completedTasksListKey =
      GlobalKey<AnimatedListState>();
  final List<Task> _completedTasksCache = [];
  bool _shoppingCompletedExpanded = false;

  void _syncCompletedTasks(List<Task> newList) {
    try {
      final old = _completedTasksCache;
      final newIds = newList.map((t) => t.id).toList();

      // Removals (iterate backwards)
      for (int i = old.length - 1; i >= 0; i--) {
        final id = old[i].id;
        if (!newIds.contains(id)) {
          final removed = old.removeAt(i);
          _completedTasksListKey.currentState?.removeItem(
            i,
            (ctx, anim) => _buildCompletedAnimatedItem(removed, anim),
            duration: const Duration(milliseconds: 240),
          );
        }
      }

      // Inserts / moves
      for (int i = 0; i < newList.length; i++) {
        final id = newList[i].id;
        final existingIndex = old.indexWhere((t) => t.id == id);
        if (existingIndex == -1) {
          // insert
          _completedTasksCache.insert(i, newList[i]);
          _completedTasksListKey.currentState?.insertItem(
            i,
            duration: const Duration(milliseconds: 180),
          );
        } else if (existingIndex != i) {
          // move: remove then insert
          final removed = old.removeAt(existingIndex);
          _completedTasksListKey.currentState?.removeItem(
            existingIndex,
            (ctx, anim) => _buildCompletedAnimatedItem(removed, anim),
            duration: const Duration(milliseconds: 160),
          );
          _completedTasksCache.insert(i, removed);
          _completedTasksListKey.currentState?.insertItem(
            i,
            duration: const Duration(milliseconds: 160),
          );
        }
      }
    } catch (_) {}
  }

  Widget _buildCompletedAnimatedItem(Task t, Animation<double> anim) {
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
        child: Dismissible(
          key: ValueKey(t.id),
          direction: t.isRetrying
              ? DismissDirection.none
              : DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
          onDismissed: (_) {
            context.read<TaskCubit>().deleteTask(t.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deleted "${t.title}"'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => context.read<TaskCubit>().addTask(t),
                ),
              ),
            );
          },
          child: TaskListTile(task: t),
        ),
      ),
    );
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  Future<void> _confirmAndDeleteSelected() async {
    // Capture context-derived values before any `await` to avoid
    // using the BuildContext across async gaps (fixes lint).
    final cubit = context.read<TaskCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final selected = cubit.state.tasks
        .where((t) => _selectedIds.contains(t.id))
        .toList();
    if (selected.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected tasks?'),
        content: Text(
          'This will delete ${selected.length} tasks. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final prevMaps = selected.map((t) => t.toMap()).toList();
    final ids = selected.map((t) => t.id).toList();

    await cubit.bulkDelete(ids);
    _clearSelection();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${ids.length} tasks'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            for (final m in prevMaps) {
              cubit.restoreTaskFromMap(m);
            }
          },
        ),
      ),
    );
  }

  Future<void> _archiveSelected() async {
    final cubit = context.read<TaskCubit>();
    final selected = cubit.state.tasks
        .where((t) => _selectedIds.contains(t.id))
        .toList();
    if (selected.isEmpty) return;
    final prevMaps = selected.map((t) => t.toMap()).toList();
    final ids = selected.map((t) => t.id).toList();
    final messenger = ScaffoldMessenger.of(context);
    await cubit.bulkArchive(ids);
    _clearSelection();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Archived ${ids.length} tasks'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            for (final m in prevMaps) {
              cubit.restoreTaskFromMap(m);
            }
          },
        ),
      ),
    );
  }

  Future<void> _addTask() async {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;
    final assignee = _selectedAssigneeValue ?? 'household';
    final assignedToId = assignee == 'household' ? null : assignee;
    final task = Task(
      id: Uuid().v4(),
      title: text,
      householdId: widget.householdId,
      assignedToId: assignedToId,
      isHouseholdTask: assignedToId == null,
    );
    context.read<TaskCubit>().addTask(task);
    _taskController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Household'),
        actions: _isSelectionMode
            ? [
                IconButton(
                  tooltip: 'Archive selected',
                  icon: const Icon(Icons.archive),
                  onPressed: _archiveSelected,
                ),
                IconButton(
                  tooltip: 'Delete selected',
                  icon: const Icon(Icons.delete),
                  onPressed: _confirmAndDeleteSelected,
                ),
                IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                ),
              ]
            : const [ProfileMenu()],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Tasks'),
            Tab(text: 'Shopping'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Members:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Authoritative source: households document contains the
                  // members array. Stream the household doc and show member
                  // display names by fetching each user doc by id. This avoids
                  // relying on the denormalized users/{uid}.householdId field.
                  StreamBuilder<DocumentSnapshot>(
                    stream: (() {
                      final ref = FirebaseFirestore.instance
                          .collection('households')
                          .doc(widget.householdId);
                      debugPrint('household_dashboard household ref: $ref');
                      return ref.snapshots().handleError(
                        (e, st) => debugPrint(
                          'household_dashboard household stream error: $e',
                        ),
                      );
                    })(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        debugPrint(
                          'household_dashboard household snapshot error: ${snap.error}',
                        );
                        return const Text('Error loading members');
                      }
                      if (!snap.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final data = snap.data!.data() as Map<String, dynamic>?;
                      final members = (data == null)
                          ? <String>[]
                          : ((data['members'] as List<dynamic>?)
                                    ?.map((e) => e?.toString() ?? '')
                                    .where((s) => s.isNotEmpty)
                                    .toList() ??
                                <String>[]);
                      if (members.isEmpty) return const Text('No members');
                      // Resolve all member user docs in parallel and show their
                      // display names (falling back to email or uid). Using
                      // Future.wait keeps the original members ordering and
                      // avoids briefly rendering the raw UID as a placeholder.
                      try {
                        debugPrint(
                          'household_dashboard: fetching ${members.length} user docs',
                        );
                      } catch (_) {}
                      return FutureBuilder<List<DocumentSnapshot>>(
                        future: Future.wait(
                          members.map(
                            (uid) => FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .get(),
                          ),
                        ),
                        builder: (context, usersSnap) {
                          if (usersSnap.hasError) {
                            debugPrint(
                              'household_dashboard user docs error: ${usersSnap.error}',
                            );
                          }
                          if (!usersSnap.hasData) {
                            return const CircularProgressIndicator();
                          }
                          final userDocs = usersSnap.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(members.length, (i) {
                              final uid = members[i];
                              final doc = userDocs.length > i
                                  ? userDocs[i]
                                  : null;
                              final udata =
                                  doc?.data() as Map<String, dynamic>?;
                              final display = udata == null
                                  ? uid
                                  : (udata['displayName'] ??
                                        udata['email'] ??
                                        uid);
                              return Text(display);
                            }),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Tasks tab
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taskController,
                        decoration: const InputDecoration(
                          labelText: 'Add new task',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 220,
                      child: AssigneeDropdown(
                        householdId: widget.householdId,
                        value: _selectedAssigneeValue ?? 'household',
                        onChanged: (v) =>
                            setState(() => _selectedAssigneeValue = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Retry all failed tasks',
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        final cubit = context.read<TaskCubit>();
                        final failedCount = cubit.state.tasks
                            .where((t) => t.syncStatus == SyncStatus.failed)
                            .length;
                        final messenger = ScaffoldMessenger.of(context);
                        if (failedCount == 0) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('No failed tasks to retry'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Retrying $failedCount failed tasks'),
                          ),
                        );
                        final succeeded = await cubit.retryAllFailed();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Retried $succeeded of $failedCount tasks',
                            ),
                          ),
                        );
                      },
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _taskController,
                      builder: (context, value, child) {
                        final canAdd =
                            value.text.trim().isNotEmpty &&
                            (_selectedAssigneeValue != null &&
                                _selectedAssigneeValue!.isNotEmpty);
                        return ElevatedButton(
                          onPressed: canAdd ? _addTask : null,
                          child: const Text('Add'),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: BlocBuilder<TaskCubit, TaskState>(
                    builder: (context, state) {
                      final tasks = state.tasks;
                      if (tasks.isEmpty) return const Text('No tasks yet.');

                      final incomplete = tasks
                          .where((t) => !t.completed)
                          .toList();
                      final completed = tasks
                          .where((t) => t.completed)
                          .toList();

                      Widget buildTaskTile(Task t) {
                        if (_isSelectionMode) {
                          return SelectionTaskRow(
                            task: t,
                            selected: _selectedIds.contains(t.id),
                            onToggle: () => _toggleSelection(t.id),
                            onCancelSelection: _clearSelection,
                          );
                        }
                        final base = Dismissible(
                          key: ValueKey(t.id),
                          direction: t.isRetrying
                              ? DismissDirection.none
                              : DismissDirection.endToStart,
                          background: Container(
                            color: Theme.of(context).colorScheme.error,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(
                              Icons.delete,
                              color: Theme.of(context).colorScheme.onError,
                            ),
                          ),
                          onDismissed: (_) {
                            context.read<TaskCubit>().deleteTask(t.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Deleted "${t.title}"'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () {
                                    context.read<TaskCubit>().addTask(t);
                                  },
                                ),
                              ),
                            );
                          },
                          child: t.assignedToId == null
                              ? TaskListTile(
                                  task: t,
                                  onCompleted: () {
                                    setState(
                                      () => _tasksCompletedExpanded = true,
                                    );
                                    _tasksController.expand();
                                  },
                                )
                              : FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(t.assignedToId)
                                      .get(),
                                  builder: (context, snap) {
                                    Color? userColor;
                                    String? resolvedDisplayName;
                                    if (snap.hasData && snap.data != null) {
                                      final data =
                                          snap.data!.data()
                                              as Map<String, dynamic>?;
                                      if (data != null &&
                                          data['personalColor'] != null) {
                                        userColor = Color(
                                          data['personalColor'] as int,
                                        );
                                      }
                                      if (data != null) {
                                        resolvedDisplayName =
                                            data['displayName'] ??
                                            data['email'];
                                      }
                                    }
                                    final displayNameFallback =
                                        resolvedDisplayName ??
                                        t.assignedToName ??
                                        t.assignedToId;
                                    return TaskListTile(
                                      task: t,
                                      tileColor: userColor,
                                      assignedToDisplayName:
                                          displayNameFallback,
                                      onCompleted: () {
                                        setState(
                                          () => _tasksCompletedExpanded = true,
                                        );
                                        _tasksController.expand();
                                      },
                                    );
                                  },
                                ),
                        );
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) {
                            final offsetAnim =
                                Tween<Offset>(
                                      begin: const Offset(0, 0.04),
                                      end: Offset.zero,
                                    )
                                    .chain(CurveTween(curve: Curves.easeInOut))
                                    .animate(anim);
                            return SlideTransition(
                              position: offsetAnim,
                              child: FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(key: ValueKey(t.id), child: base),
                        );
                      }

                      final children = <Widget>[];
                      if (incomplete.isNotEmpty) {
                        children.add(
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              'Active (${incomplete.length})',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                        for (final t in incomplete) {
                          children.add(buildTaskTile(t));
                        }
                      }

                      if (completed.isNotEmpty) {
                        children.add(const SizedBox(height: 12));
                        children.add(const Divider());
                        // Ensure our cached list and AnimatedList are in sync after frame
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _syncCompletedTasks(completed),
                        );
                        children.add(
                          ExpansionTile(
                            controller: _tasksController,
                            leading: const Icon(Icons.check_circle_outline),
                            title: Text('Completed (${completed.length})'),
                            initiallyExpanded: _tasksCompletedExpanded,
                            onExpansionChanged: (v) =>
                                setState(() => _tasksCompletedExpanded = v),
                            children: [
                              SizedBox(
                                height: ((completed.length * 80).toDouble())
                                    .clamp(80.0, 400.0),
                                child: AnimatedList(
                                  key: _completedTasksListKey,
                                  initialItemCount: _completedTasksCache.length,
                                  itemBuilder: (ctx, idx, anim) =>
                                      _buildCompletedAnimatedItem(
                                        _completedTasksCache[idx],
                                        anim,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (state.hasMore) {
                        children.add(
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        );
                      }

                      return ListView(
                        controller: _tasksScrollController,
                        children: children,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Shopping tab
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const ShoppingAddRow(),
                const SizedBox(height: 12),
                Expanded(
                  child: BlocBuilder<ShoppingCubit, ShoppingState>(
                    builder: (context, state) {
                      final items = state.items;
                      if (items.isEmpty) return const Text('No shopping items');

                      final pending = items.where((i) => !i.inCart).toList();
                      final completed = items.where((i) => i.inCart).toList();

                      Widget buildItemRow(ShoppingItem it) {
                        return Dismissible(
                          key: ValueKey(it.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Theme.of(context).colorScheme.error,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(
                              Icons.delete,
                              color: Theme.of(context).colorScheme.onError,
                            ),
                          ),
                          onDismissed: (_) {
                            context.read<ShoppingCubit>().deleteItem(it.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Deleted "${it.name}"'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () {
                                    context.read<ShoppingCubit>().addItem(it);
                                  },
                                ),
                              ),
                            );
                          },
                          child: ListTile(
                            title: Text(it.name),
                            subtitle: it.category != null
                                ? Text(it.category!)
                                : null,
                            leading: Checkbox(
                              value: it.inCart,
                              onChanged: (v) {
                                final inCart = v ?? false;
                                context.read<ShoppingCubit>().updateItem(
                                  it.copyWith(inCart: inCart),
                                );
                                if (inCart) {
                                  setState(
                                    () => _shoppingCompletedExpanded = true,
                                  );
                                  _shoppingController.expand();
                                }
                              },
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => context
                                  .read<ShoppingCubit>()
                                  .deleteItem(it.id),
                            ),
                          ),
                        );
                      }

                      final children = <Widget>[];
                      for (final it in pending) {
                        children.add(buildItemRow(it));
                      }
                      if (completed.isNotEmpty) {
                        children.add(const SizedBox(height: 12));
                        children.add(
                          ExpansionTile(
                            controller: _shoppingController,
                            title: Text('Completed (${completed.length})'),
                            initiallyExpanded: _shoppingCompletedExpanded,
                            onExpansionChanged: (v) =>
                                setState(() => _shoppingCompletedExpanded = v),
                            children: completed.map(buildItemRow).toList(),
                          ),
                        );
                      }

                      return ListView(children: children);
                    },
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

class ShoppingAddRow extends StatefulWidget {
  const ShoppingAddRow({super.key});

  @override
  State<ShoppingAddRow> createState() => ShoppingAddRowState();
}

class TaskHistoryDialog extends StatefulWidget {
  final String taskId;
  const TaskHistoryDialog({super.key, required this.taskId});

  @override
  State<TaskHistoryDialog> createState() => _TaskHistoryDialogState();
}

class _TaskHistoryDialogState extends State<TaskHistoryDialog> {
  List<CompletionRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    try {
      final hr = context.read<TaskCubit>().historyRepo;
      if (hr == null) {
        setState(() {
          _records = [];
          _loading = false;
        });
        return;
      }
      final all = hr.loadAll();
      final filtered = all.where((r) => r.taskId == widget.taskId).toList();
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _records = filtered;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _records = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Task history'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_records.isEmpty
                  ? const Text('No history for this task')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _records.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final r = _records[idx];
                        return ListTile(
                          title: Text(r.date),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (r.completedBy != null)
                                Text('By: ${r.completedBy}'),
                              Text('Recorded: ${r.createdAt.toLocal()}'),
                            ],
                          ),
                        );
                      },
                    )),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class ShoppingAddRowState extends State<ShoppingAddRow> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _cat = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Item'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _cat,
            decoration: const InputDecoration(labelText: 'Category'),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (context, value, child) {
            final canAdd = value.text.trim().isNotEmpty;
            return ElevatedButton(
              onPressed: canAdd
                  ? () {
                      final name = _name.text.trim();
                      final cat = _cat.text.trim().isEmpty
                          ? null
                          : _cat.text.trim();
                      final id = const Uuid().v4();
                      final item = ShoppingItem(
                        id: id,
                        name: name,
                        category: cat,
                      );
                      context.read<ShoppingCubit>().addItem(item);
                      _name.clear();
                      _cat.clear();
                    }
                  : null,
              child: const Text('Add'),
            );
          },
        ),
      ],
    );
  }
}
