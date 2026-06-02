import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/core/extensions.dart';
import 'package:marquee/marquee.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../cubits/ping_cubit.dart';
import '../../../../services/household_service.dart';

Future<List<_MemberPreview>> _loadHouseholdMembers({
  bool excludeCurrentUser = true,
}) async {
  final user = fb.FirebaseAuth.instance.currentUser;
  if (user == null) return const [];

  final householdId = await HouseholdService(
    FirebaseFirestore.instance,
  ).findHouseholdForUser(user.uid);

  if (householdId == null || householdId.isEmpty) {
    return const [];
  }

  final householdDoc = await FirebaseFirestore.instance
      .collection('households')
      .doc(householdId)
      .get();
  final householdData = householdDoc.data();
  final membersRaw = householdData?['members'];
  if (membersRaw is! List || membersRaw.isEmpty) {
    return const [];
  }

  final allMemberIds = membersRaw
      .map((m) => m?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toList();

  final memberIdsToLoad = excludeCurrentUser
      ? allMemberIds.where((id) => id != user.uid).toList()
      : allMemberIds;

  final users = await Future.wait(
    memberIdsToLoad.map((id) async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        final data = doc.data();
        final displayName = (data != null && data['displayName'] != null)
            ? data['displayName'] as String
            : id;
        final photoUrl = (data != null && data['photoURL'] != null)
            ? data['photoURL'] as String
            : null;
        return _MemberPreview(
          id: id,
          name: displayName,
          color: _avatarColorFromSeed(id),
          photoUrl: photoUrl,
          cooldown: null,
        );
      } catch (_) {
        return _MemberPreview(
          id: id,
          name: id,
          color: _avatarColorFromSeed(id),
          cooldown: null,
        );
      }
    }),
  );

  return users;
}

Color _avatarColorFromSeed(String seed) {
  const palette = <Color>[
    Color(0xFF4E79A7),
    Color(0xFFF28E2B),
    Color(0xFFE15759),
    Color(0xFF76B7B2),
    Color(0xFF59A14F),
    Color(0xFFEDC948),
    Color(0xFFB07AA1),
    Color(0xFFFF9DA7),
  ];
  final hash = seed.codeUnits.fold<int>(0, (acc, e) => acc + e);
  return palette[hash % palette.length];
}

