import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../cubits/task_cubit.dart';
import '../cubits/shopping_cubit.dart';
import '../models/task.dart';
import '../models/shopping_item.dart';
import 'profile_menu.dart';

class TaskListTile extends StatelessWidget {
  final Task task;
  final Color? tileColor;
  const TaskListTile({required this.task, this.tileColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: tileColor?.withOpacity(0.18),
      title: Text(task.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.assignedToName != null)
            Text('Assigned to: ${task.assignedToName}'),
          if (task.description != null) Text(task.description!),
        ],
      ),
      trailing: Checkbox(
        value: task.completed,
        onChanged: (val) => context.read<TaskCubit>().updateTask(
          task.copyWith(completed: val ?? false),
        ),
      ),
    );
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _taskController.dispose();
    _tabController.dispose();
    super.dispose();
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
        actions: const [ProfileMenu()],
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
                        itemCount: tasks.length,
                        itemBuilder: (context, idx) {
                          final t = tasks[idx];
                          return Dismissible(
                            key: ValueKey(t.id),
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
  const ShoppingAddRow();

  @override
  State<ShoppingAddRow> createState() => ShoppingAddRowState();
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
