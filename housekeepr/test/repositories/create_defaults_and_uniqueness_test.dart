import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';

import '../test_utils.dart';

void main() {
  test('TaskRepository createTask uniqueness & defaults', () async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);

    final a = await repo.createTask(title: 'A');
    final b = await repo.createTask(title: 'B');
    expect(a.id, isNot(equals(b.id)));
    expect(a.title, 'A');
    expect(a.description, isNull);
  });

  test('ShoppingRepository createItem defaults', () async {
    final prefs = InMemoryPrefs();
    final repo = ShoppingRepository(prefs);

    final it = await repo.createItem(name: 'Milk');
    expect(it.quantity, 1);
    expect(it.inCart, isFalse);
  });
}
