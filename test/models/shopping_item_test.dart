import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/shopping_item.dart';

void main() {
  test('ShoppingItem Serialization Test - booleans and timestamps', () {
    final dt = DateTime.utc(2025, 2, 3, 4, 5, 6);

    final m1 = {
      'id': 's1',
      'name': 'Milk',
      'quantity': '2',
      'inCart': 'true',
      'lastSyncedAt': dt.toIso8601String(),
    };

    final item1 = ShoppingItem.fromMap(m1);
    expect(item1.inCart, isTrue);
    expect(item1.quantity, 2);
    expect(item1.lastSyncedAt, dt.toUtc());

    final m2 = {'id': 's2', 'name': 'Eggs', 'quantity': 12, 'inCart': false};
    final item2 = ShoppingItem.fromMap(m2);
    expect(item2.inCart, isFalse);
    expect(item2.quantity, 12);
  });
}
