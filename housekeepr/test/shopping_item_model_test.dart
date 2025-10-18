import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/shopping_item.dart';

void main() {
  test('ShoppingItem toMap/fromMap and toJson/fromJson roundtrip', () {
    final item = ShoppingItem(
      id: 'id1',
      name: 'Milk',
      note: '2% milk',
      quantity: 2,
      category: 'Dairy',
      inCart: true,
    );

    final map = item.toMap();
    final fromMap = ShoppingItem.fromMap(map);
    expect(fromMap, equals(item));

    final jsonStr = item.toJson();
    final fromJson = ShoppingItem.fromJson(jsonStr);
    expect(fromJson, equals(item));
  });
}
