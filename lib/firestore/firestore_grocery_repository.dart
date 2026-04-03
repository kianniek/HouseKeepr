import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grocery_item.dart';

class FirestoreGroceryRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreGroceryRepository(this.firestore, {required this.userId});

  CollectionReference<Map<String, dynamic>> get _col =>
      firestore.collection('users').doc(userId).collection('groceries');

  Future<List<GroceryItem>> loadItems() async {
    try {
      debugPrint(
        'FirestoreGroceryRepository.loadItems: users/$userId/groceries',
      );
      final snap = await _col.get();
      return snap.docs
          .map((d) => GroceryItem.fromMap(d.data()..['id'] = d.id))
          .toList();
    } catch (e) {
      debugPrint('FirestoreGroceryRepository.loadItems failed: $e');
      rethrow;
    }
  }

  Future<void> saveItem(GroceryItem item) async {
    final data = item.toMap();
    final id = item.id;
    // Add a server-side timestamp so clients can track server version and
    // resolve conflicts deterministically when needed.
    data['serverUpdateTimestamp'] = FieldValue.serverTimestamp();
    try {
      debugPrint(
        'FirestoreGroceryRepository.saveItem: users/$userId/groceries/$id',
      );
      await _col.doc(id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreGroceryRepository.saveItem failed: $e');
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      debugPrint(
        'FirestoreGroceryRepository.deleteItem: users/$userId/groceries/$id',
      );
      await _col.doc(id).delete();
    } catch (e) {
      debugPrint('FirestoreGroceryRepository.deleteItem failed: $e');
      rethrow;
    }
  }
}
