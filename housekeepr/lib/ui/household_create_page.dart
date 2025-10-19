import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './join_household_page.dart';

class HouseholdCreatePage extends StatefulWidget {
  final User user;
  final void Function(String householdId) onCreated;
  const HouseholdCreatePage({
    super.key,
    required this.user,
    required this.onCreated,
  });

  @override
  State<HouseholdCreatePage> createState() => _HouseholdCreatePageState();
}

class _HouseholdCreatePageState extends State<HouseholdCreatePage> {
  final _nameCtl = TextEditingController();
  bool _loading = false;

  Future<void> _createHousehold() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _loading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final doc = await firestore.collection('households').add({
        'name': _nameCtl.text.trim(),
        'ownerUid': widget.user.uid,
        'members': [widget.user.uid],
        'created_at': FieldValue.serverTimestamp(),
      });
      // Optionally, update user profile with householdId
      await firestore.collection('users').doc(widget.user.uid).set({
        'householdId': doc.id,
      }, SetOptions(merge: true));
      widget.onCreated(doc.id);
    } catch (e) {
      if (mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to create household: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Household')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(labelText: 'Household name'),
            ),
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _createHousehold,
                    child: const Text('Create'),
                  ),
            const SizedBox(height: 16),
            Text('or', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final joinedId = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => JoinHouseholdPage(
                      user: widget.user,
                      onJoined: (id) => Navigator.of(context).pop(id),
                    ),
                  ),
                );
                if (joinedId != null) {
                  widget.onCreated(joinedId);
                }
              },
              child: const Text('Join with invite code'),
            ),
          ],
        ),
      ),
    );
  }
}
