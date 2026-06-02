import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ping_request.dart';

class FirestorePingRepository {
  final FirebaseFirestore firestore;
  final String householdId;

  FirestorePingRepository(this.firestore, {required this.householdId});

  CollectionReference<Map<String, dynamic>> get _col =>
      firestore.collection('households').doc(householdId).collection('pings');

  Future<void> sendPing(PingRequest request) async {
    final data = request.toMap();
    data['timestamp'] = FieldValue.serverTimestamp();
    await _col.doc(request.id).set(data, SetOptions(merge: true));
  }

  Future<void> updatePingStatus(
    String pingId,
    PingStatus status, {
    PingLocation? location,
  }) async {
    final Map<String, dynamic> data = {
      'status': status.name,
      'respondedAt': FieldValue.serverTimestamp(),
    };
    if (location != null) {
      data['location'] = location.toMap();
    }
    await _col.doc(pingId).update(data);
  }

  Stream<List<PingRequest>> streamPingsForUser(String userId) {
    return _col
        .where('recipientId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PingRequest.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Stream<PingRequest?> streamPing(String pingId) {
    return _col.doc(pingId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return PingRequest.fromMap(doc.data()!, doc.id);
    });
  }

  Future<List<PingRequest>> getRecentLogs(String userId) async {
    final snapshot = await _col
        .where('recipientId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();
    return snapshot.docs
        .map((doc) => PingRequest.fromMap(doc.data(), doc.id))
        .toList();
  }
}
