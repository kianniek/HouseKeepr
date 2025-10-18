import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';

import '../test_utils.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/models/shopping_item.dart';

void main() {
  test('TaskRepository update/delete no-op when id missing', () async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);

    final t = await repo.createTask(title: 'One');
    expect(repo.loadTasks().length, 1);

    // attempt to update a non-existent id
    await repo.updateTask(Task(id: 'nope', title: 'X'));
    expect(repo.loadTasks().length, 1);
    expect(repo.loadTasks().first.id, t.id);

    // attempt to delete a non-existent id
    await repo.deleteTask('missing');
    expect(repo.loadTasks().length, 1);
  });

  test('ShoppingRepository update/delete no-op when id missing', () async {
    final prefs = InMemoryPrefs();
    final repo = ShoppingRepository(prefs);

    final s = await repo.createItem(name: 'Eggs');
    expect(repo.loadItems().length, 1);

    await repo.updateItem(ShoppingItem(id: 'nope', name: 'X'));
    expect(repo.loadItems().length, 1);
    expect(repo.loadItems().first.id, s.id);

    await repo.deleteItem('missing');
    expect(repo.loadItems().length, 1);
  });
}
