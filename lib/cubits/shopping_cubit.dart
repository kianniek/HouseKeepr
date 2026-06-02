import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/grocery_category.dart';
import '../models/grocery_item.dart';
import '../repositories/grocery_repository.dart';
import '../services/shopping_products_service.dart';
import '../services/write_queue.dart';

part 'shopping_state.dart';

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

  Future<void> reloadItems() async {
    return _load();
  }

  Future<void> _load() async {
    final items = _repository.loadItems();
    _emitSortedState(items);
  }

  void syncRemoteItems(List<GroceryItem> remoteItems) {
    final localItems = _repository.loadItems();
    final mergedItemsById = <String, GroceryItem>{
      for (final localItem in localItems) localItem.id: localItem,
    };

    for (final remoteItem in remoteItems) {
      final localItem = mergedItemsById[remoteItem.id];
      if (localItem == null ||
          remoteItem.updatedAt.isAfter(localItem.updatedAt)) {
        mergedItemsById[remoteItem.id] = remoteItem;
      }
    }

    final mergedItems = mergedItemsById.values.toList();
    _repository.saveItems(mergedItems);
    _emitSortedState(mergedItems);
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

  Future<void> _enqueueDelete(String id) async {
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
    double? quantity,
    String? unit,
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
          quantity: existingItem.quantity + 1.0,
          checked: false,
          updatedAt: DateTime.now(),
        );

        final items = List<GroceryItem>.from(state.items);
        items[existingIndex] = updatedItem;

        _emitSortedState(items);
        await _persist(updatedItem);
        return;
      }
    }

    // Auto-categorize if not provided or 'other'
    GroceryCategory finalCategory = category ?? state.selectedCategory;
    if (finalCategory == GroceryCategory.other) {
      final learned = ShoppingProductsService.instance.getCategoryForProduct(
        normalizedName,
      );
      if (learned != null) {
        finalCategory = learned;
      }
    }

    // Learn mapping if explicit category provided
    if (finalCategory != GroceryCategory.other) {
      await ShoppingProductsService.instance.learnProduct(
        normalizedName,
        finalCategory,
      );
    }

    final newItem = GroceryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: normalizedName,
      note: note,
      category: finalCategory,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
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
          updatedAt: DateTime.now(),
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
        changedItem = item.copyWith(
          quantity: nextQty,
          updatedAt: DateTime.now(),
        );
        return changedItem!;
      }
      return item;
    }).toList();

    if (changedItem != null) {
      _emitSortedState(items);
      await _persist(changedItem!);
    }
  }

  /// Update quantity to an arbitrary value (clamped to a valid positive range)
  Future<void> updateQuantityAndUnit(
    String id,
    double quantity,
    String? unit,
  ) async {
    final clampedQty = quantity.clamp(1.0, double.maxFinite);
    GroceryItem? changedItem;
    final items = state.items.map((item) {
      if (item.id == id) {
        changedItem = item.copyWith(
          quantity: clampedQty,
          unit: unit,
          updatedAt: DateTime.now(),
        );
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
    GroceryItem? deletedItem;
    final now = DateTime.now();
    final items = _repository.loadItems().map((item) {
      if (item.id == id) {
        deletedItem = item.copyWith(
          isDeleted: true,
          checked: false,
          checkedAt: null,
          updatedAt: now,
        );
        return deletedItem!;
      }
      return item;
    }).toList();

    if (deletedItem == null) return;

    _repository.saveItems(items);
    _emitSortedState(items);
    _writeQueue?.enqueueOp(
      QueueOp(
        type: QueueOpType.saveGrocery,
        id: deletedItem!.id,
        payload: deletedItem!.toMap(),
      ),
    );
    await _enqueueDelete(id);
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
        changedItem = item.copyWith(
          name: normalizedName,
          updatedAt: DateTime.now(),
        );
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

        changedItem = item.copyWith(
          category: category,
          updatedAt: DateTime.now(),
        );
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
    final checkedIds = state.items
        .where((item) => item.checked)
        .map((item) => item.id)
        .toSet();
    if (checkedIds.isEmpty) return;

    final now = DateTime.now();
    final allItems = _repository.loadItems();
    final changedItems = <GroceryItem>[];
    final updatedItems = allItems.map((item) {
      if (!checkedIds.contains(item.id)) return item;
      final deletedItem = item.copyWith(
        isDeleted: true,
        checked: false,
        checkedAt: null,
        updatedAt: now,
      );
      changedItems.add(deletedItem);
      return deletedItem;
    }).toList();

    _repository.saveItems(updatedItems);
    _emitSortedState(updatedItems);

    for (final item in changedItems) {
      _writeQueue?.enqueueOp(
        QueueOp(
          type: QueueOpType.saveGrocery,
          id: item.id,
          payload: item.toMap(),
        ),
      );
      await _enqueueDelete(item.id);
    }
  }

  /// Helper: Calculate next quantity in cycle
  static double _nextQuantity(double current) {
    const cycle = [1.0, 2.0, 3.0, 5.0, 10.0];
    final idx = cycle.indexOf(current);
    if (idx == -1) return 1.0;
    return cycle[(idx + 1) % cycle.length];
  }

  /// Helper: Sort items with bottom-sorting (unchecked first, then checked)
  void _emitSortedState(
    List<GroceryItem> items, {
    GroceryCategory? selectedCategory,
    bool? manualCategoryOverride,
    String? manualOverrideText,
    String? suggestedText,
    double? suggestionConfidence,
  }) {
    final visibleItems = items.where((i) => !i.isDeleted).toList();
    final unchecked = visibleItems.where((i) => !i.checked).toList();
    final checked = visibleItems.where((i) => i.checked).toList();

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
    emit(
      state.copyWith(
        items: sorted,
        selectedCategory: selectedCategory ?? state.selectedCategory,
        manualCategoryOverride:
            manualCategoryOverride ?? state.manualCategoryOverride,
        manualOverrideText: manualOverrideText ?? state.manualOverrideText,
        suggestedText: suggestedText ?? state.suggestedText,
        suggestionConfidence:
            suggestionConfidence ?? state.suggestionConfidence,
      ),
    );
  }

  void updateDraftText(String text) {
    if (state.manualCategoryOverride) {
      if (text.trim() != state.manualOverrideText) {
        emit(state.copyWith(manualCategoryOverride: false));
      } else {
        return;
      }
    }

    if (text.trim().isEmpty) {
      if (state.selectedCategory != GroceryCategory.other ||
          state.suggestedText != null) {
        emit(
          state.copyWith(
            selectedCategory: GroceryCategory.other,
            suggestedText: null,
            suggestionConfidence: 0.0,
          ),
        );
      }
      return;
    }

    final suggestion = ShoppingProductsService.instance.getProductSuggestion(
      text.trim(),
    );
    final nextSuggestedText = suggestion?.product;
    final nextSuggestionConfidence = suggestion?.confidence ?? 0.0;

    final learned = ShoppingProductsService.instance.getCategoryForProduct(
      text.trim(),
    );
    final nextCategory = learned ?? state.selectedCategory;

    if (nextCategory != state.selectedCategory ||
        nextSuggestedText != state.suggestedText ||
        nextSuggestionConfidence != state.suggestionConfidence) {
      emit(
        state.copyWith(
          selectedCategory: learned ?? state.selectedCategory,
          suggestedText: nextSuggestedText,
          suggestionConfidence: nextSuggestionConfidence,
        ),
      );
    }
  }

  void setManualCategory(GroceryCategory category, String text) {
    emit(
      state.copyWith(
        selectedCategory: category,
        manualCategoryOverride: true,
        manualOverrideText: text.trim(),
      ),
    );
  }
}
