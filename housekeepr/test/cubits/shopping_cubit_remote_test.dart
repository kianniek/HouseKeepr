import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/models/shopping_item.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';

import '../test_utils.dart';

import 'package:housekeepr/firestore/remote_shopping_repository.dart';
import 'package:housekeepr/services/write_queue.dart' as wq;

class FakeRemoteShoppingRepo implements RemoteShoppingRepository {
  int saveCalls = 0;
  int deleteCalls = 0;
  final List<ShoppingItem> saved = [];

  Future<void> saveItem(ShoppingItem t) async {
    saveCalls++;
    saved.add(t);
  }

  Future<void> deleteItem(String id) async {
    deleteCalls++;
  }
}

class CapturingWriteQueue extends wq.WriteQueue {
  CapturingWriteQueue(prefs) : super(prefs);
  wq.QueueOp? lastOp;
  @override
  void enqueueOp(wq.QueueOp op) {
    lastOp = op;
    super.enqueueOp(op);
  }
}

void main() {
  test(
    'ShoppingCubit calls remoteRepo.saveItem when sync and no writeQueue',
    () async {
      final prefs = InMemoryPrefs();
      final repo = ShoppingRepository(prefs);
      final settings = SettingsRepository(prefs);
      await settings.setSyncMode(SyncMode.sync);

      final cubit = ShoppingCubit(repo, settings: settings);

      final fakeRemote = FakeRemoteShoppingRepo();
      cubit.setRemoteRepository(fakeRemote);

      final item = ShoppingItem(id: 's1', name: 'Remote');
      await cubit.addItem(item);

      // local state updated
      expect(cubit.state.items.any((t) => t.id == 's1'), isTrue);
      // remote save should have been invoked
      expect(fakeRemote.saveCalls, 1);
    },
  );

  test('ShoppingCubit enqueues op when writeQueue provided', () async {
    final prefs = InMemoryPrefs();
    final repo = ShoppingRepository(prefs);
    final settings = SettingsRepository(prefs);
    await settings.setSyncMode(SyncMode.sync);

    final prefs2 = InMemoryPrefs();
    final fakeWrite = CapturingWriteQueue(prefs2);
    final cubit = ShoppingCubit(
      repo,
      settings: settings,
      writeQueue: fakeWrite,
    );

    final fakeRemote = FakeRemoteShoppingRepo();
    cubit.setRemoteRepository(fakeRemote);

    final item = ShoppingItem(id: 's2', name: 'Queued');
    await cubit.addItem(item);

    // local state updated
    expect(cubit.state.items.any((t) => t.id == 's2'), isTrue);
    // remote should not be called directly
    expect(fakeRemote.saveCalls, 0);
    // writeQueue should have an op
    expect(fakeWrite.lastOp, isNotNull);
    expect(fakeWrite.lastOp!.type, wq.QueueOpType.saveShopping);
    expect(fakeWrite.lastOp!.id, 's2');
  });
}
