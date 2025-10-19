import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import 'remote_task_repository.dart';

class FirestoreTaskRepository implements RemoteTaskRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreTaskRepository(this.firestore, {required this.userId});

  CollectionReference<Map<String, dynamic>> get _col =>
      firestore.collection('users').doc(userId).collection('tasks');

  Future<List<Task>> loadTasks() async {
    final snap = await _col.get();
    return snap.docs.map((d) => Task.fromMap(d.data()..['id'] = d.id)).toList();
  }

  @override
  Future<void> saveTask(Task task) async {
    final data = task.toMap();
    final id = task.id;
    await _col.doc(id).set(data);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _col.doc(id).delete();
  }
}
