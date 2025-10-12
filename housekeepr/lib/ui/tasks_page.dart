import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/task_cubit.dart';
import '../models/task.dart';
import 'package:uuid/uuid.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        return Scaffold(
          body: state.tasks.isEmpty
              ? const Center(child: Text('No tasks yet'))
              : ListView.builder(
                  itemCount: state.tasks.length,
                  itemBuilder: (context, idx) {
                    final t = state.tasks[idx];
                    return ListTile(
                      title: Text(t.title),
                      subtitle: t.description != null
                          ? Text(t.description!)
                          : null,
                      leading: Checkbox(
                        value: t.completed,
                        onChanged: (v) {
                          context.read<TaskCubit>().updateTask(
                            t.copyWith(completed: v ?? false),
                          );
                        },
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () =>
                            context.read<TaskCubit>().deleteTask(t.id),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descCtl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final id = const Uuid().v4();
                final task = Task(
                  id: id,
                  title: titleCtl.text,
                  description: descCtl.text.isEmpty ? null : descCtl.text,
                );
                // Use the outer `context` (the widget's context) so the
                // BlocProvider<TaskCubit> is found. The dialog builder's
                // parameter is `dialogContext` which does not necessarily
                // include the providers from the original widget tree.
                context.read<TaskCubit>().addTask(task);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
