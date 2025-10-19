import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';
import 'package:housekeepr/models/task.dart';
// removed unused import

import '../test_utils.dart';

void main() {
  test('TaskRepository recovers recoverable malformed JSON', () async {
    final prefs = InMemoryPrefs();

    // Build a malformed-but-recoverable task JSON: numeric id/title, string priority, string completed
    final badTaskMap = {
      'id': 123,
      'title': 456,
      'description': null,
      'priority': '2',
      'completed': 'true',
      'subTasks': [
        {'id': 1, 'title': 2, 'completed': 1},
      ],
    };

    // also include a completely invalid entry to ensure it's skipped
    final raw = [json.encode(badTaskMap), 'not a json', '[]'];
    await prefs.setStringList('tasks_v1', raw);

    final repo = TaskRepository(prefs);
    final items = repo.loadTasks();
    expect(items.length, 1);
    final t = items.first;
    expect(t.id, '123');
    expect(t.title, '456');
    expect(t.priority, TaskPriority.values[2]);
    expect(t.completed, isTrue);
    expect(t.subTasks.length, 1);
    expect(t.subTasks.first.id, '1');
  });

  test('ShoppingRepository recovers recoverable malformed JSON', () async {
    final prefs = InMemoryPrefs();

    final badItemMap = {'id': 999, 'name': 100, 'quantity': '3', 'inCart': '1'};

    final raw = [json.encode(badItemMap), 'nope'];
    await prefs.setStringList('shopping_v1', raw);

    final repo = ShoppingRepository(prefs);
    final items = repo.loadItems();
    expect(items.length, 1);
    final it = items.first;
    expect(it.id, '999');
    expect(it.name, '100');
    expect(it.quantity, 3);
    expect(it.inCart, isTrue);
  });
}
