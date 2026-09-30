import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/task.dart';
import 'remote_task_repository.dart';

class FirestoreHouseholdTaskRepository implements RemoteTaskRepository {
  final FirebaseFirestore firestore;
  final String householdId;

  FirestoreHouseholdTaskRepository(this.firestore, {required this.householdId});

  CollectionReference<Map<String, dynamic>> get _col =>
      firestore.collection('households').doc(householdId).collection('tasks');

  @override
  Future<void> saveTask(Task task) async {
    final data = Map<String, dynamic>.from(task.toMap());
    if (task.deadline != null) {
      data['deadline'] = fs.Timestamp.fromDate(task.deadline!.toUtc());
    }
    data['serverUpdateTimestamp'] = FieldValue.serverTimestamp();
    final id = task.id;
    try {
      debugPrint(
        'FirestoreHouseholdTaskRepository.saveTask: households/$householdId/tasks/$id',
      );
      await _col.doc(id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreHouseholdTaskRepository.saveTask failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      debugPrint(
        'FirestoreHouseholdTaskRepository.deleteTask: households/$householdId/tasks/$id',
      );
      await _col.doc(id).delete();
    } catch (e) {
      debugPrint('FirestoreHouseholdTaskRepository.deleteTask failed: $e');
      rethrow;
    }
  }
}
