import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:housekeepr/core/grocery_parser.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/models/grocery_category.dart';
import 'package:housekeepr/models/grocery_item.dart';
import 'package:housekeepr/repositories/grocery_repository.dart';
import 'package:housekeepr/services/shopping_products_service.dart';
import 'package:housekeepr/services/write_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

GroceryItem _item(
  String id, {
  bool checked = false,
  bool isDeleted = false,
  DateTime? deletedAt,
  DateTime? updatedAt,
}) {
  final created = DateTime.now().subtract(const Duration(days: 30));
  return GroceryItem(
    id: id,
    name: 'Item $id',
    createdAt: created,
    updatedAt: updatedAt ?? created,
    checked: checked,
    checkedAt: checked ? created : null,
    isDeleted: isDeleted,
    deletedAt: deletedAt,
  );
}

void main() {
  late Directory tempDir;
  late GroceryRepository repo;
  late List<QueueOp> ops;
  late WriteQueue queue;
  final cubits = <ShoppingCubit>[];

  Future<ShoppingCubit> createCubit({bool withQueue = true}) async {
    final cubit = ShoppingCubit(repo);
    cubits.add(cubit);
    await cubit.initializationFuture;
    if (withQueue) cubit.attachWriteQueue(queue);
    await pumpEventQueue();
    return cubit;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('housekeepr_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('groceries');
    await Hive.openBox('groceries_meta');
    repo = GroceryRepository();

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ShoppingProductsService.instance.init(prefs);
    await Hive.box('learning_products').clear();
    ops = [];
    queue = WriteQueue(prefs)
      ..attachOpBuilder(
        (op) =>
            () async => ops.add(op),
      );
  });

  tearDown(() async {
    for (final c in cubits) {
      await c.close();
    }
    cubits.clear();
    await Hive.deleteFromDisk();
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('GroceryItem.deletedAt', () {
    test('round-trips through toMap/fromMap', () {
      final at = DateTime(2026, 11, 1, 12, 30);
      final item = _item('a', isDeleted: true, deletedAt: at);
      final copy = GroceryItem.fromMap(item.toMap());
      expect(copy.deletedAt, at);
      expect(copy, item);
    });

    test('copyWith can clear deletedAt', () {
      final item = _item('a', isDeleted: true, deletedAt: DateTime.now());
      expect(item.copyWith(deletedAt: null).deletedAt, isNull);
      expect(item.copyWith().deletedAt, item.deletedAt);
    });
  });

  group('soft delete + undo', () {
    test(
      'deleteItem hides item, lists it as recently deleted, no hard delete',
      () async {
        await repo.saveItems([_item('a'), _item('b')]);
        final cubit = await createCubit();

        final deleted = await cubit.deleteItem('a');
        await pumpEventQueue();

        expect(deleted, isNotNull);
        expect(deleted!.isDeleted, isTrue);
        expect(deleted.deletedAt, isNotNull);
        expect(cubit.state.items.map((i) => i.id), ['b']);
        expect(cubit.state.recentlyDeleted.map((i) => i.id), ['a']);
        // Tombstone kept locally.
        expect(repo.loadItems().any((i) => i.id == 'a' && i.isDeleted), isTrue);
        // Only a save (tombstone) op, no remote hard delete.
        expect(ops.map((o) => o.type), [QueueOpType.saveGrocery]);
      },
    );

    test('restoreItems keeps checked state by default (undo)', () async {
      await repo.saveItems([_item('a', checked: true)]);
      final cubit = await createCubit();

      await cubit.deleteItem('a');
      await cubit.restoreItems(['a']);

      final restored = cubit.state.items.single;
      expect(restored.isDeleted, isFalse);
      expect(restored.deletedAt, isNull);
      expect(restored.checked, isTrue);
      expect(cubit.state.recentlyDeleted, isEmpty);
    });

    test('restoreItems(uncheck: true) restores unchecked', () async {
      await repo.saveItems([_item('a', checked: true)]);
      final cubit = await createCubit();

      await cubit.deleteItem('a');
      await cubit.restoreItems(['a'], uncheck: true);

      final restored = cubit.state.items.single;
      expect(restored.checked, isFalse);
      expect(restored.checkedAt, isNull);
    });

    test('deleteItem(deletedAt:) preserves original deletion time', () async {
      final original = DateTime.now().subtract(const Duration(days: 3));
      await repo.saveItems([_item('a')]);
      final cubit = await createCubit();

      await cubit.deleteItem('a', deletedAt: original);
      expect(cubit.state.recentlyDeleted.single.deletedAt, original);
    });

    test(
      'clearCheckedItems returns ids and all land in recentlyDeleted',
      () async {
        await repo.saveItems([
          _item('a', checked: true),
          _item('b', checked: true),
          _item('c'),
        ]);
        final cubit = await createCubit();

        final ids = await cubit.clearCheckedItems();
        expect(ids.toSet(), {'a', 'b'});
        expect(cubit.state.items.map((i) => i.id), ['c']);
        expect(cubit.state.recentlyDeleted.map((i) => i.id).toSet(), {
          'a',
          'b',
        });

        await cubit.restoreItems(ids);
        expect(cubit.state.items.length, 3);
        expect(cubit.state.items.where((i) => i.checked).length, 2);
      },
    );

    test(
      'permanentlyDelete removes locally and enqueues remote delete',
      () async {
        await repo.saveItems([_item('a')]);
        final cubit = await createCubit();
        await cubit.deleteItem('a');
        ops.clear();

        await cubit.permanentlyDelete(['a']);
        await pumpEventQueue();

        expect(repo.loadItems(), isEmpty);
        expect(cubit.state.recentlyDeleted, isEmpty);
        expect(ops.map((o) => o.type), [QueueOpType.deleteGrocery]);
      },
    );
  });

  group('retention purge', () {
    test('purges tombstones older than 7 days, keeps newer ones', () async {
      final now = DateTime.now();
      await repo.saveItems([
        _item('active'),
        _item(
          'old',
          isDeleted: true,
          deletedAt: now.subtract(const Duration(days: 8)),
          updatedAt: now.subtract(const Duration(days: 8)),
        ),
        _item(
          'recent',
          isDeleted: true,
          deletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
        // Legacy tombstone without deletedAt -> falls back to updatedAt.
        _item(
          'legacy',
          isDeleted: true,
          updatedAt: now.subtract(const Duration(days: 10)),
        ),
      ]);

      final cubit = await createCubit();

      final remaining = repo.loadItems().map((i) => i.id).toSet();
      expect(remaining, {'active', 'recent'});
      expect(cubit.state.recentlyDeleted.map((i) => i.id), ['recent']);
      expect(
        ops
            .where((o) => o.type == QueueOpType.deleteGrocery)
            .map((o) => o.id)
            .toSet(),
        {'old', 'legacy'},
      );
    });

    test(
      'syncRemoteItems does not re-insert expired remote tombstones',
      () async {
        final cubit = await createCubit();
        final old = DateTime.now().subtract(const Duration(days: 9));

        cubit.syncRemoteItems([
          _item('remoteOld', isDeleted: true, deletedAt: old, updatedAt: old),
          _item('remoteActive'),
        ]);
        await pumpEventQueue();

        expect(repo.loadItems().map((i) => i.id), ['remoteActive']);
        expect(cubit.state.recentlyDeleted, isEmpty);
        expect(
          ops
              .where((o) => o.type == QueueOpType.deleteGrocery)
              .map((o) => o.id),
          ['remoteOld'],
        );
      },
    );

    test('isExpiredTombstone ignores active items', () {
      final old = DateTime.now().subtract(const Duration(days: 30));
      expect(
        ShoppingCubit.isExpiredTombstone(_item('a', updatedAt: old)),
        isFalse,
      );
    });
  });

  group('ShoppingCubit view preference persistence', () {
    test('persists aisleModeEnabled and flatViewEnabled across restarts', () async {
      final cubit = await createCubit(withQueue: false);
      expect(cubit.state.aisleModeEnabled, isFalse);
      expect(cubit.state.flatViewEnabled, isFalse);

      cubit.toggleAisleMode();
      cubit.toggleFlatView();
      await pumpEventQueue();

      expect(cubit.state.aisleModeEnabled, isTrue);
      expect(cubit.state.flatViewEnabled, isTrue);

      final restarted = await createCubit(withQueue: false);
      expect(restarted.state.aisleModeEnabled, isTrue);
      expect(restarted.state.flatViewEnabled, isTrue);
    });
  });

  group('Phase 1 state & quantity fixes', () {
    test('GroceryItem.copyWith can clear unit to null', () {
      final item = _item('a').copyWith(unit: 'kg');
      expect(item.unit, 'kg');
      expect(item.copyWith(unit: null).unit, isNull);
      expect(item.copyWith().unit, 'kg');
    });

    test('ShoppingState.copyWith can clear suggestedText and error', () {
      const state = ShoppingState(
        suggestedText: 'Milk',
        error: 'Network error',
      );
      final cleared = state.copyWith(suggestedText: null, error: null);
      expect(cleared.suggestedText, isNull);
      expect(cleared.error, isNull);
    });

    test('updateQuantityAndUnit preserves 0.5 and can clear unit', () async {
      await repo.saveItems([_item('a').copyWith(quantity: 2, unit: 'kg')]);
      final cubit = await createCubit();

      await cubit.updateQuantityAndUnit('a', 0.5, null);
      final updated = cubit.state.items.single;
      expect(updated.quantity, 0.5);
      expect(updated.unit, isNull);
    });

    test('addItem duplicate merge clears checkedAt when unchecking', () async {
      final checked = _item('a', checked: true).copyWith(name: 'Milk');
      await repo.saveItems([checked]);
      final cubit = await createCubit();

      await cubit.addItem('Milk');
      final merged = cubit.state.items.single;
      expect(merged.checked, isFalse);
      expect(merged.checkedAt, isNull);
      expect(merged.quantity, 2.0);
    });

    test('updateDraftText clears suggestedText and resets category', () async {
      final cubit = await createCubit(withQueue: false);
      cubit.setManualCategory(GroceryCategory.dairy, 'Milk');
      expect(cubit.state.selectedCategory, GroceryCategory.dairy);

      cubit.updateDraftText('');
      expect(cubit.state.selectedCategory, GroceryCategory.other);
      expect(cubit.state.suggestedText, isNull);
    });
  });

  group('Phase 3 item editing, uncheck-all, and parser integration', () {
    test('updateItemDetails updates name, note, quantity, unit, and category',
        () async {
      await repo.saveItems([
        _item('a').copyWith(
          name: 'Milk',
          note: 'Old note',
          quantity: 1,
          unit: 'pak',
          category: GroceryCategory.dairy,
        ),
      ]);
      final cubit = await createCubit();

      await cubit.updateItemDetails(
        'a',
        name: 'oat milk',
        note: '  Barista  ',
        quantity: 2.5,
        unit: 'L',
        category: GroceryCategory.beverages,
      );

      final updated = cubit.state.items.single;
      expect(updated.name, 'Oat Milk');
      expect(updated.note, 'Barista');
      expect(updated.quantity, 2.5);
      expect(updated.unit, 'L');
      expect(updated.category, GroceryCategory.beverages);

      // Verify clearing note and unit to null works
      await cubit.updateItemDetails(
        'a',
        name: 'Oat Milk',
        note: '   ',
        quantity: 1,
        unit: null,
        category: GroceryCategory.beverages,
      );
      final cleared = cubit.state.items.single;
      expect(cleared.note, isNull);
      expect(cleared.unit, isNull);
    });

    test('uncheckAllCompleted and recheckItems round-trip', () async {
      await repo.saveItems([
        _item('a', checked: true),
        _item('b', checked: true),
        _item('c', checked: false),
      ]);
      final cubit = await createCubit();

      final ids = await cubit.uncheckAllCompleted();
      expect(ids.toSet(), {'a', 'b'});
      expect(cubit.state.items.every((i) => !i.checked), isTrue);
      expect(cubit.state.items.every((i) => i.checkedAt == null), isTrue);

      await cubit.recheckItems(ids);
      final byId = {for (final i in cubit.state.items) i.id: i};
      expect(byId['a']!.checked, isTrue);
      expect(byId['b']!.checked, isTrue);
      expect(byId['c']!.checked, isFalse);
    });

    test('GroceryParser.parseLine integrates with ShoppingCubit.addItem',
        () async {
      final cubit = await createCubit();
      final parsed = GroceryParser.parseLine('2 pakken melk');
      await cubit.addItem(
        parsed.name,
        note: parsed.note,
        quantity: parsed.quantity,
        unit: parsed.unit,
        category: parsed.category,
      );

      final added = cubit.state.items.single;
      expect(added.name, 'Melk');
      expect(added.quantity, 2.0);
      expect(added.unit, 'pak');
    });
  });

  group('Learning system integration', () {
    test('addItem applies learned category, quantity, and unit when omitted',
        () async {
      await ShoppingProductsService.instance.learnProductUsage(
        'Halfvolle Melk',
        category: GroceryCategory.dairy,
        quantity: 2.0,
        unit: 'L',
      );
      final cubit = await createCubit();

      await cubit.addItem('halfvolle melk');
      final item = cubit.state.items.single;
      expect(item.category, GroceryCategory.dairy);
      expect(item.quantity, 2.0);
      expect(item.unit, 'L');
    });

    test('addItem respects explicit quantity/unit over learned defaults',
        () async {
      await ShoppingProductsService.instance.learnProductUsage(
        'Halfvolle Melk',
        category: GroceryCategory.dairy,
        quantity: 2.0,
        unit: 'L',
      );
      final cubit = await createCubit();

      await cubit.addItem('halfvolle melk', quantity: 1.0, unit: 'pak');
      final item = cubit.state.items.single;
      expect(item.quantity, 1.0);
      expect(item.unit, 'pak');
    });

    test('checking off and editing an item records usage for future adds',
        () async {
      final cubit = await createCubit();
      await cubit.addItem('Koffiebonen', category: GroceryCategory.coffeeAndTea);
      final id = cubit.state.items.single.id;

      await cubit.updateQuantityAndUnit(id, 500, 'g');
      await cubit.toggleItem(id);
      await pumpEventQueue();

      final usual = ShoppingProductsService.instance.getUsualQuantityAndUnit(
        'koffiebonen',
      );
      expect(usual?.quantity, 500.0);
      expect(usual?.unit, 'g');
      expect(
        ShoppingProductsService.instance.getCategoryForProduct('koffiebonen'),
        GroceryCategory.coffeeAndTea,
      );
    });
  });

  group('recipe parent containers', () {
    test('addRecipe creates parent and isolated child ingredients', () async {
      final cubit = await createCubit();

      // Pre-existing standalone item with the same name as a recipe ingredient
      await cubit.addItem('Spaghetti', quantity: 500, unit: 'g');

      final recipe = await cubit.addRecipe(
        title: 'Spaghetti Carbonara',
        url: 'https://www.ah.nl/allerhande/recept/R-R12345/carbonara',
        sourceName: 'Albert Heijn',
        servings: 4,
        ingredients: const [
          ParsedGroceryItem(
            name: 'Spaghetti',
            quantity: 400,
            unit: 'g',
            category: GroceryCategory.international,
          ),
          ParsedGroceryItem(
            name: 'Eieren',
            quantity: 4,
            category: GroceryCategory.dairy,
          ),
        ],
      );

      expect(recipe.isRecipe, isTrue);
      expect(recipe.recipeSource, 'Albert Heijn');
      expect(recipe.recipeServings, 4);

      // Standalone Spaghetti should remain 500g (not merged)
      final standalone = cubit.state.items.firstWhere(
        (i) => !i.isRecipe && i.parentRecipeId == null,
      );
      expect(standalone.quantity, 500);

      final children = cubit.state.items
          .where((i) => i.parentRecipeId == recipe.id)
          .toList();
      expect(children.length, 2);
      expect(children.map((c) => c.name), containsAll(['Spaghetti', 'Eieren']));
    });

    test('toggling recipe parent toggles all children and vice versa', () async {
      final cubit = await createCubit();
      final recipe = await cubit.addRecipe(
        title: 'Pannenkoeken',
        url: 'https://www.jumbo.com/recepten/pannenkoeken',
        sourceName: 'Jumbo',
        ingredients: const [
          ParsedGroceryItem(
            name: 'Bloem',
            quantity: 250,
            unit: 'g',
            category: GroceryCategory.baking,
          ),
          ParsedGroceryItem(
            name: 'Melk',
            quantity: 500,
            unit: 'ml',
            category: GroceryCategory.dairy,
          ),
        ],
      );

      // Toggle parent -> checks both children
      await cubit.toggleItem(recipe.id);
      var parent = cubit.state.items.firstWhere((i) => i.id == recipe.id);
      var children = cubit.state.items
          .where((i) => i.parentRecipeId == recipe.id)
          .toList();
      expect(parent.checked, isTrue);
      expect(children.every((c) => c.checked), isTrue);

      // Uncheck one child -> unchecks parent too
      await cubit.toggleItem(children.first.id);
      parent = cubit.state.items.firstWhere((i) => i.id == recipe.id);
      expect(parent.checked, isFalse);

      // Re-check that child -> all children checked -> parent becomes checked
      await cubit.toggleItem(children.first.id);
      parent = cubit.state.items.firstWhere((i) => i.id == recipe.id);
      expect(parent.checked, isTrue);
    });

    test('deleteRecipeWithChildren soft-deletes and restoreItems restores group',
        () async {
      final cubit = await createCubit();
      final recipe = await cubit.addRecipe(
        title: 'Appeltaart',
        url: 'https://rutgerbakt.nl/appeltaart',
        sourceName: 'rutgerbakt.nl',
        ingredients: const [
          ParsedGroceryItem(
            name: 'Appels',
            quantity: 6,
            category: GroceryCategory.fruit,
          ),
          ParsedGroceryItem(
            name: 'Boter',
            quantity: 200,
            unit: 'g',
            category: GroceryCategory.dairy,
          ),
        ],
      );

      final deleted = await cubit.deleteRecipeWithChildren(recipe.id);
      expect(deleted.length, 3);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.recentlyDeleted.length, 3);

      await cubit.restoreItems(deleted.map((i) => i.id).toList());
      expect(cubit.state.items.length, 3);
      expect(cubit.state.recentlyDeleted, isEmpty);
    });
  });
}
