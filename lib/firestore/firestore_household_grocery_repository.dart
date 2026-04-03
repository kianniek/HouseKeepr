import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grocery_item.dart';

class FirestoreHouseholdGroceryRepository {
  final FirebaseFirestore firestore;
  final String householdId;

  FirestoreHouseholdGroceryRepository(
    this.firestore, {
    required this.householdId,
  });

  CollectionReference<Map<String, dynamic>> get _col => firestore
      .collection('households')
      .doc(householdId)
      .collection('groceries');

  Future<List<GroceryItem>> loadItems() async {
    try {
      debugPrint(
        'FirestoreHouseholdGroceryRepository.loadItems: households/$householdId/groceries',
      );
      final snap = await _col.get();
      return snap.docs
          .map((d) => GroceryItem.fromMap(d.data()..['id'] = d.id))
          .toList();
    } catch (e) {
      debugPrint('FirestoreHouseholdGroceryRepository.loadItems failed: $e');
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
        'FirestoreHouseholdGroceryRepository.saveItem: households/$householdId/groceries/$id',
      );
      await _col.doc(id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreHouseholdGroceryRepository.saveItem failed: $e');
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      debugPrint(
        'FirestoreHouseholdGroceryRepository.deleteItem: households/$householdId/groceries/$id',
      );
      await _col.doc(id).delete();
    } catch (e) {
      debugPrint('FirestoreHouseholdGroceryRepository.deleteItem failed: $e');
      rethrow;
    }
  }
}
