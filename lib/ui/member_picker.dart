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
      // Stream the authoritative household doc and resolve members from the
      // members array rather than relying on the denormalized
      // users/{uid}.householdId field.
      final hhRef = FirebaseFirestore.instance
          .collection('households')
          .doc(householdId);
      debugPrint(
        'MemberPicker: subscribing to households/$householdId (ref=$hhRef)',
      );
      final hhStream = hhRef.snapshots().handleError(
        (e, st) => debugPrint('member_picker household stream error: $e'),
      );
      return StreamBuilder<DocumentSnapshot>(
        stream: hhStream,
        builder: (context, hhSnap) {
          if (hhSnap.hasError) {
            debugPrint(
              'MemberPicker household snapshot error: ${hhSnap.error}',
            );
            return const SizedBox(
              height: 48,
              child: Center(child: Text('Error loading members')),
            );
          }
          if (!hhSnap.hasData) {
            return const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final data = hhSnap.data!.data() as Map<String, dynamic>?;
          final membersIds = (data == null)
              ? <String>[]
              : ((data['members'] as List<dynamic>?)
                        ?.map((e) => e?.toString() ?? '')
                        .where((s) => s.isNotEmpty)
                        .toList() ??
                    <String>[]);

          if (membersIds.isEmpty) {
            return DropdownButtonFormField<String>(
              initialValue: initialMemberId ?? '',
              decoration: const InputDecoration(labelText: 'Assign to'),
              items: const [
                DropdownMenuItem<String>(value: '', child: Text('Unassigned')),
              ],
              onChanged: (_) => onChanged(null, null),
            );
          }

          // If possible, use a whereIn query to stream the user docs.
          if (membersIds.length <= 10) {
            final usersQuery = FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: membersIds);
            debugPrint(
              'MemberPicker: usersQuery whereIn count=${membersIds.length} query=$usersQuery',
            );
            final usersStream = usersQuery.snapshots().handleError(
              (e, st) => debugPrint('member_picker users stream error: $e'),
            );
            try {
              debugPrint(
                'MemberPicker: subscribing to users whereIn ${membersIds.length} ids',
              );
            } catch (_) {}
            return StreamBuilder<QuerySnapshot>(
              stream: usersStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  debugPrint(
                    'MemberPicker users snapshot error: ${snap.error}',
                  );
                  return const SizedBox(
                    height: 48,
                    child: Center(child: Text('Error loading members')),
                  );
                }
                if (!snap.hasData) {
                  return const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snap.data!.docs;
                final members = docs.map((d) {
                  final m = d.data() as Map<String, dynamic>?;
                  final display = m == null
                      ? d.id
                      : (m['displayName'] ?? m['email'] ?? d.id).toString();
                  return {'id': d.id, 'display': display};
                }).toList();
                members.sort(
                  (a, b) => membersIds
                      .indexOf(a['id']!)
                      .compareTo(membersIds.indexOf(b['id']!)),
                );
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
          }

          // Fallback for large households: fetch user docs individually.
          final futureUsers = Future.wait(
            membersIds.map(
              (id) =>
                  FirebaseFirestore.instance.collection('users').doc(id).get(),
            ),
          );
          try {
            debugPrint(
              'MemberPicker: fetching ${membersIds.length} user docs (fallback)',
            );
          } catch (_) {}
          return FutureBuilder<List<DocumentSnapshot>>(
            future: futureUsers,
            builder: (context, snap) {
              if (snap.hasError) {
                debugPrint('MemberPicker future users error: ${snap.error}');
              }
              final members = <Map<String, String>>[];
              if (snap.hasData) {
                for (final d in snap.data!) {
                  if (d.exists) {
                    final m = d.data() as Map<String, dynamic>?;
                    final display = m == null
                        ? d.id
                        : (m['displayName'] ?? m['email'] ?? d.id).toString();
                    members.add({'id': d.id, 'display': display});
                  }
                }
              }
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
