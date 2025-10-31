import 'package:cloud_firestore/cloud_firestore.dart' as fs;
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
    await _col.doc(id).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteTask(String id) async {
    await _col.doc(id).delete();
  }
}
