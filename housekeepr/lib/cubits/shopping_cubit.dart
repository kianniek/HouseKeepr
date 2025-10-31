import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/shopping_item.dart';
import '../repositories/shopping_repository.dart';
// firestore_shopping_repository import removed — remote interface used instead
import '../firestore/remote_shopping_repository.dart';
import '../core/settings_repository.dart';
import '../core/sync_mode.dart';
import '../services/write_queue.dart';

part 'shopping_state.dart';

class ShoppingCubit extends Cubit<ShoppingState> {
  final ShoppingRepository repo;
  RemoteShoppingRepository? remoteRepo;
  final SettingsRepository? settings;
  WriteQueue? writeQueue;

  ShoppingCubit(this.repo, {this.settings, this.writeQueue})
    : super(ShoppingState.initial()) {
    load();
  }

  void load() {
    final items = repo.loadItems();
    emit(state.copyWith(items: items));
  }

  Future<void> addItem(ShoppingItem item) async {
    final list = List<ShoppingItem>.from(state.items)..add(item);
    await repo.saveItems(list);
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          final payload = item.toMap();
          try {
            payload['_isNew'] = true;
          } catch (_) {}
          writeQueue!.enqueueOp(
            QueueOp(
              type: QueueOpType.saveShopping,
              id: item.id,
              payload: payload,
            ),
          );
        } else {
          Future<void> op() => remoteRepo!.saveItem(item);
          unawaited(op());
        }
      }
    }
    emit(state.copyWith(items: list));
  }

  Future<void> updateItem(ShoppingItem item) async {
    final prev = state.items.firstWhere(
      (i) => i.id == item.id,
      orElse: () => item,
    );
    final list = state.items.map((i) => i.id == item.id ? item : i).toList();
    await repo.saveItems(list);
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          final payload = item.toMap();
          try {
            payload['_previous'] = prev.toMap();
          } catch (_) {}
          writeQueue!.enqueueOp(
            QueueOp(
              type: QueueOpType.saveShopping,
              id: item.id,
              payload: payload,
            ),
          );
        } else {
          Future<void> op() => remoteRepo!.saveItem(item);
          unawaited(op());
        }
      }
    }
    emit(state.copyWith(items: list));
  }

  Future<void> replaceAll(List<ShoppingItem> items) async {
    await repo.saveItems(items);
    emit(state.copyWith(items: items));
  }

  Future<void> deleteItem(String id) async {
    final prev = state.items.firstWhere((i) => i.id == id);
    final list = List<ShoppingItem>.from(state.items)
      ..removeWhere((i) => i.id == id);
    await repo.saveItems(list);
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          final payload = <String, dynamic>{};
          try {
            payload['_previous'] = prev.toMap();
          } catch (_) {}
          writeQueue!.enqueueOp(
            QueueOp(type: QueueOpType.deleteShopping, id: id, payload: payload),
          );
        } else {
          Future<void> op() => remoteRepo!.deleteItem(id);
          unawaited(op());
        }
      }
    }
    emit(state.copyWith(items: list));
  }

  /// Attach or replace the WriteQueue so this cubit can enqueue operations.
  void attachWriteQueue(WriteQueue? wq) {
    writeQueue = wq;
  }

  /// Remove a shopping item from the local store without enqueueing remote
  /// operations. Used to rollback optimistic creates when remote persistence
  /// fails permanently.
  Future<void> removeLocalItem(String id) async {
    try {
      final list = List<ShoppingItem>.from(state.items)
        ..removeWhere((i) => i.id == id);
      await repo.saveItems(list);
      emit(state.copyWith(items: list));
    } catch (_) {}
  }

  /// Restore an item from a serialized map into the local store without
  /// re-enqueueing remote ops. Used by the write-queue failure handler.
  Future<void> restoreItemFromMap(Map<String, dynamic> m) async {
    try {
      final it = ShoppingItem.fromMap(Map<String, dynamic>.from(m));
      final list = List<ShoppingItem>.from(state.items);
      final idx = list.indexWhere((x) => x.id == it.id);
      if (idx != -1) {
        list[idx] = it;
      } else {
        list.add(it);
      }
      await repo.saveItems(list);
      emit(state.copyWith(items: list));
    } catch (_) {}
  }

  void setRemoteRepository(RemoteShoppingRepository? r) {
    remoteRepo = r;
  }
}

// helper for fire-and-forget
void unawaited(Future<void> f) {}
