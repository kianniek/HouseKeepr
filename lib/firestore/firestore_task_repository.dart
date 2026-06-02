import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/task.dart';
import 'remote_task_repository.dart';

class FirestoreTaskRepository implements RemoteTaskRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreTaskRepository(this.firestore, {required this.userId});

  CollectionReference<Map<String, dynamic>> get _col =>
      firestore.collection('users').doc(userId).collection('tasks');

  Future<List<Task>> loadTasks() async {
    try {
      debugPrint(
        'FirestoreTaskRepository.loadTasks: reading users/$userId/tasks',
      );
      final snap = await _col.get();
      return snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        // If serverUpdateTimestamp is present, surface it as lastSyncedAt so
        // Task.fromMap can parse it into DateTime. Also provide a numeric
        // serverVersion based on milliseconds since epoch for simple conflict
        // resolution heuristics.
        final ts = d.data()['serverUpdateTimestamp'];
        if (ts is Timestamp) {
          m['lastSyncedAt'] = ts;
          m['serverVersion'] = ts.millisecondsSinceEpoch;
        }
        return Task.fromMap(m);
      }).toList();
    } catch (e) {
      debugPrint('FirestoreTaskRepository.loadTasks failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveTask(Task task) async {
    final data = Map<String, dynamic>.from(task.toMap());
    // Convert deadline to Firestore Timestamp when present
    if (task.deadline != null) {
      data['deadline'] = fs.Timestamp.fromDate(task.deadline!.toUtc());
    }
    final id = task.id;
    // Add a server-side timestamp to help with conflict resolution and
    // server version tracking. Firestore resolves FieldValue.serverTimestamp
    // on the server; we'll read it back when loading.
    data['serverUpdateTimestamp'] = FieldValue.serverTimestamp();
    try {
      debugPrint('FirestoreTaskRepository.saveTask: users/$userId/tasks/$id');
      final docRef = _col.doc(id);
      await docRef.set(data, SetOptions(merge: true));

      // Attempt to read the written document to surface the resolved
      // serverUpdateTimestamp and compute a numeric serverVersion. This
      // helps downstream merge logic converge faster (snapshot listeners
      // will also pick this up, but reading here reduces race windows).
      try {
        final fresh = await docRef.get();
        final ts = fresh.data()?['serverUpdateTimestamp'];
        if (ts is Timestamp) {
          final sv = ts.millisecondsSinceEpoch;
          debugPrint(
            'FirestoreTaskRepository.saveTask: resolved serverVersion=$sv for $id',
          );
        }
      } catch (e) {
        // Non-fatal; snapshot listener should handle it eventually.
        debugPrint(
          'FirestoreTaskRepository.saveTask: post-write read failed: $e',
        );
      }
    } catch (e) {
      debugPrint('FirestoreTaskRepository.saveTask failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      debugPrint('FirestoreTaskRepository.deleteTask: users/$userId/tasks/$id');
      await _col.doc(id).delete();
    } catch (e) {
      debugPrint('FirestoreTaskRepository.deleteTask failed: $e');
      rethrow;
    }
  }
}
