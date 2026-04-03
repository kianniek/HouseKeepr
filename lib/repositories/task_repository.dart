import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

import '../models/task.dart';
import '../services/recurrence_generator.dart';

class TaskRepository {
  final SharedPreferences prefs;
  final _uuid = const Uuid();

  TaskRepository(this.prefs);

  static const _kLegacyKey = 'tasks_v1';

  /// Migrate legacy SharedPreferences storage (string-list JSON) into Hive.
  Future<void> _migrateFromPrefsIfNeeded() async {
    try {
      if (prefs.getStringList(_kLegacyKey) != null) {
        final raw = prefs.getStringList(_kLegacyKey) ?? <String>[];
        if (raw.isNotEmpty) {
          final box = _box;
          final meta = _meta;
          final ids = <String>[];
          for (final s in raw) {
            try {
              final decoded = json.decode(s);
              if (decoded is Map) {
                final map = Map<String, dynamic>.from(decoded);
                final t = Task.fromMap(map);
                if (t.id.isNotEmpty) {
                  await box.put(t.id, t.toMap());
                  ids.add(t.id);
                }
              }
            } catch (_) {}
          }
          if (ids.isNotEmpty) await meta.put('order', ids);
        }
        await prefs.remove(_kLegacyKey);
      }
    } catch (_) {}
  }

  Box get _box => Hive.box('tasks');
  Box get _meta => Hive.box('tasks_meta');

  List<Task> loadTasks() {
    // If legacy SharedPreferences storage exists, parse and return it
    // synchronously so callers (tests) get the expected items immediately.
    if (prefs.getStringList(_kLegacyKey) != null) {
      final raw = prefs.getStringList(_kLegacyKey) ?? <String>[];
      final parsed = <Task>[];
      for (final s in raw) {
        try {
          final decoded = json.decode(s);
          if (decoded is Map) {
            parsed.add(Task.fromMap(Map<String, dynamic>.from(decoded)));
          }
        } catch (_) {}
      }
      // Kick off background migration to Hive
      Future.microtask(() => _migrateFromPrefsIfNeeded());
      return parsed;
    }

    final order = _meta.get('order') as List<dynamic>?;
    final out = <Task>[];
    if (order != null && order.isNotEmpty) {
      for (final id in order.whereType<String>()) {
        final raw = _box.get(id);
        if (raw == null) continue;
        try {
          out.add(Task.fromMap(Map<String, dynamic>.from(raw)));
        } catch (_) {}
      }
    } else {
      for (final raw in _box.values) {
        try {
          out.add(Task.fromMap(Map<String, dynamic>.from(raw)));
        } catch (_) {}
      }
    }
    return out;
  }

  List<Task> loadTasksPage({
    int offset = 0,
    int limit = 20,
    bool includeArchived = false,
  }) {
    final all = loadTasks();
    final filtered = includeArchived
        ? all
        : all.where((t) => t.archived == false).toList();
    if (offset >= filtered.length) return <Task>[];
    final end = (offset + limit) < filtered.length
        ? (offset + limit)
        : filtered.length;
    return filtered.sublist(offset, end);
  }

  Future<void> saveTasks(List<Task> tasks) async {
    // 1. Persist the tasks themselves
    // Write incoming tasks and remove any stale tasks that are no longer
    // present in the provided list. This keeps the local store in sync
    // with the authoritative set (useful when replaceAll/save is used
    // after fetching server snapshots).
    final incomingIds = tasks.map((t) => t.id).toSet();

    // Remove entries that are not in the incoming set.
    final existingKeys = _box.keys.cast<String>().toList();
    for (final k in existingKeys) {
      if (!incomingIds.contains(k)) {
        await _box.delete(k);
      }
    }

    // Put/update incoming tasks
    for (final t in tasks) {
      await _box.put(t.id, t.toMap());
    }

    // 2. Update the stored order to match exactly the incoming tasks' ids.
    // This avoids resurrecting deleted tasks by merging old ids back.
    final orderedIds = tasks.map((t) => t.id).toList();
    await _meta.put('order', orderedIds);
  }

  Future<void> materializeOccurrences({
    required DateTime from,
    required DateTime to,
    int interval = 1,
  }) async {
    // No longer generating synthetic task occurrences.
    // Repeating tasks are now shown/hidden based on their repeat schedule,
    // and completion is tracked via completedDates array.
    return;
  }

  Future<Task> createTask({required String title, String? description}) async {
    final task = Task(id: _uuid.v4(), title: title, description: description);
    await _box.put(task.id, task.toMap());
    final order =
        (_meta.get('order') as List<dynamic>?)?.whereType<String>().toList() ??
        <String>[];
    order.add(task.id);
    await _meta.put('order', order);
    return task;
  }

  Future<void> createTaskObject(Task task) async {
    await _box.put(task.id, task.toMap());
    final order =
        (_meta.get('order') as List<dynamic>?)?.whereType<String>().toList() ??
        <String>[];
    order.add(task.id);
    await _meta.put('order', order);
  }

  Future<void> updateTask(Task task) async {
    if (_box.containsKey(task.id)) {
      await _box.put(task.id, task.toMap());
    }
  }

  Future<void> deleteTask(String id) async {
    await _box.delete(id);
    final order =
        (_meta.get('order') as List<dynamic>?)?.whereType<String>().toList() ??
        <String>[];
    order.removeWhere((s) => s == id);
    await _meta.put('order', order);
  }
}
