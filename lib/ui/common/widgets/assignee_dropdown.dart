import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Reusable assignee dropdown used by inline add rows and dialogs.
///
/// - `householdId` (required): the household to list members for.
/// - `value`: current selected value, use 'household' to represent the whole
///   household (no specific assignee).
/// - `onChanged`: called with the newly-selected value.
class AssigneeDropdown extends StatelessWidget {
  final String householdId;
  final String? value;
  final ValueChanged<String?> onChanged;
  // Optional callback to receive the current members list (id/display) when
  // the dropdown's internal stream updates. Useful for callers that want to
  // avoid their own Firestore lookups and reuse the streamed member data.
  final ValueChanged<List<Map<String, String>>>? onMembersChanged;
  final double? width;

  const AssigneeDropdown({
    super.key,
    required this.householdId,
    required this.value,
    required this.onChanged,
    this.onMembersChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final child = Builder(
      builder: (ctx) {
        try {
          // Stream the household doc to get authoritative members list.
          final hhRef = FirebaseFirestore.instance
              .collection('households')
              .doc(householdId);
          debugPrint(
            'AssigneeDropdown: subscribing to households/$householdId (ref=$hhRef)',
          );
          final hhStream = hhRef.snapshots().handleError(
            (e, st) =>
                debugPrint('assignee_dropdown household stream error: $e'),
          );
          try {
            debugPrint(
              'AssigneeDropdown: subscribing to households/$householdId',
            );
          } catch (_) {}
          return StreamBuilder<DocumentSnapshot>(
            stream: hhStream,
            builder: (context, hhSnap) {
              if (hhSnap.hasError) {
                debugPrint(
                  'AssigneeDropdown household snapshot error: ${hhSnap.error}',
                );
                return DropdownButtonFormField<String>(
                  initialValue: value ?? 'household',
                  decoration: const InputDecoration(labelText: 'Assign to'),
                  items: const [
                    DropdownMenuItem(
                      value: 'household',
                      child: Text('Household (anyone)'),
                    ),
                  ],
                  onChanged: onChanged,
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

              // If no members, just render the household-only option.
              if (membersIds.isEmpty) {
                final items = <DropdownMenuItem<String>>[
                  const DropdownMenuItem(
                    value: 'household',
                    child: Text('Household (anyone)'),
                  ),
                ];
                try {
                  if (onMembersChanged != null) onMembersChanged!(const []);
                } catch (_) {}
                return DropdownButtonFormField<String>(
                  initialValue: value ?? 'household',
                  decoration: const InputDecoration(labelText: 'Assign to'),
                  items: items,
                  onChanged: onChanged,
                );
              }

              // If the household has a small number of members, use a whereIn
              // query to stream the user docs. Firestore whereIn supports up to
              // 10 values; if larger, fall back to fetching individual docs.
              if (membersIds.length <= 10) {
                final usersQuery = FirebaseFirestore.instance
                    .collection('users')
                    .where(FieldPath.documentId, whereIn: membersIds);
                debugPrint(
                  'AssigneeDropdown: usersQuery whereIn count=${membersIds.length} query=$usersQuery',
                );
                final usersStream = usersQuery.snapshots().handleError(
                  (e, st) =>
                      debugPrint('assignee_dropdown users stream error: $e'),
                );
                try {
                  debugPrint(
                    'AssigneeDropdown: subscribing to users whereIn ${membersIds.length} ids',
                  );
                } catch (_) {}
                return StreamBuilder<QuerySnapshot>(
                  stream: usersStream,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      debugPrint(
                        'AssigneeDropdown users snapshot error: ${snap.error}',
                      );
                    }
                    final members = <Map<String, String>>[];
                    if (snap.hasData) {
                      for (final d in snap.data!.docs) {
                        final m = d.data() as Map<String, dynamic>;
                        final display =
                            m['displayName'] as String? ??
                            m['email'] as String? ??
                            d.id;
                        members.add({'id': d.id, 'display': display});
                      }
                    }
                    // Preserve the original member ordering from membersIds when possible
                    members.sort(
                      (a, b) => membersIds
                          .indexOf(a['id']!)
                          .compareTo(membersIds.indexOf(b['id']!)),
                    );
                    final items = <DropdownMenuItem<String>>[
                      const DropdownMenuItem(
                        value: 'household',
                        child: Text('Household (anyone)'),
                      ),
                      ...members.map(
                        (m) => DropdownMenuItem(
                          value: m['id'],
                          child: Text(m['display']!),
                        ),
                      ),
                    ];
                    try {
                      if (onMembersChanged != null) {
                        onMembersChanged!(List.unmodifiable(members));
                      }
                    } catch (_) {}
                    return DropdownButtonFormField<String>(
                      initialValue: value ?? 'household',
                      decoration: const InputDecoration(labelText: 'Assign to'),
                      items: items,
                      onChanged: onChanged,
                    );
                  },
                );
              }

              // Fallback: fetch user docs individually (non-streaming). This
              // is acceptable for large households but won't reflect live
              // changes to user profiles.
              final futureUsers = Future.wait(
                membersIds.map(
                  (id) => FirebaseFirestore.instance
                      .collection('users')
                      .doc(id)
                      .get(),
                ),
              );
              try {
                debugPrint(
                  'AssigneeDropdown: fetching ${membersIds.length} user docs (fallback)',
                );
              } catch (_) {}
              return FutureBuilder<List<DocumentSnapshot>>(
                future: futureUsers,
                builder: (context, snap) {
                  if (snap.hasError) {
                    debugPrint(
                      'AssigneeDropdown future users error: ${snap.error}',
                    );
                  }
                  final members = <Map<String, String>>[];
                  if (snap.hasData) {
                    for (final d in snap.data!) {
                      if (d.exists) {
                        final m = d.data() as Map<String, dynamic>?;
                        final display = m == null
                            ? d.id
                            : (m['displayName'] ?? m['email'] ?? d.id)
                                  .toString();
                        members.add({'id': d.id, 'display': display});
                      }
                    }
                  }
                  final items = <DropdownMenuItem<String>>[
                    const DropdownMenuItem(
                      value: 'household',
                      child: Text('Household (anyone)'),
                    ),
                    ...members.map(
                      (m) => DropdownMenuItem(
                        value: m['id'],
                        child: Text(m['display']!),
                      ),
                    ),
                  ];
                  try {
                    if (onMembersChanged != null) {
                      onMembersChanged!(List.unmodifiable(members));
                    }
                  } catch (_) {}
                  return DropdownButtonFormField<String>(
                    initialValue: value ?? 'household',
                    decoration: const InputDecoration(labelText: 'Assign to'),
                    items: items,
                    onChanged: onChanged,
                  );
                },
              );
            },
          );
        } catch (e) {
          return DropdownButtonFormField<String>(
            initialValue: value ?? 'household',
            decoration: const InputDecoration(labelText: 'Assign to'),
            items: const [
              DropdownMenuItem(
                value: 'household',
                child: Text('Household (anyone)'),
              ),
            ],
            onChanged: onChanged,
          );
        }
      },
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return child;
  }
}
