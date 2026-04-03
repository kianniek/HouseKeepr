import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

import '../models/shopping_item.dart';

class ShoppingRepository {
  final SharedPreferences prefs;
  final _uuid = const Uuid();

  ShoppingRepository(this.prefs);

  static const _kLegacyKey = 'shopping_v1';

  Future<void> _migrateFromPrefsIfNeeded() async {
    try {
      if (prefs.containsKey(_kLegacyKey)) {
        final raw = prefs.getStringList(_kLegacyKey) ?? <String>[];
        if (raw.isNotEmpty) {
          final box = _box;
          final meta = _meta;
          final ids = <String>[];
          for (final s in raw) {
            try {
              final decoded = json.decode(s);
              if (decoded is Map) {
                final map = Map<String, dynamic>.from(decoded);
                final it = ShoppingItem.fromMap(map);
                if (it.id.isNotEmpty && it.name.isNotEmpty) {
                  await box.put(it.id, it.toMap());
                  ids.add(it.id);
                }
              }
            } catch (_) {}
          }
          if (ids.isNotEmpty) await meta.put('order', ids);
        }
        await prefs.remove(_kLegacyKey);
      }
    } catch (_) {}
  }

  Box get _box => Hive.box('shopping');
  Box get _meta => Hive.box('shopping_meta');

  List<ShoppingItem> loadItems() {
    // If legacy SharedPreferences storage exists, parse and return it
    // synchronously so callers (tests) get the expected items immediately.
    if (prefs.getStringList(_kLegacyKey) != null) {
      final raw = prefs.getStringList(_kLegacyKey) ?? <String>[];
      final parsed = <ShoppingItem>[];
      for (final s in raw) {
        try {
          final decoded = json.decode(s);
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            final it = ShoppingItem.fromMap(map);
            if (it.name.isNotEmpty) parsed.add(it);
          }
        } catch (_) {}
      }
      Future.microtask(() => _migrateFromPrefsIfNeeded());
      return parsed;
    }

    final order = _meta.get('order') as List<dynamic>?;
    final out = <ShoppingItem>[];
    if (order != null && order.isNotEmpty) {
      for (final id in order.whereType<String>()) {
        final raw = _box.get(id);
        if (raw == null) continue;
        try {
          out.add(ShoppingItem.fromMap(Map<String, dynamic>.from(raw)));
        } catch (_) {}
      }
    } else {
      for (final raw in _box.values) {
        try {
          out.add(ShoppingItem.fromMap(Map<String, dynamic>.from(raw)));
        } catch (_) {}
      }
    }
    return out;
  }

  Future<void> saveItems(List<ShoppingItem> items) async {
    final ids = <String>[];
    for (final it in items) {
      ids.add(it.id);
      await _box.put(it.id, it.toMap());
    }
    await _meta.put('order', ids);
  }

  Future<ShoppingItem> createItem({
    required String name,
    String? category,
    String? note,
    int quantity = 1,
  }) async {
    final item = ShoppingItem(
      id: _uuid.v4(),
      name: name,
      category: category,
      note: note,
      quantity: quantity,
    );
    await _box.put(item.id, item.toMap());
    final order =
        (_meta.get('order') as List<dynamic>?)?.whereType<String>().toList() ??
        <String>[];
    order.add(item.id);
    await _meta.put('order', order);
    return item;
  }

  Future<void> updateItem(ShoppingItem item) async {
    if (_box.containsKey(item.id)) {
      await _box.put(item.id, item.toMap());
    }
  }

  Future<void> deleteItem(String id) async {
    await _box.delete(id);
    final order =
        (_meta.get('order') as List<dynamic>?)?.whereType<String>().toList() ??
        <String>[];
    order.removeWhere((s) => s == id);
    await _meta.put('order', order);
  }
}
