import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shopping_item.dart';

class FirestoreShoppingRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreShoppingRepository(this.firestore, {required this.userId});

  CollectionReference<Map<String, dynamic>> get _col =>
      firestore.collection('users').doc(userId).collection('shopping');

  Future<List<ShoppingItem>> loadItems() async {
    final snap = await _col.get();
    return snap.docs
        .map((d) => ShoppingItem.fromMap(d.data()..['id'] = d.id))
        .toList();
  }

  Future<void> saveItem(ShoppingItem item) async {
    final data = item.toMap();
    final id = item.id;
    await _col.doc(id).set(data);
  }

  Future<void> deleteItem(String id) async {
    await _col.doc(id).delete();
  }
}
