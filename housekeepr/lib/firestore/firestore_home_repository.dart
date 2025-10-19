import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/home.dart';
import 'remote_home_repository.dart';

class FirestoreHomeRepository implements RemoteHomeRepository {
  final FirebaseFirestore firestore;

  FirestoreHomeRepository(this.firestore);

  CollectionReference<Map<String, dynamic>> get _homes =>
      firestore.collection('homes');

  @override
  Future<void> createHome(Home home) async {
    final data = home.toMap();
    final id = home.id;
    await _homes.doc(id).set(data);
  }

  @override
  Future<Home?> getHome(String id) async {
    final doc = await _homes.doc(id).get();
    if (!doc.exists) return null;
    final map = doc.data()!..['id'] = doc.id;
    return Home.fromMap(map);
  }

  @override
  Future<Home?> getHomeByInviteCode(String inviteCode) async {
    final q = await _homes
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    final map = d.data()..['id'] = d.id;
    return Home.fromMap(map);
  }

  @override
  Future<void> joinHomeByInvite(String inviteCode, String userId) async {
    final home = await getHomeByInviteCode(inviteCode);
    if (home == null) throw StateError('Invite code not found');

    final docRef = _homes.doc(home.id);
    await firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) throw StateError('Home disappeared');
      final data = snapshot.data()!;
      final members =
          (data['members'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          <String>[];
      if (!members.contains(userId)) {
        members.add(userId);
        tx.update(docRef, {'members': members});
      }
    });
  }

  @override
  Future<void> updateHome(Home home) async {
    final data = home.toMap();
    await _homes.doc(home.id).set(data, SetOptions(merge: true));
  }
}
