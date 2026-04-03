import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/grocery_item.dart';
import '../models/grocery_category.dart';
import '../repositories/grocery_repository.dart';
import '../services/write_queue.dart';
import '../services/shopping_products_service.dart';

part 'shopping_state_v2.dart';

class ShoppingCubit extends Cubit<ShoppingState> {
  final GroceryRepository _repository;
  WriteQueue? _writeQueue;
  Future<void>? initializationFuture;

  /// Public access to the underlying repository (used by WidgetService for
  /// reconciling toggle actions from the home-screen widget).
  GroceryRepository get repository => _repository;

  ShoppingCubit(this._repository) : super(ShoppingState.initial()) {
    initializationFuture = _load();
  }

  void attachWriteQueue(WriteQueue queue) {
    _writeQueue = queue;
  }

  Future<void> _load() async {
    final items = _repository.loadItems();
    _emitSortedState(items);
  }

  void syncRemoteItems(List<GroceryItem> remoteItems) {
    // Determine if we should replace everything or merge.
    // For simplicity with the WriteQueue pattern, we often accept the server state
    // but we might want to preserve local optimistic updates if we can track them.
    // However, since we don't have complex versioning in state yet,
    // let's accept the remote items as the base truth, update local cache, and emit.
    _repository.saveItems(remoteItems);
    _emitSortedState(remoteItems);
  }

  Future<void> _persist(GroceryItem item) async {
    await _repository.saveItem(item);
    _writeQueue?.enqueueOp(
      QueueOp(
        type: QueueOpType.saveGrocery,
        id: item.id,
        payload: item.toMap(),
      ),
    );
  }

  Future<void> _delete(String id) async {
    await _repository.deleteItem(id);
    _writeQueue?.enqueueOp(QueueOp(type: QueueOpType.deleteGrocery, id: id));
  }

  String _normalizeItemName(String input) {
    final collapsed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return '';
    return collapsed
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) => word.length == 1
              ? word.toUpperCase()
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  /// Add a new grocery item
  Future<void> addItem(
    String name, {
    String? note,
    GroceryCategory? category,
  }) async {
    final normalizedName = _normalizeItemName(name);

    // Check for existing item to merge (only if name is not empty)
    if (normalizedName.isNotEmpty) {
      final existingIndex = state.items.indexWhere(
        (i) =>
            _normalizeItemName(i.name).toLowerCase() ==
            normalizedName.toLowerCase(),
      );

      if (existingIndex != -1) {
        final existingItem = state.items[existingIndex];
        // Merge: Increment quantity and uncheck if checked
        final updatedItem = existingItem.copyWith(
          quantity: existingItem.quantity + 1,
          checked: false,
        );

        final items = List<GroceryItem>.from(state.items);
        items[existingIndex] = updatedItem;

        _emitSortedState(items);
        await _persist(updatedItem);
        return;
      }
    }

    // Auto-categorize if not provided or 'other'
    GroceryCategory finalCategory = category ?? GroceryCategory.other;
    if (finalCategory == GroceryCategory.other) {
      final learned = ShoppingProductsService.instance.getCategoryForProduct(
        normalizedName,
      );
      if (learned != null) {
        finalCategory = learned;
      }
    }

    // Learn mapping if explicit category provided
    if (category != null && category != GroceryCategory.other) {
      await ShoppingProductsService.instance.learnProduct(
        normalizedName,
        category,
      );
    }

    final newItem = GroceryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: normalizedName,
      note: note,
      category: finalCategory,
      createdAt: DateTime.now(),
    );

