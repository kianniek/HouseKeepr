import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';

import '../test_utils.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/models/shopping_item.dart';

void main() {
  test('TaskRepository skips malformed JSON in prefs', () async {
    final prefs = InMemoryPrefs();
    // insert one valid and two malformed entries
    await prefs.setStringList('tasks_v1', [
      Task(id: 'a', title: 'A').toJson(),
      '{bad json',
      '[]',
    ]);

    final repo = TaskRepository(prefs);
    final list = repo.loadTasks();
    expect(list.length, 1);
    expect(list.first.id, 'a');
  });

  test('ShoppingRepository skips malformed JSON in prefs', () async {
    final prefs = InMemoryPrefs();
    await prefs.setStringList('shopping_v1', [
      ShoppingItem(id: 's1', name: 'One').toJson(),
      'not json',
      '{"id": "s2"}', // missing required fields (name) may throw
    ]);

    final repo = ShoppingRepository(prefs);
    final items = repo.loadItems();
    expect(items.length, 1);
    expect(items.first.id, 's1');
  });
}