class ToolPingHouseholdMember extends StatelessWidget {
  const ToolPingHouseholdMember({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Household Ping')),
        body: Column(
          children: [
            const SizedBox(height: 8),
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.send_outlined), text: 'Send Ping'),
                Tab(icon: Icon(Icons.privacy_tip_outlined), text: 'Privacy'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [_SenderCommandCenter(), _RecipientPrivacyCenter()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SenderCommandCenter extends StatefulWidget {
  const _SenderCommandCenter();

  @override
  State<_SenderCommandCenter> createState() => _SenderCommandCenterState();
}

class _SenderCommandCenterState extends State<_SenderCommandCenter> {
  static const double _mapLatitude = 52.343657542849854;
  static const double _mapLongitude = 4.837116364182893;

  late final Future<List<_MemberPreview>> _membersFuture;
  String? _selectedMemberId;
  String? _selectedMemberName;
  final TextEditingController _customMessageController =
      TextEditingController();
  int? _selectedReasonIndex;
  bool _reciprocity = false;

  final List<_ReasonPreset> _reasons = const [
    _ReasonPreset(
      icon: Icons.restaurant_menu,
      title: 'Dinner',
      subtitle: 'Starting dinner, how far out are you?',
    ),
    _ReasonPreset(
      icon: Icons.location_searching,
      title: 'Waiting',
      subtitle: "I'm at the spot, where are you?",
    ),
    _ReasonPreset(
      icon: Icons.directions_car,
      title: 'Commute',
      subtitle: "Checking if you've left yet.",
    ),
    _ReasonPreset(
      icon: Icons.health_and_safety,
      title: 'Safety',
      subtitle: 'Just making sure you arrived safely.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  @override
  void dispose() {
    _customMessageController.dispose();
    super.dispose();
  }

  void _sendPing() {
    if (_selectedMemberId == null || _selectedMemberName == null) return;

    // Determine the reason string
    String reason = '';
    if (_customMessageController.text.isNotEmpty) {
      reason = _customMessageController.text;
    } else if (_selectedReasonIndex != null) {
      reason = _reasons[_selectedReasonIndex!].subtitle;
    }

    if (reason.isEmpty) return;

    final currentUser = fb.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    context.read<PingCubit>().sendPing(
      currentUser.uid,
      _selectedMemberId!,
      reason,
      reciprocity: _reciprocity,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ping sent to $_selectedMemberName')),
    );
  }

  Future<List<_MemberPreview>> _loadMembers() async {
    final members = await _loadHouseholdMembers(excludeCurrentUser: true);
    if (members.isNotEmpty) return members;
    return _loadHouseholdMembers(excludeCurrentUser: false);
  }

  Future<void> _openInGoogleMaps() async {
    final query = '$_mapLatitude,$_mapLongitude';

    final androidDeepLink = Uri.parse('geo:$query?q=$query');
    final iosDeepLink = Uri.parse('comgooglemaps://?q=$query');
    final webFallback = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

    final deepLink = kIsWeb
        ? webFallback
        : defaultTargetPlatform == TargetPlatform.iOS
        ? iosDeepLink
        : androidDeepLink;

    if (await canLaunchUrl(deepLink)) {
      await launchUrl(deepLink, mode: LaunchMode.externalApplication);
      return;
    }

    if (await canLaunchUrl(webFallback)) {
      await launchUrl(webFallback, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Google Maps.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pingState = context.watch<PingCubit>().state;

    // Calculate cooldown for currently selected member
    Duration cooldownRemaining = Duration.zero;
    bool isCooldownActive = false;
    if (_selectedMemberId != null &&
        pingState.cooldowns.containsKey(_selectedMemberId!)) {
      final expiry = pingState.cooldowns[_selectedMemberId!]!;
      final now = DateTime.now();
      if (expiry.isAfter(now)) {
        cooldownRemaining = expiry.difference(now);
        isCooldownActive = true;
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.visibility_off, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ghost Mode: Off',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'You can send and receive pings right now.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('1h Ghost'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select household member',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<_MemberPreview>>(
                  future: _membersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 84,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: scheme.onErrorContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Could not load household members.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final members = snapshot.data ?? const <_MemberPreview>[];
                    if (members.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.group_off,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No household members available to ping yet.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    _selectedMemberId ??= members.first.id;
                    _selectedMemberName ??= members.first.name;

                    return SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: members.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final selected = member.id == _selectedMemberId;
                          return _MemberChip(
                            member: member,
                            selected: selected,
                            onTap: () {
                              setState(() {
                                _selectedMemberId = member.id;
                                _selectedMemberName = member.name;
                              });
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Why are you pinging?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  itemCount: _reasons.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (context, index) {
                    final reason = _reasons[index];
                    return _ReasonCard(
                      reason: reason,
                      selected: _selectedReasonIndex == index,
                      onTap: () {
                        setState(() {
                          _selectedReasonIndex = index;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customMessageController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Custom message',
                    hintText: 'Type your own reason here',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  onChanged: (value) {
                    if (value.trim().isNotEmpty &&
                        _selectedReasonIndex != null) {
                      setState(() {
                        _selectedReasonIndex = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Share my location too (5 minutes)'),
                  subtitle: const Text(
                    'Reciprocity enabled for this ping request.',
                  ),
                  value: _reciprocity,
                  onChanged: (val) => setState(() => _reciprocity = val),
                ),
                if (isCooldownActive) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_bottom, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cool-down active for ${_selectedMemberName ?? 'member'}: '
                            '${cooldownRemaining.toClockMmSs()} remaining.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isCooldownActive || _selectedMemberId == null
                        ? null
                        : _sendPing,
                    icon: const Icon(Icons.send),
                    label: Text(
                      isCooldownActive
                          ? 'Wait ${cooldownRemaining.toClockMmSs()}'
                          : 'Send Ping to ${_selectedMemberName ?? 'Member'}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last approved ping',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withAlpha(110),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.location_pin,
                          size: 46,
                          color: scheme.primary,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surface.withAlpha(230),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Shared 2 minutes ago • Accuracy ±15m',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openInGoogleMaps,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open in Maps'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecipientPrivacyCenter extends StatefulWidget {
  const _RecipientPrivacyCenter();

  @override
  State<_RecipientPrivacyCenter> createState() =>
      _RecipientPrivacyCenterState();
}

class _RecipientPrivacyCenterState extends State<_RecipientPrivacyCenter> {
  late final Future<List<_MemberPreview>> _trustMembersFuture;
  final Map<String, bool> _autoApproveByMemberId = {};

  final List<_LogEntry> _logEntries = const [
    _LogEntry(
      name: 'Dad',
      reason: 'Starting dinner, how far out are you?',
      time: 'Today • 18:42',
      status: 'Auto-approved',
      icon: Icons.check_circle,
      approved: true,
    ),
    _LogEntry(
      name: 'Mila',
      reason: 'I\'m at the spot, where are you?',
      time: 'Today • 17:10',
      status: 'Declined',
      icon: Icons.cancel,
      approved: false,
    ),
    _LogEntry(
      name: 'Tom',
      reason: 'Checking if you\'ve left yet.',
      time: 'Yesterday • 08:23',
      status: 'Expired',
      icon: Icons.hourglass_disabled,
      approved: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _trustMembersFuture = _loadHouseholdMembers(excludeCurrentUser: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trust Management',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'These people can see your location automatically.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<_MemberPreview>>(
                  future: _trustMembersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Could not load household members for trust management.',
                            ),
                          ),
                        ],
                      );
                    }

                    final members = snapshot.data ?? const <_MemberPreview>[];
                    if (members.isEmpty) {
                      return const Text('No household members available yet.');
                    }

                    return Column(
                      children: members.map((member) {
                        final enabled =
                            _autoApproveByMemberId[member.id] ?? false;
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary:
                              member.photoUrl != null &&
                                  member.photoUrl!.isNotEmpty
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    member.photoUrl!,
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: member.color,
                                  child: Text(
                                    member.name.characters.first.toUpperCase(),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                          title: Text(member.name),
                          subtitle: const Text(
                            'Auto-approve one-time ping requests',
                          ),
                          value: enabled,
                          onChanged: (value) {
                            setState(() {
                              _autoApproveByMemberId[member.id] = value;
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick responses',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    Chip(label: Text('Stuck in traffic')),
                    Chip(label: Text('Leaving in 5')),
                    Chip(label: Text('On my way')),
                    Chip(label: Text('Arrived safely')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ping activity log',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear log'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._logEntries.map((entry) => _LogTile(entry: entry)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghost Mode Timer',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    ChoiceChip(label: Text('1 hour'), selected: true),
                    ChoiceChip(label: Text('4 hours'), selected: false),
                    ChoiceChip(label: Text('Until tomorrow'), selected: false),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {},
                    icon: const Icon(Icons.visibility_off),
                    label: const Text('Enable Ghost Mode'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final _ReasonPreset reason;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonCard({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(reason.icon, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              reason.title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                reason.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final _MemberPreview member;
  final bool selected;
  final VoidCallback onTap;

  const _MemberChip({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Column(
          children: [
            member.photoUrl != null && member.photoUrl!.isNotEmpty
                ? CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(member.photoUrl!),
                  )
                : CircleAvatar(
                    radius: 18,
                    backgroundColor: member.color,
                    child: Text(
                      member.name.characters.first.toUpperCase(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            const SizedBox(height: 4),
            SizedBox(
              height: 14,
              child: Marquee(
                text: member.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                startAfter: const Duration(seconds: 3),
                pauseAfterRound: const Duration(seconds: 2),
                blankSpace: 20,
                velocity: 25,
                accelerationCurve: Curves.easeInOutCubic,
                accelerationDuration: const Duration(seconds: 1),
                decelerationDuration: const Duration(seconds: 1),
                decelerationCurve: Curves.easeInOutCubic,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 14,
              child: Text(
                member.cooldown == null ? 'Ready' : member.cooldown!,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  height: 1,
                  color: member.cooldown == null
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                textScaler: TextScaler.noScaling,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final _LogEntry entry;

  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconColor = entry.approved ? Colors.green : scheme.onSurfaceVariant;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(entry.icon, color: iconColor),
      title: Text('${entry.name} • ${entry.reason}'),
      subtitle: Text('${entry.time} • ${entry.status}'),
      trailing: entry.status == 'Auto-approved'
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Auto',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }
}

class _ReasonPreset {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ReasonPreset({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _MemberPreview {
  final String id;
  final String name;
  final Color color;
  final String? photoUrl;
  final String? cooldown;

  const _MemberPreview({
    required this.id,
    required this.name,
    required this.color,
    this.photoUrl,
    this.cooldown,
  });
}

class _LogEntry {
  final String name;
  final String reason;
  final String time;
  final String status;
  final IconData icon;
  final bool approved;

  const _LogEntry({
    required this.name,
    required this.reason,
    required this.time,
    required this.status,
    required this.icon,
    required this.approved,
  });
}
