import 'package:hive/hive.dart';
import '../models/grocery_item.dart';

class GroceryRepository {
  GroceryRepository();

  Box get _box => Hive.box('groceries');
  Box get _meta => Hive.box('groceries_meta');

  List<GroceryItem> loadItems() {
    final items = <GroceryItem>[];
    final raw = _box.values;
    for (final item in raw) {
      if (item is Map) {
        try {
          items.add(GroceryItem.fromMap(Map<String, dynamic>.from(item)));
        } catch (_) {}
      }
    }

    // Sort by checking order meta if needed, or just let Cubit sort.
    // Ideally we preserve some order.
    if (_meta.containsKey('order')) {
      final order = List<String>.from(_meta.get('order'));
      final map = {for (var i in items) i.id: i};
      final sorted = <GroceryItem>[];
      for (final id in order) {
        if (map.containsKey(id)) {
          sorted.add(map[id]!);
          map.remove(id);
        }
      }
      // Add any remaining items (newly added maybe?)
      sorted.addAll(map.values);
      return sorted;
    }

    return items;
  }

  Future<void> saveItem(GroceryItem item) async {
    await _box.put(item.id, item.toMap());
    await _updateOrder();
  }

  Future<void> deleteItem(String id) async {
    await _box.delete(id);
    await _updateOrder(removeId: id);
  }

  Future<void> saveItems(List<GroceryItem> items) async {
    final Map<String, Map<String, dynamic>> entries = {};
    for (final item in items) {
      entries[item.id] = item.toMap();
    }
    await _box.putAll(entries);
    await _updateOrder(newOrder: items.map((e) => e.id).toList());
  }

  Future<void> updateOrder(List<String> order) async {
    await _meta.put('order', order);
  }

  Future<void> _updateOrder({String? removeId, List<String>? newOrder}) async {
    if (newOrder != null) {
      await _meta.put('order', newOrder);
      return;
    }

    // If just modifying one item, we might not need to reorder unless it's new
    // But maintaining order ensures consistency.
    // For now, let's just make sure the ID list is consistent with box keys.
    final currentOrder =
        _meta.get('order', defaultValue: <String>[])?.cast<String>() ?? [];

    if (removeId != null) {
      currentOrder.remove(removeId);
      await _meta.put('order', currentOrder);
    }
  }
}
