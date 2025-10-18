import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A reusable member picker that emits selected member id and display name via onChanged.
class MemberPicker extends StatelessWidget {
  final String householdId;
  final void Function(String? id, String? displayName) onChanged;
  final String? initialMemberId;

  const MemberPicker({
    super.key,
    required this.householdId,
    required this.onChanged,
    this.initialMemberId,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final stream = FirebaseFirestore.instance
          .collection('users')
          .where('householdId', isEqualTo: householdId)
          .snapshots();
      return StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final docs = snap.data!.docs;
          final members = docs.map((d) {
            final m = d.data() as Map<String, dynamic>;
            final display =
                m['displayName'] as String? ?? m['email'] as String? ?? d.id;
            return {'id': d.id, 'display': display};
          }).toList();

          return DropdownButtonFormField<String>(
            initialValue: initialMemberId ?? '',
            decoration: const InputDecoration(labelText: 'Assign to'),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Unassigned'),
              ),
              ...members.map(
                (m) => DropdownMenuItem<String>(
                  value: m['id']!,
                  child: Text(m['display']!),
                ),
              ),
            ],
            onChanged: (v) {
              if (v == null || v.isEmpty) return onChanged(null, null);
              final m = members.firstWhere((e) => e['id'] == v);
              onChanged(m['id'], m['display']);
            },
          );
        },
      );
    } catch (e) {
      // Firebase isn't initialized in tests or dev environment; render a simple fallback.
      return DropdownButtonFormField<String>(
        initialValue: '',
        decoration: const InputDecoration(labelText: 'Assign to'),
        items: const [
          DropdownMenuItem<String>(value: '', child: Text('Unassigned')),
        ],
        onChanged: (_) => onChanged(null, null),
      );
    }
  }
}
