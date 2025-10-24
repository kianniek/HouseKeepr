import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../models/home.dart';
import '../models/task.dart';
import '../cubits/task_cubit.dart';
import '../cubits/shopping_cubit.dart';
import '../firestore/firestore_home_repository.dart';
import 'profile_menu.dart';
import 'household_dashboard_page.dart' show TaskListTile, ShoppingAddRow;
import 'tasks_page.dart';
import 'task_add_dialog.dart';

class HomeScreen extends StatefulWidget {
  final fb.User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bottomNavIndex = 0; // 0 = Home, 1 = Tasks, 2 = Shopping
  int _feedIndex = 0; // 0 = For You, 1 = Everyone

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_bottomNavIndex == 0) {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 16.0,
            ),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('For You'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Everyone'),
                  icon: Icon(Icons.people),
                ),
              ],
              selected: <int>{_feedIndex},
              onSelectionChanged: (s) {
                setState(() => _feedIndex = s.first);
              },
              showSelectedIcon: false,
            ),
          ),
          Expanded(
            child: _feedIndex == 0
                ? ForYouFeed(user: widget.user)
                : EveryoneFeed(user: widget.user),
          ),
        ],
      );
    } else if (_bottomNavIndex == 1) {
      // Tasks tab: use the TasksPage with FAB/modal and pass current user
      body = TasksPage(currentUser: widget.user);
    } else {
      // Shopping tab: use the Shopping tab widget from HouseholdDashboardPage
      body = Padding(padding: const EdgeInsets.all(16.0), child: ShoppingTab());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [ProfileMenu(user: widget.user)],
      ),
      body: body,
      floatingActionButton: _bottomNavIndex == 1
          ? FloatingActionButton(
              onPressed: () => showTaskAddEditDialog(
                context,
                householdId: null,
                currentUser: widget.user,
              ),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomNavIndex,
        onDestinationSelected: (idx) => setState(() => _bottomNavIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Shopping',
          ),
        ],
      ),
    );
  }
}

// Extracted from HouseholdDashboardPage for reuse
class TasksTab extends StatelessWidget {
  const TasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuse the logic from HouseholdDashboardPage
    final TextEditingController taskController = TextEditingController();
    Future<void> addTask() async {
      final text = taskController.text.trim();
      if (text.isEmpty) return;
      final id = const Uuid().v4();
      final task = Task(id: id, title: text);
      context.read<TaskCubit>().addTask(task);
      taskController.clear();
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: taskController,
                decoration: const InputDecoration(labelText: 'Add new task'),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: taskController,
              builder: (context, value, child) {
                final canAdd = value.text.trim().isNotEmpty;
                return ElevatedButton(
                  onPressed: canAdd ? addTask : null,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
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
                                    snap.data!.data() as Map<String, dynamic>?;
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
    );
  }
}

class ShoppingTab extends StatelessWidget {
  const ShoppingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
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
                      subtitle: it.category != null ? Text(it.category!) : null,
                      leading: Checkbox(
                        value: it.inCart,
                        onChanged: (v) => context
                            .read<ShoppingCubit>()
                            .updateItem(it.copyWith(inCart: v ?? false)),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () =>
                            context.read<ShoppingCubit>().deleteItem(it.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ForYouFeed extends StatelessWidget {
  final fb.User user;
  const ForYouFeed({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final repo = FirestoreHomeRepository(FirebaseFirestore.instance);
    return StreamBuilder<Home?>(
      stream: repo.userHome(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final home = snapshot.data;
        if (home == null) {
          return const Center(child: Text('You are not a member of any home.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                title: Text('Welcome to ${home.name}!'),
                subtitle: Text('Members: ${home.members.length}'),
              ),
            ),
            // Add more personalized cards here (e.g., recent activity, tasks, etc.)
          ],
        );
      },
    );
  }
}

class EveryoneFeed extends StatelessWidget {
  final fb.User user;
  const EveryoneFeed({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final repo = FirestoreHomeRepository(FirebaseFirestore.instance);
    return StreamBuilder<List<Home>>(
      stream: repo.allHomes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final homes = snapshot.data ?? [];
        if (homes.isEmpty) {
          return const Center(child: Text('No homes found.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: homes.length,
          itemBuilder: (context, idx) {
            final home = homes[idx];
            return Card(
              child: ListTile(
                title: Text(home.name),
                subtitle: Text('Members: ${home.members.length}'),
              ),
            );
          },
        );
      },
    );
  }
}
