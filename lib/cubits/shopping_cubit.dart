import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../core/grocery_parser.dart';

import '../models/grocery_category.dart';
import '../models/grocery_item.dart';
import '../repositories/grocery_repository.dart';
import '../services/firestore_sync_service.dart';
import '../services/shopping_products_service.dart';
import '../services/write_queue.dart';

part 'shopping_state.dart';

class ShoppingCubit extends Cubit<ShoppingState> {
  /// How long soft-deleted items stay in "Recently Deleted" before they are
  /// permanently purged.
  static const Duration deletedRetention = Duration(days: 7);

  /// How often expired soft-deleted items are purged while the app is open.
  static const Duration purgeInterval = Duration(hours: 1);

  final GroceryRepository _repository;
  WriteQueue? _writeQueue;
  Future<void>? initializationFuture;
  Timer? _purgeTimer;

  /// Ids for which a remote hard-delete has already been enqueued during this
  /// session, to avoid flooding the queue while snapshots catch up.
  final Set<String> _purgeEnqueuedIds = {};

  /// Public access to the underlying repository (used by WidgetService for
  /// reconciling toggle actions from the home-screen widget).
  GroceryRepository get repository => _repository;

  ShoppingCubit(this._repository) : super(ShoppingState.initial()) {
    initializationFuture = _load();
    _purgeTimer = Timer.periodic(
      purgeInterval,
      (_) => purgeExpiredDeletedItems(),
    );
  }

  @override
  Future<void> close() {
    _purgeTimer?.cancel();
    _purgeTimer = null;
    return super.close();
  }

  /// Soft-deleted items older than [deletedRetention] whose remote deletion
  /// has not yet been enqueued because the write queue was not attached.
  final Set<String> _pendingRemotePurgeIds = {};

  void attachWriteQueue(WriteQueue queue) {
    _writeQueue = queue;
    for (final id in _pendingRemotePurgeIds) {
      _enqueueDelete(id);
    }
    _pendingRemotePurgeIds.clear();
    // Now that remote deletes can actually be enqueued, purge again.
    purgeExpiredDeletedItems();
  }

  Future<void> reloadItems() async {
    return _load();
  }

  /// Hard reloads shopping assets directly from the network nodes while flushing local indexes.
  Future<void> reloadItemsFromServer(FirestoreSyncService syncService) async {
    try {
      // 1. Fetch fresh list from server first (guarantees we don't clear storage on network failure)
      final remoteFreshList = await syncService.forceFetchRemoteState();

      // 2. Invalidate local database and shared storage structures
      await _repository.clearAll();

      // 3. Re-get and commit the retrieved records into memory and state
      await _repository.overwriteAll(remoteFreshList);
      _emitSortedState(remoteFreshList);
    } catch (e) {
      // Optionally emit an error state or rethrow for handling in UI
      rethrow;
    }
  }

  Future<void> _load() async {
    final items = _repository.loadItems();
    _emitSortedState(items);
    await purgeExpiredDeletedItems();
  }

