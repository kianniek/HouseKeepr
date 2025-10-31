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

class TaskListTile extends StatefulWidget {
  final Task task;
  final Color? tileColor;
  const TaskListTile({super.key, required this.task, this.tileColor});

  @override
  State<TaskListTile> createState() => _TaskListTileState();
}

class _TaskListTileState extends State<TaskListTile> {
  bool _retrying = false;
  late final FocusNode _focusNode;
  @override
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
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
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
                if (task.assignedToName != null)
                  Text('Assigned to: ${task.assignedToName}'),
                if (task.description != null) Text(task.description!),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: task.completed,
                  onChanged: (val) => context.read<TaskCubit>().updateTask(
                    task.copyWith(completed: val ?? false),
                  ),
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

  KeyEventResult _handleKey(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
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
      onKey: _handleKey,
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
                if (t.assignedToName != null)
                  Text('Assigned to: ${t.assignedToName}'),
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
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case SyncStatus.pending:
        color = Colors.orange;
        icon = Icons.hourglass_top;
        label = 'Pending sync';
        break;
      case SyncStatus.syncing:
        color = Colors.blue;
        icon = Icons.sync;
        label = 'Syncing';
        break;
      case SyncStatus.failed:
        color = Theme.of(context).colorScheme.error;
        icon = Icons.error;
        label = 'Sync failed';
        break;
      case SyncStatus.synced:
        color = Colors.green;
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
      if (_selectedIds.contains(id))
        _selectedIds.remove(id);
      else
        _selectedIds.add(id);
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  Future<void> _confirmAndDeleteSelected() async {
    final cubit = context.read<TaskCubit>();
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
    ScaffoldMessenger.of(context).showSnackBar(
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
    await cubit.bulkArchive(ids);
    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
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
    final id = const Uuid().v4();
    final task = Task(id: id, title: text);
    // add via cubit so write-queue and sync flow are used
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
                  const Text(
                    'Members:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('householdId', isEqualTo: widget.householdId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final members = snapshot.data!.docs;
                      if (members.isEmpty) {
                        return const Text('No members');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: members.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Text(
                            data['displayName'] ?? data['email'] ?? doc.id,
                          );
                        }).toList(),
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
                        final canAdd = value.text.trim().isNotEmpty;
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
                      return ListView.builder(
                        controller: _tasksScrollController,
                        // show a loading indicator row when more pages are available
                        itemCount: tasks.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (context, idx) {
                          if (idx >= tasks.length) {
                            // loading indicator
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final t = tasks[idx];
                          if (_isSelectionMode) {
                            return SelectionTaskRow(
                              task: t,
                              selected: _selectedIds.contains(t.id),
                              onToggle: () => _toggleSelection(t.id),
                              onCancelSelection: _clearSelection,
                            );
                          }

                          return Dismissible(
                            key: ValueKey(t.id),
                            direction: t.isRetrying
                                ? DismissDirection.none
                                : DismissDirection.endToStart,
                            background: Container(
                              color: Theme.of(context).colorScheme.error,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
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
                                ? TaskListTile(task: t)
                                : FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(t.assignedToId)
                                        .get(),
                                    builder: (context, snap) {
                                      Color? userColor;
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
                                      }
                                      return TaskListTile(
                                        task: t,
                                        tileColor: userColor,
                                      );
                                    },
                                  ),
                          );
                        },
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
                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, idx) {
                          final it = items[idx];
                          return Dismissible(
                            key: ValueKey(it.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Theme.of(context).colorScheme.error,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
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
                                onChanged: (v) =>
                                    context.read<ShoppingCubit>().updateItem(
                                      it.copyWith(inCart: v ?? false),
                                    ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => context
                                    .read<ShoppingCubit>()
                                    .deleteItem(it.id),
                              ),
                            ),
                          );
                        },
                      );
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
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
