import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../models/completion_record.dart';

class FirestoreHistoryRepository {
  final fs.FirebaseFirestore firestore;
  final String userId;

  FirestoreHistoryRepository(this.firestore, {required this.userId});

  fs.CollectionReference<Map<String, dynamic>> get _col =>
      firestore.collection('users').doc(userId).collection('history');

  Future<void> saveRecord(CompletionRecord r) async {
    final data = Map<String, dynamic>.from(r.toMap());
    // createdAt -> Timestamp
    data['createdAt'] = fs.Timestamp.fromDate(r.createdAt.toUtc());
    await _col.doc(r.id).set(data);
  }

  Future<void> deleteRecord(String id) async {
    await _col.doc(id).delete();
  }

  Future<List<CompletionRecord>> loadAll() async {
    final snap = await _col.get();
    return snap.docs
        .map((d) => CompletionRecord.fromMap(d.data()..['id'] = d.id))
        .toList();
  }
}
