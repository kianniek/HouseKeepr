import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/task.dart';

/// Small interface to abstract remote task persistence for testing.
abstract class RemoteTaskRepository {
  Future<void> saveTask(Task task);
  Future<void> saveTasksBatch(List<Task> tasks);
  Future<void> deleteTask(String id);
}

/// Shared Firestore implementation for [RemoteTaskRepository] backed by a
/// specific tasks collection path.
abstract class BaseFirestoreTaskRepository implements RemoteTaskRepository {
  CollectionReference<Map<String, dynamic>> get tasksCollection;
  String get collectionLabel;

  Map<String, dynamic> _toFirestoreData(Task task) {
    final data = Map<String, dynamic>.from(task.toMap());
    if (task.deadline != null) {
      data['deadline'] = Timestamp.fromDate(task.deadline!.toUtc());
    }
    data['serverUpdateTimestamp'] = FieldValue.serverTimestamp();
    return data;
  }

  @override
  Future<void> saveTask(Task task) async {
    final data = _toFirestoreData(task);
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
  Future<void> saveTasksBatch(List<Task> tasks) async {
    if (tasks.isEmpty) return;
    const chunkSize = 500;
    try {
      for (var i = 0; i < tasks.length; i += chunkSize) {
        final end = (i + chunkSize < tasks.length) ? i + chunkSize : tasks.length;
        final chunk = tasks.sublist(i, end);
        final batch = tasksCollection.firestore.batch();
        for (final task in chunk) {
          batch.set(
            tasksCollection.doc(task.id),
            _toFirestoreData(task),
            SetOptions(merge: true),
          );
        }
        debugPrint(
          '$runtimeType.saveTasksBatch: $collectionLabel (${chunk.length} tasks)',
        );
        await batch.commit();
      }
    } catch (e) {
      debugPrint('$runtimeType.saveTasksBatch failed: $e');
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
