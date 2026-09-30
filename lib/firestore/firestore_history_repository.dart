import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';

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
    try {
      debugPrint(
        'FirestoreHistoryRepository.saveRecord: users/$userId/history/${r.id}',
      );
      await _col.doc(r.id).set(data);
    } catch (e) {
      debugPrint('FirestoreHistoryRepository.saveRecord failed: $e');
      rethrow;
    }
  }

  Future<void> deleteRecord(String id) async {
    try {
      debugPrint(
        'FirestoreHistoryRepository.deleteRecord: users/$userId/history/$id',
      );
      await _col.doc(id).delete();
    } catch (e) {
      debugPrint('FirestoreHistoryRepository.deleteRecord failed: $e');
      rethrow;
    }
  }

  Future<List<CompletionRecord>> loadAll() async {
    try {
      debugPrint('FirestoreHistoryRepository.loadAll: users/$userId/history');
      final snap = await _col.get();
      return snap.docs
          .map((d) => CompletionRecord.fromMap(d.data()..['id'] = d.id))
          .toList();
    } catch (e) {
      debugPrint('FirestoreHistoryRepository.loadAll failed: $e');
      rethrow;
    }
  }
}
