import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/home.dart';
import 'remote_home_repository.dart';

class FirestoreHomeRepository implements RemoteHomeRepository {
  /// Stream the home for a given user (assumes user is member of at most one home)
  Stream<Home?> userHome(String userId) {
    return _households
        .where('members', arrayContains: userId)
        .limit(1)
        .snapshots()
        .map(
          (snap) => snap.docs.isNotEmpty
              ? Home.fromMap(
                  (snap.docs.first.data()..['id'] = snap.docs.first.id),
                )
              : null,
        );
  }

  /// Stream all homes (for 'Everyone' feed)
  Stream<List<Home>> allHomes() {
    return _households.snapshots().map(
      (snap) => snap.docs
          .map((d) => Home.fromMap((d.data()..['id'] = d.id)))
          .toList(),
    );
  }

  final FirebaseFirestore firestore;

  FirestoreHomeRepository(this.firestore);

  CollectionReference<Map<String, dynamic>> get _households =>
      firestore.collection('households');

  @override
  Future<void> createHome(Home home) async {
    final data = home.toMap();
    final id = home.id;
    await _households.doc(id).set(data);
  }

  @override
  Future<Home?> getHome(String id) async {
    final doc = await _households.doc(id).get();
    if (!doc.exists) return null;
    final map = doc.data()!..['id'] = doc.id;
    return Home.fromMap(map);
  }

  @override
  Future<Home?> getHomeByInviteCode(String inviteCode) async {
    final q = await _households
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

    final docRef = _households.doc(home.id);
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
    await _households.doc(home.id).set(data, SetOptions(merge: true));
  }
}
