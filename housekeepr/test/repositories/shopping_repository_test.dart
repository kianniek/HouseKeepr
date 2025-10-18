import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';

import '../test_utils.dart';

void main() {
  test('ShoppingRepository CRUD operations', () async {
    final prefs = InMemoryPrefs();
    final repo = ShoppingRepository(prefs);

    // initially empty
    expect(repo.loadItems(), isEmpty);

    final item = await repo.createItem(name: 'Milk', quantity: 2);
    expect(item.name, 'Milk');
    expect(repo.loadItems().length, 1);

    final updated = item.copyWith(name: 'Milk2');
    await repo.updateItem(updated);
    expect(repo.loadItems().first.name, 'Milk2');

    await repo.deleteItem(item.id);
    expect(repo.loadItems(), isEmpty);
  });
}
