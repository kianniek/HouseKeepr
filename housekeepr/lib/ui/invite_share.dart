import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/home.dart';

/// Simple widget that shows invite info for a Home and provides a share button.
class InviteShare extends StatelessWidget {
  final Home home;
  final String baseUrl; // e.g. https://housekeepr.app/join

  const InviteShare({
    super.key,
    required this.home,
    this.baseUrl = 'https://housekeepr.app/join',
  });

  void _share(BuildContext context) {
    final code = home.inviteCode ?? '';
    final link = '$baseUrl?code=$code&home=${home.id}';
    Share.share(
      'Join my HouseKeepr home "${home.name}" using this link: $link',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Invite code: ${home.inviteCode ?? "-"}'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _share(context),
          icon: const Icon(Icons.share),
          label: const Text('Share invite'),
        ),
      ],
    );
  }
}
