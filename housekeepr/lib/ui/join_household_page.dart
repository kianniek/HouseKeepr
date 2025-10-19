import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinHouseholdPage extends StatefulWidget {
  final User user;
  final void Function(String householdId) onJoined;
  const JoinHouseholdPage({
    super.key,
    required this.user,
    required this.onJoined,
  });

  @override
  State<JoinHouseholdPage> createState() => _JoinHouseholdPageState();
}

class _JoinHouseholdPageState extends State<JoinHouseholdPage> {
  final _inviteCtl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _joinHousehold() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final query = await firestore
          .collection('households')
          .where('inviteCode', isEqualTo: _inviteCtl.text.trim())
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        setState(() => _error = 'No household found for that invite code.');
        return;
      }
      final doc = query.docs.first;
      final householdId = doc.id;
      // Add user to household members array
      await firestore.collection('households').doc(householdId).update({
        'members': FieldValue.arrayUnion([widget.user.uid]),
      });
      // Update user profile with householdId
      await firestore.collection('users').doc(widget.user.uid).set({
        'householdId': householdId,
      }, SetOptions(merge: true));
      widget.onJoined(householdId);
    } catch (e) {
      setState(() => _error = 'Failed to join household: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Household')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _inviteCtl,
              decoration: const InputDecoration(labelText: 'Invite code'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _joinHousehold,
                    child: const Text('Join'),
                  ),
          ],
        ),
      ),
    );
  }
}
