import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';
import 'test_utils.dart';

void main() {
  test('TaskRepository CRUD operations', () async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);

    // initially empty
    expect(repo.loadTasks(), isEmpty);

    final task = await repo.createTask(title: 'Test');
    final list = repo.loadTasks();
    expect(list.length, equals(1));
    expect(list.first.title, equals('Test'));

    final updated = task.copyWith(title: 'Updated');
    await repo.updateTask(updated);
    final afterUpdate = repo.loadTasks();
    expect(afterUpdate.first.title, equals('Updated'));

    await repo.deleteTask(updated.id);
    expect(repo.loadTasks(), isEmpty);
  });

  test('ShoppingRepository CRUD operations', () async {
    final prefs = InMemoryPrefs();
    final repo = ShoppingRepository(prefs);

    expect(repo.loadItems(), isEmpty);

    final item = await repo.createItem(name: 'Milk', quantity: 2);
    expect(repo.loadItems().length, equals(1));
    expect(repo.loadItems().first.name, equals('Milk'));

    final updated = item.copyWith(name: 'Skim milk');
    await repo.updateItem(updated);
    expect(repo.loadItems().first.name, equals('Skim milk'));

    await repo.deleteItem(updated.id);
    expect(repo.loadItems(), isEmpty);
  });
}
