import 'package:flutter/material.dart';
// cloud_firestore is used inside MemberPicker; tasks_page no longer needs a direct import.
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/task_cubit.dart';
import '../models/task.dart';
import 'member_picker.dart';
import 'package:uuid/uuid.dart';

class TasksPage extends StatelessWidget {
  final String? householdId;
  const TasksPage({super.key, this.householdId});

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
                      subtitle:
                          (t.assignedToName != null || t.description != null)
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (t.assignedToName != null)
                                  Text('Assigned to: ${t.assignedToName}'),
                                if (t.description != null) Text(t.description!),
                              ],
                            )
                          : null,
                      isThreeLine:
                          t.assignedToName != null && t.description != null,
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
    String? selectedMemberId;
    String? selectedMemberName;
    // Use StatefulBuilder so the dialog can update button enabled state
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool canAdd() => titleCtl.text.trim().isNotEmpty;
        return StatefulBuilder(
          builder: (contextSB, setStateSB) {
            titleCtl.addListener(() => setStateSB(() {}));
            return AlertDialog(
              title: const Text('New Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  if (householdId == null) ...[
                    // fallback to free-text if householdId not provided
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Assigned to (optional)',
                      ),
                      onChanged: (v) => selectedMemberName = v.trim().isEmpty
                          ? null
                          : v.trim(),
                    ),
                  ] else ...[
                    MemberPicker(
                      householdId: householdId!,
                      onChanged: (id, display) {
                        selectedMemberId = id;
                        selectedMemberName = display;
                      },
                    ),
                  ],
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
                  onPressed: canAdd()
                      ? () {
                          final id = const Uuid().v4();
                          final task = Task(
                            id: id,
                            title: titleCtl.text.trim(),
                            description: descCtl.text.isEmpty
                                ? null
                                : descCtl.text,
                            assignedToId: selectedMemberId,
                            assignedToName: selectedMemberName,
                          );
                          // Use the outer `context` so the BlocProvider<TaskCubit is found.
                          context.read<TaskCubit>().addTask(task);
                          Navigator.pop(context);
                        }
                      : null,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
