import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/task.dart';

/// Small interface to abstract remote task persistence for testing.
abstract class RemoteTaskRepository {
  Future<void> saveTask(Task task);
  Future<void> deleteTask(String id);
}

/// Shared Firestore implementation for [RemoteTaskRepository] backed by a
/// specific tasks collection path.
abstract class BaseFirestoreTaskRepository implements RemoteTaskRepository {
  CollectionReference<Map<String, dynamic>> get tasksCollection;
  String get collectionLabel;

  @override
  Future<void> saveTask(Task task) async {
    final data = Map<String, dynamic>.from(task.toMap());
    if (task.deadline != null) {
      data['deadline'] = Timestamp.fromDate(task.deadline!.toUtc());
    }
    data['serverUpdateTimestamp'] = FieldValue.serverTimestamp();
    final id = task.id;
    try {
      debugPrint('$runtimeType.saveTask: $collectionLabel/$id');
      await tasksCollection.doc(id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('$runtimeType.saveTask failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      debugPrint('$runtimeType.deleteTask: $collectionLabel/$id');
      await tasksCollection.doc(id).delete();
    } catch (e) {
      debugPrint('$runtimeType.deleteTask failed: $e');
      rethrow;
    }
  }
}
