import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/task.dart';
import 'remote_task_repository.dart';

class FirestoreTaskRepository extends BaseFirestoreTaskRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreTaskRepository(this.firestore, {required this.userId});

  @override
  CollectionReference<Map<String, dynamic>> get tasksCollection =>
      firestore.collection('users').doc(userId).collection('tasks');

  @override
  String get collectionLabel => 'users/$userId/tasks';

  Future<List<Task>> loadTasks() async {
    try {
      debugPrint('FirestoreTaskRepository.loadTasks: reading $collectionLabel');
      final snap = await tasksCollection.get();
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
}
