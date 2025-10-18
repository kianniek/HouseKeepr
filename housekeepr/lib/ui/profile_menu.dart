import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/user_cubit.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'profile_page.dart';
import 'switch_household_page.dart';
import 'settings_page.dart';

class ProfileMenu extends StatelessWidget {
  final fb.User? user;
  const ProfileMenu({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserCubit, fb.User?>(
      builder: (context, cubitUser) {
        final displayUser = cubitUser ?? user;
        return PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'profile') {
              if (displayUser != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(user: displayUser),
                  ),
                );
              }
            } else if (v == 'switch') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SwitchHouseholdPage()),
              );
            } else if (v == 'settings') {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            } else if (v == 'signout') {
              final ok =
                  await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (!ok) return;
              try {
                await fb.FirebaseAuth.instance.signOut();
              } catch (_) {}
              try {
                final google = GoogleSignIn();
                if (await google.isSignedIn()) await google.signOut();
              } catch (_) {}
            }
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'profile', child: Text('Profile')),
            PopupMenuItem(value: 'switch', child: Text('Switch household')),
            PopupMenuItem(value: 'settings', child: Text('Settings')),
            PopupMenuItem(value: 'signout', child: Text('Sign out')),
          ],
          icon: CircleAvatar(
            backgroundImage:
                (displayUser != null && displayUser.photoURL != null)
                ? NetworkImage(displayUser.photoURL!)
                : null,
            child: (displayUser == null || displayUser.photoURL == null)
                ? const Icon(Icons.person)
                : null,
          ),
        );
      },
    );
  }
}
