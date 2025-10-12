import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/shopping_item.dart';

class ShoppingRepository {
  static const _kKey = 'shopping_v1';
  final SharedPreferences prefs;
  final _uuid = const Uuid();

  ShoppingRepository(this.prefs);

  List<ShoppingItem> loadItems() {
    final raw = prefs.getStringList(_kKey) ?? [];
    return raw.map((e) => ShoppingItem.fromJson(e)).toList();
  }

  Future<void> saveItems(List<ShoppingItem> items) async {
    final raw = items.map((i) => i.toJson()).toList();
    await prefs.setStringList(_kKey, raw);
  }

  Future<ShoppingItem> createItem({
    required String name,
    String? category,
    String? note,
    int quantity = 1,
  }) async {
    final items = loadItems();
    final item = ShoppingItem(
      id: _uuid.v4(),
      name: name,
      category: category,
      note: note,
      quantity: quantity,
    );
    items.add(item);
    await saveItems(items);
    return item;
  }

  Future<void> updateItem(ShoppingItem item) async {
    final items = loadItems();
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      items[idx] = item;
      await saveItems(items);
    }
  }

  Future<void> deleteItem(String id) async {
    final items = loadItems();
    items.removeWhere((i) => i.id == id);
    await saveItems(items);
  }
}
