import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shopping_item.dart';
import 'remote_shopping_repository.dart';

class FirestoreShoppingRepository implements RemoteShoppingRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreShoppingRepository(this.firestore, {required this.userId});

  CollectionReference<Map<String, dynamic>> get _col =>
      firestore.collection('users').doc(userId).collection('shopping');

  Future<List<ShoppingItem>> loadItems() async {
    try {
      debugPrint(
        'FirestoreShoppingRepository.loadItems: users/$userId/shopping',
      );
      final snap = await _col.get();
      return snap.docs
          .map((d) => ShoppingItem.fromMap(d.data()..['id'] = d.id))
          .toList();
    } catch (e) {
      debugPrint('FirestoreShoppingRepository.loadItems failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveItem(ShoppingItem item) async {
    final data = item.toMap();
    final id = item.id;
    // Add a server-side timestamp so clients can track server version and
    // resolve conflicts deterministically when needed.
    data['serverUpdateTimestamp'] = FieldValue.serverTimestamp();
    try {
      debugPrint(
        'FirestoreShoppingRepository.saveItem: users/$userId/shopping/$id',
      );
      await _col.doc(id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreShoppingRepository.saveItem failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteItem(String id) async {
    try {
      debugPrint(
        'FirestoreShoppingRepository.deleteItem: users/$userId/shopping/$id',
      );
      await _col.doc(id).delete();
    } catch (e) {
      debugPrint('FirestoreShoppingRepository.deleteItem failed: $e');
      rethrow;
    }
  }
}