  /// Synchronizes incoming records with local state data using strict deterministic timestamp evaluations.
  void syncRemoteItems(List<GroceryItem> remoteItems) {
    final localItems = _repository.loadItems();

    final mergedItemsById = <String, GroceryItem>{
      for (final localItem in localItems) localItem.id: localItem,
    };

    for (final remoteItem in remoteItems) {
      final localItem = mergedItemsById[remoteItem.id];

      if (localItem == null) {
        // Device missing this record entirely -> accept it
        mergedItemsById[remoteItem.id] = remoteItem;
      } else {
        // Device collision -> evaluate timestamps deterministically
        if (remoteItem.updatedAt.isAfter(localItem.updatedAt)) {
          mergedItemsById[remoteItem.id] = remoteItem;
        }
        // If local is newer, keep local. The write queue will eventual-consistent update the server.
      }
    }

    // Drop tombstones that are past the retention window (and purge them
    // remotely) instead of re-inserting them locally.
    final expiredIds = mergedItemsById.values
        .where(isExpiredTombstone)
        .map((i) => i.id)
        .toList();
    for (final id in expiredIds) {
      mergedItemsById.remove(id);
      _repository.deleteItem(id);
      _enqueueRemotePurge(id);
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

  /// Enqueue a remote hard-delete once per session for [id].
  void _enqueueRemotePurge(String id) {
    if (_writeQueue == null) {
      _pendingRemotePurgeIds.add(id);
      return; // retried once the queue is attached
    }
    if (!_purgeEnqueuedIds.add(id)) return;
    _enqueueDelete(id);
  }

  /// The moment a tombstone was deleted (legacy tombstones without
  /// `deletedAt` fall back to `updatedAt`).
  static DateTime deletedMoment(GroceryItem item) =>
      item.deletedAt ?? item.updatedAt;

  /// Whether [item] is a tombstone older than [deletedRetention].
  static bool isExpiredTombstone(GroceryItem item, {DateTime? now}) {
    if (!item.isDeleted) return false;
    final cutoff = (now ?? DateTime.now()).subtract(deletedRetention);
    return deletedMoment(item).isBefore(cutoff);
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
        final addedQty = quantity ?? 1.0;
        final updatedItem = existingItem.copyWith(
          quantity: existingItem.quantity + addedQty,
          unit: existingItem.unit ?? unit,
          note: note ?? existingItem.note,
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
      id: const Uuid().v4(),
      name: normalizedName,
      note: note,
      quantity: quantity ?? 1.0,
      unit: unit,
      category: finalCategory,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final items = List<GroceryItem>.from(state.items)..add(newItem);
    _emitSortedState(items);
    await _persist(newItem);
  }

  /// Bulk add multiple grocery items
  Future<void> addItems(List<ParsedGroceryItem> parsedItems) async {
    for (final item in parsedItems) {
      await addItem(
        item.name,
        note: item.note,
        category: item.category,
        quantity: item.quantity,
        unit: item.unit,
      );
    }
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

  /// Soft-delete an item. It stays in "Recently Deleted" for
  /// [deletedRetention] before being purged. Returns the deleted item (so the
  /// UI can offer undo) or null if it was not found.
  ///
  /// [deletedAt] can be passed to keep an item's original deletion time (used
  /// when undoing a restore from "Recently Deleted").
  Future<GroceryItem?> deleteItem(String id, {DateTime? deletedAt}) async {
    GroceryItem? deletedItem;
    final now = DateTime.now();
    final items = _repository.loadItems().map((item) {
      if (item.id == id && !item.isDeleted) {
        deletedItem = item.copyWith(
          isDeleted: true,
          deletedAt: deletedAt ?? now,
          updatedAt: now,
        );
        return deletedItem!;
      }
      return item;
    }).toList();

    if (deletedItem == null) return null;

    // Emit synchronously first: a dismissed Dismissible must leave the tree
    // before the next frame.
    _emitSortedState(items);
    await _repository.saveItems(items);
    _writeQueue?.enqueueOp(
      QueueOp(
        type: QueueOpType.saveGrocery,
        id: deletedItem!.id,
        payload: deletedItem!.toMap(),
      ),
    );
    return deletedItem;
  }

  /// Restore soft-deleted items. When [uncheck] is true the restored items are
  /// also unchecked (used when restoring from "Recently Deleted").
  Future<void> restoreItems(List<String> ids, {bool uncheck = false}) async {
    if (ids.isEmpty) return;
    final idSet = ids.toSet();
    final now = DateTime.now();
    final changed = <GroceryItem>[];
    final items = _repository.loadItems().map((item) {
      if (!idSet.contains(item.id) || !item.isDeleted) return item;
      final restored = item.copyWith(
        isDeleted: false,
        deletedAt: null,
        updatedAt: now,
        checked: uncheck ? false : null,
        checkedAt: uncheck ? null : item.checkedAt,
      );
      changed.add(restored);
      return restored;
    }).toList();

    if (changed.isEmpty) return;

    _emitSortedState(items);
    await _repository.saveItems(items);
    for (final item in changed) {
      _purgeEnqueuedIds.remove(item.id);
      _writeQueue?.enqueueOp(
        QueueOp(
          type: QueueOpType.saveGrocery,
          id: item.id,
          payload: item.toMap(),
        ),
      );
    }
  }

  /// Permanently delete items locally and remotely (no undo).
  Future<void> permanentlyDelete(List<String> ids) async {
    if (ids.isEmpty) return;
    final idSet = ids.toSet();
    // Emit synchronously first (Dismissible in "Recently Deleted").
    _emitSortedState(
      _repository.loadItems().where((i) => !idSet.contains(i.id)).toList(),
    );
    for (final id in idSet) {
      await _repository.deleteItem(id);
      _purgeEnqueuedIds.add(id);
      await _enqueueDelete(id);
    }
  }

  /// Permanently delete all tombstones older than [deletedRetention].
  Future<void> purgeExpiredDeletedItems() async {
    if (isClosed) return;
    final items = _repository.loadItems();
    final expired = items.where(isExpiredTombstone).map((i) => i.id).toList();
    if (expired.isEmpty) return;
    for (final id in expired) {
      await _repository.deleteItem(id);
      _enqueueRemotePurge(id);
    }
    if (isClosed) return;
    _emitSortedState(_repository.loadItems());
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

  /// Clear all checked items (soft-delete). Returns the ids that were cleared
  /// so the UI can offer undo.
  Future<List<String>> clearCheckedItems() async {
    final checkedIds = state.items
        .where((item) => item.checked)
        .map((item) => item.id)
        .toSet();
    if (checkedIds.isEmpty) return const [];

    final now = DateTime.now();
    final allItems = _repository.loadItems();
    final changedItems = <GroceryItem>[];
    final updatedItems = allItems.map((item) {
      if (!checkedIds.contains(item.id) || item.isDeleted) return item;
      final deletedItem = item.copyWith(
        isDeleted: true,
        deletedAt: now,
        updatedAt: now,
      );
      changedItems.add(deletedItem);
      return deletedItem;
    }).toList();

    _emitSortedState(updatedItems);
    await _repository.saveItems(updatedItems);

    for (final item in changedItems) {
      _writeQueue?.enqueueOp(
        QueueOp(
          type: QueueOpType.saveGrocery,
          id: item.id,
          payload: item.toMap(),
        ),
      );
    }
    return changedItems.map((i) => i.id).toList();
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

    final now = DateTime.now();
    final recentlyDeleted =
        items
            .where((i) => i.isDeleted && !isExpiredTombstone(i, now: now))
            .toList()
          ..sort((a, b) => deletedMoment(b).compareTo(deletedMoment(a)));

    emit(
      state.copyWith(
        items: sorted,
        recentlyDeleted: recentlyDeleted,
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
