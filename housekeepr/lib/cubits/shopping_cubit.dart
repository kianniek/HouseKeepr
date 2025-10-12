import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/shopping_item.dart';
import '../repositories/shopping_repository.dart';
import '../firestore/firestore_shopping_repository.dart';
import '../core/settings_repository.dart';
import '../core/sync_mode.dart';
import '../services/write_queue.dart';

part 'shopping_state.dart';

class ShoppingCubit extends Cubit<ShoppingState> {
  final ShoppingRepository repo;
  FirestoreShoppingRepository? remoteRepo;
  final SettingsRepository? settings;
  final WriteQueue? writeQueue;

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
          writeQueue!.enqueueOp(
            QueueOp(
              type: QueueOpType.saveShopping,
              id: item.id,
              payload: item.toMap(),
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
    final list = state.items.map((i) => i.id == item.id ? item : i).toList();
    await repo.saveItems(list);
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          writeQueue!.enqueueOp(
            QueueOp(
              type: QueueOpType.saveShopping,
              id: item.id,
              payload: item.toMap(),
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
    final list = List<ShoppingItem>.from(state.items)
      ..removeWhere((i) => i.id == id);
    await repo.saveItems(list);
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          writeQueue!.enqueueOp(
            QueueOp(type: QueueOpType.deleteShopping, id: id),
          );
        } else {
          Future<void> op() => remoteRepo!.deleteItem(id);
          unawaited(op());
        }
      }
    }
    emit(state.copyWith(items: list));
  }

  void setRemoteRepository(FirestoreShoppingRepository? r) {
    remoteRepo = r;
  }
}

// helper for fire-and-forget
void unawaited(Future<void> f) {}
