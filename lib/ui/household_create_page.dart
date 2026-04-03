import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widget_previews.dart';
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
      // Use field names that match the recommended schema and security rules
      // (see docs/firestore_homes.md). In particular the rules expect
      // `createdBy` and `createdAt` so set those names here.
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      // Debug info to help diagnose rules rejections
      // Print firebase_core app list and full currentUser object to ensure
      // the app is initialized and the auth state is what we expect.
      try {
        debugPrint('DEBUG Firebase.apps: ${Firebase.apps}');
      } catch (e) {
        debugPrint('DEBUG Firebase.apps error: $e');
      }
      debugPrint(
        'DEBUG currentUser full: ${FirebaseAuth.instance.currentUser}',
      );
      debugPrint(
        'DEBUG createHousehold: authUid=$authUid widgetUser=${widget.user.uid}',
      );
      final payload = {
        'name': _nameCtl.text.trim(),
        'createdBy': widget.user.uid,
        'members': [widget.user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      };
      debugPrint('DEBUG createHousehold payload: $payload');
      final doc = await firestore.collection('households').add(payload);
      // Optionally, update user profile with householdId
      final userPayload = {'householdId': doc.id};
      debugPrint('DEBUG updating users/${widget.user.uid} with: $userPayload');
      await firestore
          .collection('users')
          .doc(widget.user.uid)
          .set(userPayload, SetOptions(merge: true));
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
    final theme = Theme.of(context);
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
            Text(
              'or',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
