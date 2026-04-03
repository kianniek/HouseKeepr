import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/home.dart';
import 'package:uuid/uuid.dart';
import 'remote_home_repository.dart';

class FirestoreHomeRepository implements RemoteHomeRepository {
  /// Stream the home for a given user (assumes user is member of at most one home)
  Stream<Home?> userHome(String userId) {
    debugPrint(
      'FirestoreHomeRepository.userHome: streaming households with member=$userId',
    );
    final query = _households.where('members', arrayContains: userId).limit(1);
    debugPrint(
      'FirestoreHomeRepository.userHome query: where(members arrayContains $userId) limit(1) on collection households',
    );
    return query
        .snapshots()
        .handleError((e, st) => debugPrint('userHome stream error: $e'))
        .map(
          (snap) => snap.docs.isNotEmpty
              ? (() {
                  final d = snap.docs.first;
                  // Fire-and-forget ensure inviteCode exists for this doc
                  _ensureInviteCodeIfMissing(d.id, d.data());
                  return Home.fromMap((d.data()..['id'] = d.id));
                })()
              : null,
        );
  }

  /// Stream all homes (for 'Everyone' feed)
  Stream<List<Home>> allHomes(String userId) {
    debugPrint(
      'FirestoreHomeRepository.allHomes: streaming households for user=$userId',
    );
    final query = _households.where('members', arrayContains: userId);
    debugPrint(
      'FirestoreHomeRepository.allHomes query: where(members arrayContains $userId) on collection households',
    );
    return query
        .snapshots()
        .handleError((e, st) => debugPrint('allHomes stream error: $e'))
        .map(
          (snap) => snap.docs.map((d) {
            // Fire-and-forget ensure inviteCode exists for this doc
            _ensureInviteCodeIfMissing(d.id, d.data());
            return Home.fromMap((d.data()..['id'] = d.id));
          }).toList(),
        );
  }

  final FirebaseFirestore firestore;

  FirestoreHomeRepository(this.firestore);

  CollectionReference<Map<String, dynamic>> get _households =>
      firestore.collection('households');

  // Ensure a household document has an inviteCode. If missing, generate one
  // and persist it. This runs fire-and-forget for stream mappers to avoid
  // blocking synchronous mapping.
  Future<void> _ensureInviteCodeIfMissing(
    String docId,
    Map<String, dynamic>? data,
  ) async {
    try {
      final existing = data?['inviteCode'];
      if (existing == null || (existing is String && existing.isEmpty)) {
        final invite = const Uuid().v4().substring(0, 6).toUpperCase();
        await _households.doc(docId).set({
          'inviteCode': invite,
        }, SetOptions(merge: true));
        debugPrint('Added missing inviteCode for household $docId');
      }
    } catch (e) {
      debugPrint('Failed to ensure inviteCode for $docId: $e');
    }
  }

  @override
  Future<void> createHome(Home home) async {
    final data = home.toMap();
    final id = home.id;
    try {
      debugPrint('FirestoreHomeRepository.createHome: households/$id');
      await _households.doc(id).set(data);
    } catch (e) {
      debugPrint('FirestoreHomeRepository.createHome failed: $e');
      rethrow;
    }
  }

  @override
  Future<Home?> getHome(String id) async {
    try {
      debugPrint('FirestoreHomeRepository.getHome: households/$id');
      final doc = await _households.doc(id).get();
      if (!doc.exists) return null;
      final map = doc.data()!..['id'] = doc.id;
      // If inviteCode missing, generate and persist synchronously so caller sees it
      if (map['inviteCode'] == null ||
          (map['inviteCode'] is String &&
              (map['inviteCode'] as String).isEmpty)) {
        final invite = const Uuid().v4().substring(0, 6).toUpperCase();
        await _households.doc(id).set({
          'inviteCode': invite,
        }, SetOptions(merge: true));
        map['inviteCode'] = invite;
      }
      return Home.fromMap(map);
    } catch (e) {
      debugPrint('FirestoreHomeRepository.getHome failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateHome(Home home) async {
    final data = home.toMap();
    try {
      debugPrint('FirestoreHomeRepository.updateHome: households/${home.id}');
      await _households.doc(home.id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreHomeRepository.updateHome failed: $e');
      rethrow;
    }
  }
}
