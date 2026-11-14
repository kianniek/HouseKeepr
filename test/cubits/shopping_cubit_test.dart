import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/models/grocery_item.dart';
import 'package:housekeepr/repositories/grocery_repository.dart';
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
}
