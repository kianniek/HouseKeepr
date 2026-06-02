import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../cubits/shopping_cubit.dart';
import '../cubits/task_cubit.dart';
import '../models/grocery_item.dart';
import '../models/task.dart';

class FirestoreSyncService {
  final FirebaseFirestore firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _shoppingSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _householdTasksSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _rootTasksSub;

  FirestoreSyncService(this.firestore);

  Future<void> start(
    String userId,
    TaskCubit taskCubit,
    ShoppingCubit shoppingCubit, {
    String? householdId,
  }) async {
    // Await stop to ensure previous listeners are fully detatched
    await stop();
    debugPrint(
      'FirestoreSyncService START: userId=$userId householdId=$householdId',
    );

    // 1. User Tasks Listener
    final tasksCol = firestore
        .collection('users')
        .doc(userId)
        .collection('tasks');

    _tasksSub = tasksCol.snapshots().listen(
      (snap) {
        debugPrint(
          'FirestoreSyncService: User tasks snapshot received. Docs: ${snap.docs.length}',
        );
        final serverTasks = snap.docs.map((d) {
          final m = Map<String, dynamic>.from(d.data());
          m['id'] = d.id;
          final ts = d.data()['serverUpdateTimestamp'];
          if (ts is Timestamp) {
            m['lastSyncedAt'] = ts;
            m['serverVersion'] = ts.millisecondsSinceEpoch;
          }
          final t = Task.fromMap(m);
          return t.copyWith(syncStatus: SyncStatus.synced);
        }).toList();

        _mergeAndEmit(taskCubit, serverTasks: serverTasks, source: 'user');
      },
      onError: (e) {
        debugPrint('FirestoreSyncService ERROR (User Tasks): $e');
      },
    );

    // 2. Shopping Listener (use household groceries if available, otherwise user groceries)
    if (householdId != null && householdId.isNotEmpty) {
      final shoppingCol = firestore
          .collection('households')
          .doc(householdId)
          .collection('groceries');
      _shoppingSub = shoppingCol.snapshots().listen(
        (snap) {
          debugPrint(
            'FirestoreSyncService: Household groceries snapshot received. Docs: ${snap.docs.length}',
          );
          final items = snap.docs.map((d) {
            final m = Map<String, dynamic>.from(d.data());
            m['id'] = d.id;
            final ts = d.data()['serverUpdateTimestamp'];
            if (ts is Timestamp) {
              m['serverVersion'] = ts.millisecondsSinceEpoch;
            }
            return GroceryItem.fromMap(m);
          }).toList();
          shoppingCubit.syncRemoteItems(items);
        },
        onError: (e) {
          debugPrint('FirestoreSyncService ERROR (Household Groceries): $e');
        },
      );
    } else {
      // Fallback to user groceries if no household (should not happen in normal flow)
      final shoppingCol = firestore
          .collection('users')
          .doc(userId)
          .collection('groceries');
      _shoppingSub = shoppingCol.snapshots().listen(
        (snap) {
          debugPrint(
            'FirestoreSyncService: User groceries snapshot received. Docs: ${snap.docs.length}',
          );
          final items = snap.docs.map((d) {
            final m = Map<String, dynamic>.from(d.data());
            m['id'] = d.id;
            final ts = d.data()['serverUpdateTimestamp'];
            if (ts is Timestamp) {
              m['serverVersion'] = ts.millisecondsSinceEpoch;
            }
            return GroceryItem.fromMap(m);
          }).toList();
          shoppingCubit.syncRemoteItems(items);
        },
        onError: (e) {
          debugPrint('FirestoreSyncService ERROR (User Groceries): $e');
        },
      );
    }

    // 3. Household Tasks Listener
    if (householdId != null && householdId.isNotEmpty) {
      final hhCol = firestore
          .collection('households')
          .doc(householdId)
          .collection('tasks');

      debugPrint('FirestoreSyncService: Listening to $hhCol');

      _householdTasksSub = hhCol.snapshots().listen(
        (snap) {
          debugPrint(
            'FirestoreSyncService: Household tasks snapshot received. Docs: ${snap.docs.length}',
          );
          final serverHouseholdTasks = snap.docs.map((d) {
            final m = Map<String, dynamic>.from(d.data());
            m['id'] = d.id;
            m['householdId'] = householdId;
            final ts = d.data()['serverUpdateTimestamp'];
            if (ts is Timestamp) {
              m['lastSyncedAt'] = ts;
              m['serverVersion'] = ts.millisecondsSinceEpoch;
            }
            final t = Task.fromMap(m);
            return t.copyWith(syncStatus: SyncStatus.synced);
          }).toList();

          _mergeAndEmit(
            taskCubit,
            serverTasks: serverHouseholdTasks,
            source: 'household',
            householdId: householdId,
          );
        },
        onError: (e) {
          debugPrint('FirestoreSyncService ERROR (Household Tasks): $e');
          // If this errors (e.g. Permission Denied), the stream dies.
          // You might consider a fallback query here if needed.
        },
      );
    }
  }

  // Helper to centralize merging logic and reduce code duplication
  void _mergeAndEmit(
    TaskCubit taskCubit, {
    required List<Task> serverTasks,
    required String source,
    String? householdId,
  }) {
    // We grab the current state from the Cubit to preserve tasks from the *other* source
    final currentState = taskCubit.state.tasks;

    // Identify which tasks we need to KEEP from the local state
    List<Task> preserved = [];
    if (source == 'user') {
      // If update is from User stream, keep Household tasks
      preserved = currentState.where((t) => t.householdId != null).toList();
    } else {
      // If update is from Household stream, keep User tasks
      preserved = currentState.where((t) => t.householdId == null).toList();
    }

    // Also keep any local-only pending tasks (that haven't synced yet)
    // to prevent them from being wiped out by an incoming server update.
    final pending = currentState
        .where(
          (t) =>
              t.syncStatus != SyncStatus.synced &&
              // Avoid duplicating if we just added it to 'preserved' above
              !preserved.any((p) => p.id == t.id),
        )
        .toList();

    final combinedMap = <String, Task>{};

    // 1. Add preserved tasks (from the other stream)
    for (final t in preserved) {
      combinedMap[t.id] = t;
    }

    // 2. Add pending local tasks
    for (final t in pending) {
      combinedMap[t.id] = t;
    }

    // 3. Add/Overwrite with new server data
    for (final t in serverTasks) {
      combinedMap[t.id] = t;
    }

    debugPrint(
      'FirestoreSyncService: Merging ($source). Preserved: ${preserved.length}, Server: ${serverTasks.length}, Total: ${combinedMap.length}',
    );

    taskCubit.replaceAll(combinedMap.values.toList());
  }

  Future<void> stop() async {
    debugPrint('FirestoreSyncService STOP');
    await _tasksSub?.cancel();
    _tasksSub = null;
    await _shoppingSub?.cancel();
    _shoppingSub = null;
    await _householdTasksSub?.cancel();
    _householdTasksSub = null;
    await _rootTasksSub?.cancel();
    _rootTasksSub = null;
  }
}
