import 'package:barcode_widget/barcode_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class AboutHouseholdPage extends StatefulWidget {
  const AboutHouseholdPage({super.key});

  @override
  State<AboutHouseholdPage> createState() => _AboutHouseholdPageState();
}

class _AboutHouseholdPageState extends State<AboutHouseholdPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _household;
  List<Map<String, String?>>? _members;

  @override
  void initState() {
    super.initState();
    _loadHousehold();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Future<void> _loadHousehold() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not signed in';
          _loading = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      final hid = userData?['householdId'] as String?;
      if (hid == null) {
        setState(() {
          _error = 'No household is currently selected for your account.';
          _loading = false;
        });
        return;
      }

      final hhDoc = await FirebaseFirestore.instance
          .collection('households')
          .doc(hid)
          .get();
      final hhData = hhDoc.data();
      if (hhData == null) {
        setState(() {
          _error = 'Household not found.';
          _loading = false;
        });
        return;
      }

      // Load member display names + photoURL if members list present
      final members = hhData['members'];
      List<Map<String, String?>> memberList = [];
      if (members is List && members.isNotEmpty) {
        final docs = await Future.wait(
          members.map((m) async {
            final uid = m?.toString() ?? '';
            try {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get();
              final data = doc.data();
              return <String, String?>{
                'id': uid,
                'displayName': (data != null && data['displayName'] != null)
                    ? data['displayName'] as String
                    : uid,
                'photoURL': (data != null && data['photoURL'] != null)
                    ? data['photoURL'] as String
                    : null,
              };
            } catch (_) {
              return <String, String?>{
                'id': uid,
                'displayName': uid,
                'photoURL': null,
              };
            }
          }),
        );
        memberList = docs.cast<Map<String, String?>>();
      }

      setState(() {
        _household = hhData;
        _members = memberList;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load household: $e';
        _loading = false;
      });
    }
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final hh = _household ?? {};
    final name = hh['name'] as String? ?? 'Unknown';
    final description = hh['description'] as String? ?? '';
    final members = hh['members'];
    final memberCount = members is List
        ? members.length
        : (hh['memberCount'] ?? 'N/A');
    final created = hh['createdAt'];
    final inviteCode = hh['inviteCode'] as String?;
    String createdStr = 'N/A';
    if (created is Timestamp) {
      createdStr = DateTime.fromMillisecondsSinceEpoch(
        created.millisecondsSinceEpoch,
      ).toString();
    } else if (created is int) {
      createdStr = DateTime.fromMillisecondsSinceEpoch(created).toString();
    } else if (created is String) {
      createdStr = created;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (description.isNotEmpty) Text(description),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.group),
              const SizedBox(width: 8),
              Text('Members: $memberCount'),
            ],
          ),
          const SizedBox(height: 8),
          if (_members != null) ...[
            const SizedBox(height: 8),
            Text('Member list:', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            // show each member with avatar if available
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _members!.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final m = _members![index];
                final name = m['displayName'] ?? m['id'] ?? '';
                final photo = m['photoURL'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: photo != null && photo.isNotEmpty
                      ? CircleAvatar(backgroundImage: NetworkImage(photo))
                      : CircleAvatar(child: Text(_initials(name))),
                  title: Text(name),
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today),
              const SizedBox(width: 8),
              Text('Created: $createdStr'),
            ],
          ),
          const SizedBox(height: 16),
          if (inviteCode != null && inviteCode.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            // Invite code with copy button
            Row(
              children: [
                const Text('Invite code: '),
                Expanded(
                  child: SelectableText(
                    inviteCode,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy invite code',
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // QR for invite link with white background + border
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: BarcodeWidget(
                  barcode: Barcode.qrCode(),
                  data:
                      'https://housekeepr.app/join?code=$inviteCode&home=${hh['id'] ?? ''}',
                  width: 176,
                  height: 176,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Share button under QR
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share invite'),
                onPressed: () {
                  final link =
                      'https://housekeepr.app/join?code=$inviteCode&home=${hh['id'] ?? ''}';
                  try {
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Join my HouseKeepr home "${hh['name'] ?? ''}" using this link: $link',
                      ),
                    );
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to open share dialog'),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Scan this QR from the Join screen to accept the invite',
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text('No invite code available for this household.'),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadHousehold,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About household')),
      body: _buildBody(),
    );
  }
}
