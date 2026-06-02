import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class HouseholdService {
  final FirebaseFirestore firestore;
  HouseholdService(this.firestore);

  /// Returns the householdId that contains [userId] in its `members` array,
  /// or null if none found. Queries are limited to 1 result and treat the
  /// households collection as the authoritative source of membership.
  Future<String?> findHouseholdForUser(String userId) async {
    try {
      // First, try to get householdId from the user's own document.
      try {
        debugPrint('HouseholdService: reading users/$userId');
      } catch (_) {}
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()!.containsKey('householdId')) {
        final householdId = userDoc.data()!['householdId'] as String?;
        if (householdId != null && householdId.isNotEmpty) {
          return householdId;
        }
      }

      // Fallback for existing users: query the households collection.
      try {
        debugPrint(
          'HouseholdService: querying households where members contains $userId',
        );
      } catch (_) {}
      final q = await firestore
          .collection('households')
          .where('members', arrayContains: userId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final householdId = q.docs.first.id;
        // As a migration step, write back the householdId to the user doc.
        await firestore.collection('users').doc(userId).set({
          'householdId': householdId,
        }, SetOptions(merge: true));
        return householdId;
      }
    } catch (e) {
      // Log the error but don't rethrow, as a null return is a valid outcome.
      debugPrint('Error finding household for user: $e');
    }
    return null;
  }
}
