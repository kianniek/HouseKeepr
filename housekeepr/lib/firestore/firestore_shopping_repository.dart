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
    final snap = await _col.get();
    return snap.docs
        .map((d) => ShoppingItem.fromMap(d.data()..['id'] = d.id))
        .toList();
  }

  @override
  Future<void> saveItem(ShoppingItem item) async {
    final data = item.toMap();
    final id = item.id;
    // Add a server-side timestamp so clients can track server version and
    // resolve conflicts deterministically when needed.
    data['serverUpdateTimestamp'] = FieldValue.serverTimestamp();
    await _col.doc(id).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteItem(String id) async {
    await _col.doc(id).delete();
  }
}
