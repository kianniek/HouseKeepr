import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../cubits/task_cubit.dart';
import '../cubits/shopping_cubit.dart';
import '../models/task.dart';
import '../models/shopping_item.dart';

class FirestoreSyncService {
  final FirebaseFirestore firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _shoppingSub;

  FirestoreSyncService(this.firestore);

  void start(String userId, TaskCubit taskCubit, ShoppingCubit shoppingCubit) {
    // Cancel existing subscriptions first
    stop();

    final tasksCol = firestore
        .collection('users')
        .doc(userId)
        .collection('tasks');
    _tasksSub = tasksCol.snapshots().listen((snap) {
      final tasks = snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        // mark server-origin tasks as synced locally
        final t = Task.fromMap(m);
        return t.copyWith(
          syncStatus: SyncStatus.synced,
          lastSyncedAt: DateTime.now().toUtc(),
        );
      }).toList();
      taskCubit.replaceAll(tasks);
    });

    final shoppingCol = firestore
        .collection('users')
        .doc(userId)
        .collection('shopping');
    _shoppingSub = shoppingCol.snapshots().listen((snap) {
      final items = snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        return ShoppingItem.fromMap(m);
      }).toList();
      shoppingCubit.replaceAll(items);
    });
  }

  Future<void> stop() async {
    await _tasksSub?.cancel();
    _tasksSub = null;
    await _shoppingSub?.cancel();
    _shoppingSub = null;
  }
}
