import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static const String _aisleModeKey = 'shopping_aisle_mode_v1';
  static const String _flatViewKey = 'shopping_flat_view_v1';

  final GroceryRepository _repository;
  WriteQueue? _writeQueue;
  Future<void>? initializationFuture;
  Timer? _purgeTimer;
  bool _hasToggledAisleMode = false;
  bool _hasToggledFlatView = false;

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
    await _loadViewPreferences();
    await purgeExpiredDeletedItems();
  }

  Future<void> _loadViewPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isClosed) return;
      final savedAisleMode = _hasToggledAisleMode
          ? null
          : prefs.getBool(_aisleModeKey);
      final savedFlatView = _hasToggledFlatView
          ? null
          : prefs.getBool(_flatViewKey);
      if (savedAisleMode == null && savedFlatView == null) return;
      emit(
        state.copyWith(
          aisleModeEnabled: savedAisleMode ?? state.aisleModeEnabled,
          flatViewEnabled: savedFlatView ?? state.flatViewEnabled,
        ),
      );
    } catch (_) {}
  }

  Future<void> _saveBoolPreference(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
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
    final hasExplicitQtyOrUnit = quantity != null || unit != null;
    final usualQtyUnit = (!hasExplicitQtyOrUnit && normalizedName.isNotEmpty)
        ? ShoppingProductsService.instance.getUsualQuantityAndUnit(
            normalizedName,
          )
        : null;
    final finalQuantity = quantity ?? usualQtyUnit?.quantity ?? 1.0;
    final finalUnit = unit ?? (quantity == null ? usualQtyUnit?.unit : null);

    // Check for existing standalone item to merge (only if name is not empty)
    if (normalizedName.isNotEmpty) {
      final existingIndex = state.items.indexWhere(
        (i) =>
            !i.isRecipe &&
            i.parentRecipeId == null &&
            _normalizeItemName(i.name).toLowerCase() ==
                normalizedName.toLowerCase(),
      );

      if (existingIndex != -1) {
        final existingItem = state.items[existingIndex];
        // Merge: Increment quantity and uncheck if checked
        final updatedItem = existingItem.copyWith(
          quantity: existingItem.quantity + finalQuantity,
          unit: existingItem.unit ?? finalUnit,
          note: note ?? existingItem.note,
          category: (category != null && category != GroceryCategory.other)
              ? category
              : existingItem.category,
          checked: false,
          checkedAt: null,
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

    // Learn explicit category / quantity / unit usage
    if (finalCategory != GroceryCategory.other || hasExplicitQtyOrUnit) {
      await ShoppingProductsService.instance.learnProductUsage(
        normalizedName,
        category: finalCategory != GroceryCategory.other ? finalCategory : null,
        quantity: hasExplicitQtyOrUnit ? finalQuantity : null,
        unit: hasExplicitQtyOrUnit ? finalUnit : null,
        weight: 1,
      );
    }

    final newItem = GroceryItem(
      id: const Uuid().v4(),
      name: normalizedName,
      note: note,
      quantity: finalQuantity,
      unit: finalUnit,
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

  /// Add an imported recipe as a parent container with nested child ingredients.
  /// Child ingredients are kept isolated inside the recipe container and are
  /// not merged with standalone items or other recipes.
  Future<GroceryItem> addRecipe({
    required String title,
    required String url,
    String? sourceName,
    int? servings,
    String? imageUrl,
    required List<ParsedGroceryItem> ingredients,
  }) async {
    final now = DateTime.now();
    const uuid = Uuid();
    final recipeId = uuid.v4();
    final trimmedTitle = title.trim().isEmpty
        ? (sourceName ?? 'Recipe')
        : title.trim();

    final parentRecipe = GroceryItem(
      id: recipeId,
      name: trimmedTitle,
      quantity: 1.0,
      category: GroceryCategory.other,
      createdAt: now,
      updatedAt: now,
      isRecipe: true,
      recipeUrl: url.trim(),
      recipeSource: sourceName,
      recipeServings: servings,
      recipeImageUrl: imageUrl,
    );

    final createdItems = <GroceryItem>[parentRecipe];

    for (var i = 0; i < ingredients.length; i++) {
      final ing = ingredients[i];
      final normalizedName = _normalizeItemName(ing.name);
      if (normalizedName.isEmpty) continue;

      GroceryCategory finalCategory = ing.category;
      if (finalCategory == GroceryCategory.other) {
        final learned = ShoppingProductsService.instance.getCategoryForProduct(
          normalizedName,
        );
        if (learned != null) {
          finalCategory = learned;
        }
      }

      final childItem = GroceryItem(
        id: uuid.v4(),
        name: normalizedName,
        note: ing.note,
        quantity: ing.quantity,
        unit: ing.unit,
        category: finalCategory,
        createdAt: now.add(Duration(milliseconds: i + 1)),
        updatedAt: now,
        parentRecipeId: recipeId,
      );
      createdItems.add(childItem);
    }

    final allItems = List<GroceryItem>.from(_repository.loadItems())
      ..addAll(createdItems);
    _emitSortedState(allItems);
    await _repository.saveItems(allItems);

    for (final item in createdItems) {
      _writeQueue?.enqueueOp(
        QueueOp(
          type: QueueOpType.saveGrocery,
          id: item.id,
          payload: item.toMap(),
        ),
      );
    }

    return parentRecipe;
  }

  /// Toggle item checked status and apply bottom-sort.
  /// Toggling a recipe parent toggles all its children; toggling a child
  /// updates its parent recipe's checked state when all children are checked.
  Future<void> toggleItem(String id) async {
    final targetIndex = state.items.indexWhere((i) => i.id == id);
    if (targetIndex == -1) return;

    final target = state.items[targetIndex];
    final now = DateTime.now();
    final newChecked = !target.checked;
    final changedItems = <GroceryItem>[];

    List<GroceryItem> updatedActiveItems;

    if (target.isRecipe) {
      updatedActiveItems = state.items.map((item) {
        if (item.id == id || item.parentRecipeId == id) {
          final updated = item.copyWith(
            checked: newChecked,
            checkedAt: newChecked ? now : null,
            updatedAt: now,
          );
          changedItems.add(updated);
          return updated;
        }
        return item;
      }).toList();
    } else if (target.parentRecipeId != null) {
      final parentId = target.parentRecipeId!;
      final toggledItems = state.items.map((item) {
        if (item.id == id) {
          final updated = item.copyWith(
            checked: newChecked,
            checkedAt: newChecked ? now : null,
            updatedAt: now,
          );
          changedItems.add(updated);
          return updated;
        }
        return item;
      }).toList();

      final siblings = toggledItems
          .where((item) => item.parentRecipeId == parentId)
          .toList();
      final allChildrenChecked =
          siblings.isNotEmpty && siblings.every((item) => item.checked);

      updatedActiveItems = toggledItems.map((item) {
        if (item.id == parentId && item.checked != allChildrenChecked) {
          final updatedParent = item.copyWith(
            checked: allChildrenChecked,
            checkedAt: allChildrenChecked ? now : null,
            updatedAt: now,
          );
          changedItems.add(updatedParent);
          return updatedParent;
        }
        return item;
      }).toList();
    } else {
      updatedActiveItems = state.items.map((item) {
        if (item.id == id) {
          final updated = item.copyWith(
            checked: newChecked,
            checkedAt: newChecked ? now : null,
            updatedAt: now,
          );
          changedItems.add(updated);
          return updated;
        }
        return item;
      }).toList();
    }

    if (changedItems.isEmpty) return;

    // Learn category, quantity, and unit for newly checked non-recipe items
    for (final changed in changedItems) {
      if (!changed.isRecipe && changed.checked && changed.name.isNotEmpty) {
        await ShoppingProductsService.instance.learnProductUsage(
          changed.name,
          category: changed.category != GroceryCategory.other
              ? changed.category
              : null,
          quantity: changed.quantity,
          unit: changed.unit,
          weight: 1,
        );
      }
    }

    // Merge active updates back with any soft-deleted tombstones in repository
    final changedById = {for (final item in changedItems) item.id: item};
    final allRepoItems = _repository.loadItems().map((item) {
      return changedById[item.id] ?? item;
    }).toList();
    final itemsToSave = allRepoItems.isNotEmpty
        ? allRepoItems
        : updatedActiveItems;

    _emitSortedState(itemsToSave);
    await _repository.saveItems(itemsToSave);

    for (final item in changedItems) {
      _writeQueue?.enqueueOp(
        QueueOp(
          type: QueueOpType.saveGrocery,
          id: item.id,
          payload: item.toMap(),
        ),
      );
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

  /// Update full item details (name, note, quantity, unit, and category).
  Future<void> updateItemDetails(
    String id, {
    required String name,
    String? note,
    required double quantity,
    String? unit,
    required GroceryCategory category,
  }) async {
    final normalizedName = _normalizeItemName(name);
    if (normalizedName.isEmpty) return;

    final trimmedNote = note?.trim();
    final finalNote = (trimmedNote == null || trimmedNote.isEmpty)
        ? null
        : trimmedNote;
    final trimmedUnit = unit?.trim();
    final finalUnit = (trimmedUnit == null || trimmedUnit.isEmpty)
        ? null
        : trimmedUnit;
    final clampedQty = quantity.clamp(0.1, double.maxFinite);

    if (category != GroceryCategory.other ||
        clampedQty != 1.0 ||
        finalUnit != null) {
      await ShoppingProductsService.instance.learnProductUsage(
        normalizedName,
        category: category != GroceryCategory.other ? category : null,
        quantity: clampedQty,
        unit: finalUnit,
        weight: 2,
      );
    }

    GroceryItem? changedItem;
    final items = state.items.map((item) {
      if (item.id == id) {
        changedItem = item.copyWith(
          name: normalizedName,
          note: finalNote,
          quantity: clampedQty,
          unit: finalUnit,
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

  /// Uncheck all completed items. Returns the affected item IDs for undo.
  Future<List<String>> uncheckAllCompleted() async {
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
      final unchecked = item.copyWith(
        checked: false,
        checkedAt: null,
        updatedAt: now,
      );
      changedItems.add(unchecked);
      return unchecked;
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

  /// Re-check items by ID (used to undo [uncheckAllCompleted]).
  Future<void> recheckItems(List<String> ids) async {
    if (ids.isEmpty) return;
    final idSet = ids.toSet();
    final now = DateTime.now();
    final allItems = _repository.loadItems();
    final changedItems = <GroceryItem>[];
    final updatedItems = allItems.map((item) {
      if (!idSet.contains(item.id) || item.isDeleted || item.checked) {
        return item;
      }
      final rechecked = item.copyWith(
        checked: true,
        checkedAt: now,
        updatedAt: now,
      );
      changedItems.add(rechecked);
      return rechecked;
    }).toList();

    if (changedItems.isEmpty) return;

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
  }

  /// Update quantity to an arbitrary value (clamped to a valid positive range)
  Future<void> updateQuantityAndUnit(
    String id,
    double quantity,
    String? unit,
  ) async {
    final clampedQty = quantity.clamp(0.1, double.maxFinite);
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
      await ShoppingProductsService.instance.learnProductUsage(
        changedItem!.name,
        quantity: clampedQty,
        unit: unit,
        weight: 2,
      );
      _emitSortedState(items);
      await _persist(changedItem!);
    }
  }

  /// Soft-delete an item (and its child ingredients if it is a recipe parent).
  /// It stays in "Recently Deleted" for [deletedRetention] before being purged.
  /// Returns the deleted item (so the UI can offer undo) or null if not found.
  ///
  /// [deletedAt] can be passed to keep an item's original deletion time (used
  /// when undoing a restore from "Recently Deleted").
  Future<GroceryItem?> deleteItem(String id, {DateTime? deletedAt}) async {
    final deleted = await deleteRecipeWithChildren(id, deletedAt: deletedAt);
    return deleted.isEmpty ? null : deleted.first;
  }

  /// Soft-delete an item and, if it is a recipe parent, all of its active
  /// child ingredients. Returns all soft-deleted items (parent first) for Undo.
  Future<List<GroceryItem>> deleteRecipeWithChildren(
    String id, {
    DateTime? deletedAt,
  }) async {
    final now = DateTime.now();
    final effectiveDeletedAt = deletedAt ?? now;
    final deletedItems = <GroceryItem>[];

    final allItems = _repository.loadItems();
    final targetExists = allItems.any(
      (item) => item.id == id && !item.isDeleted,
    );
    if (!targetExists) return const [];

    final target = allItems.firstWhere((item) => item.id == id);
    final updatedItems = allItems.map((item) {
      final shouldDelete =
          !item.isDeleted &&
          (item.id == id || (target.isRecipe && item.parentRecipeId == id));
      if (shouldDelete) {
        final tombstone = item.copyWith(
          isDeleted: true,
          deletedAt: effectiveDeletedAt,
          updatedAt: now,
        );
        deletedItems.add(tombstone);
        return tombstone;
      }
      return item;
    }).toList();

    if (deletedItems.isEmpty) return const [];

    // Emit synchronously first: a dismissed Dismissible must leave the tree
    // before the next frame.
    _emitSortedState(updatedItems);
    await _repository.saveItems(updatedItems);
    for (final item in deletedItems) {
      _writeQueue?.enqueueOp(
        QueueOp(
          type: QueueOpType.saveGrocery,
          id: item.id,
          payload: item.toMap(),
        ),
      );
    }
    return deletedItems;
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
        // Learn this new mapping with higher weight
        ShoppingProductsService.instance.learnProductUsage(
          item.name,
          category: category,
          weight: 2,
        );

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
    _hasToggledAisleMode = true;
    final nextValue = !state.aisleModeEnabled;
    emit(state.copyWith(aisleModeEnabled: nextValue));
    unawaited(_saveBoolPreference(_aisleModeKey, nextValue));
  }

  /// Toggle flat view mode
  void toggleFlatView() {
    _hasToggledFlatView = true;
    final nextValue = !state.flatViewEnabled;
    emit(state.copyWith(flatViewEnabled: nextValue));
    unawaited(_saveBoolPreference(_flatViewKey, nextValue));
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
    final nextCategory = learned ?? GroceryCategory.other;

    if (nextCategory != state.selectedCategory ||
        nextSuggestedText != state.suggestedText ||
        nextSuggestionConfidence != state.suggestionConfidence) {
      emit(
        state.copyWith(
          selectedCategory: nextCategory,
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
