import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';

class TaskRepository {
  static const _kTasksKey = 'tasks_v1';
  final SharedPreferences prefs;
  final _uuid = const Uuid();

  TaskRepository(this.prefs);

  List<Task> loadTasks() {
    final raw = prefs.getStringList(_kTasksKey) ?? [];
    final List<Task> out = [];
    for (final e in raw) {
      try {
        final t = Task.fromJson(e);
        if (t.id.isNotEmpty && t.title.isNotEmpty) out.add(t);
      } catch (_) {
        // skip malformed entry
      }
    }
    return out;
  }

  Future<void> saveTasks(List<Task> tasks) async {
    final raw = tasks.map((t) => t.toJson()).toList();
    await prefs.setStringList(_kTasksKey, raw);
  }

  Future<Task> createTask({required String title, String? description}) async {
    final tasks = loadTasks();
    final task = Task(id: _uuid.v4(), title: title, description: description);
    tasks.add(task);
    await saveTasks(tasks);
    return task;
  }

  Future<void> updateTask(Task task) async {
    final tasks = loadTasks();
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      tasks[idx] = task;
      await saveTasks(tasks);
    }
  }

  Future<void> deleteTask(String id) async {
    final tasks = loadTasks();
    tasks.removeWhere((t) => t.id == id);
    await saveTasks(tasks);
  }
}