    final items = List<GroceryItem>.from(state.items)..add(newItem);
    _emitSortedState(items);
    await _persist(newItem);
  }

  /// Toggle item checked status and apply bottom-sort
  Future<void> toggleItem(String id) async {
    GroceryItem? changedItem;
    final items = state.items.map((item) {
      if (item.id == id) {
        changedItem = item.copyWith(
          checked: !item.checked,
          checkedAt: !item.checked ? DateTime.now() : null,
        );
        return changedItem!;
      }
      return item;
    }).toList();

    if (changedItem != null) {
      // Learn category mapping when item is checked off
      if (changedItem!.checked && changedItem!.name.isNotEmpty) {
        ShoppingProductsService.instance.learnProduct(
          changedItem!.name,
          changedItem!.category,
        );
      }
      _emitSortedState(items);
      await _persist(changedItem!);
    }
  }

  /// Increment quantity with cycling (1 → 2 → 3 → 5 → 10 → 1)
  Future<void> cycleQuantity(String id) async {
    GroceryItem? changedItem;
    final items = state.items.map((item) {
      if (item.id == id) {
        final nextQty = _nextQuantity(item.quantity);
        changedItem = item.copyWith(quantity: nextQty);
        return changedItem!;
      }
      return item;
    }).toList();

    if (changedItem != null) {
      _emitSortedState(items);
      await _persist(changedItem!);
    }
  }

  /// Update quantity to an arbitrary value (clamped 1-99)
  Future<void> updateQuantity(String id, int quantity) async {
    final clampedQty = quantity.clamp(1, 99);
    GroceryItem? changedItem;
    final items = state.items.map((item) {
      if (item.id == id) {
        changedItem = item.copyWith(quantity: clampedQty);
        return changedItem!;
      }
      return item;
    }).toList();

    if (changedItem != null) {
      _emitSortedState(items);
      await _persist(changedItem!);
    }
  }

  /// Delete an item
  Future<void> deleteItem(String id) async {
    final items = state.items.where((item) => item.id != id).toList();
    _emitSortedState(items);
    await _delete(id);
  }

  /// Reorder items (for drag-and-drop)
  Future<void> reorderItem(int oldIndex, int newIndex) async {
    final items = List<GroceryItem>.from(state.items);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Save the new order in meta if supported, or just rely on local state for now.
    // Ideally we persist an 'order' field or update a meta document.
    // For now, we update the state.
    // If we want to persist sort order, we need to update the repository's order meta.

    // We'll trust the repository to handle order saving if we save all items?
    // Or we explicitly save order.
    // GroceryRepository has updateOrder.
    _repository.updateOrder(items.map((e) => e.id).toList());

    emit(state.copyWith(items: items));
  }

  /// Update item name
  Future<void> updateItemName(String id, String newName) async {
    final normalizedName = _normalizeItemName(newName);
    if (normalizedName.isEmpty) return;

    GroceryItem? changedItem;
    final items = state.items.map((item) {
      if (item.id == id) {
        changedItem = item.copyWith(name: normalizedName);
        return changedItem!;
      }
      return item;
    }).toList();

    if (changedItem != null) {
      _emitSortedState(items);
      await _persist(changedItem!);
    }
  }

  /// Update category
  Future<void> updateCategory(String id, GroceryCategory category) async {
    GroceryItem? changedItem;
    final items = state.items.map((item) {
      if (item.id == id) {
        // Learn this new mapping
        ShoppingProductsService.instance.learnProduct(item.name, category);

        changedItem = item.copyWith(category: category);
        return changedItem!;
      }
      return item;
    }).toList();

    if (changedItem != null) {
      _emitSortedState(items);
      await _persist(changedItem!);
    }
  }

  /// Toggle aisle mode
  void toggleAisleMode() {
    emit(state.copyWith(aisleModeEnabled: !state.aisleModeEnabled));
  }

  /// Toggle flat view mode
  void toggleFlatView() {
    emit(state.copyWith(flatViewEnabled: !state.flatViewEnabled));
  }

  /// Clear all checked items
  Future<void> clearCheckedItems() async {
    final toDelete = state.items.where((item) => item.checked).toList();
    final items = state.items.where((item) => !item.checked).toList();

    _emitSortedState(items);

    for (final item in toDelete) {
      await _delete(item.id);
    }
  }

  /// Helper: Calculate next quantity in cycle
  static int _nextQuantity(int current) {
    const cycle = [1, 2, 3, 5, 10];
    final idx = cycle.indexOf(current);
    if (idx == -1) return 1;
    return cycle[(idx + 1) % cycle.length];
  }

  /// Helper: Sort items with bottom-sorting (unchecked first, then checked)
  void _emitSortedState(List<GroceryItem> items) {
    final unchecked = items.where((i) => !i.checked).toList();
    final checked = items.where((i) => i.checked).toList();

    // Sort unchecked by category, then by creation time
    unchecked.sort((a, b) {
      final catCmp = a.category.displayName.compareTo(b.category.displayName);
      if (catCmp != 0) return catCmp;
      return a.createdAt.compareTo(b.createdAt);
    });

    // Sort checked by checked time (most recent first)
    checked.sort(
      (a, b) => (b.checkedAt ?? DateTime.now()).compareTo(
        a.checkedAt ?? DateTime.now(),
      ),
    );

    final sorted = [...unchecked, ...checked];
    emit(state.copyWith(items: sorted));
  }
}
