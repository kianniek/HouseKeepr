import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/locale_provider.dart';
import '../../../../core/settings_repository.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../home_screen.dart';
import '../../../../services/notification_service.dart';
import 'profile_page.dart';

/// Settings page exposing notification controls, UI preferences, and language selection.
/// Changes are persisted via [SettingsRepository] and applied immediately.

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsRepository? _settings;
  bool _enabled = true;
  bool _useFloatingNav = true;
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsRepository(prefs);
    setState(() {
      _settings = s;
      _enabled = s.notificationsEnabled();
      _useFloatingNav = s.useFloatingNav();
      _start = s.notificationStart();
      _end = s.notificationEnd();
      _loading = false;
    });
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t == null) return;
    setState(() => _start = t);
    await _settings?.setNotificationStart(t);
    await NotificationService.instance.scheduleDailyStartEnd(
      enabled: _enabled,
      start: _start,
      end: _end,
    );
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t == null) return;
    setState(() => _end = t);
    await _settings?.setNotificationEnd(t);
    await NotificationService.instance.scheduleDailyStartEnd(
      enabled: _enabled,
      start: _start,
      end: _end,
    );
  }

  Future<void> _toggleEnabled(bool v) async {
    setState(() => _enabled = v);
    await _settings?.setNotificationsEnabled(v);
    await NotificationService.instance.scheduleDailyStartEnd(
      enabled: _enabled,
      start: _start,
      end: _end,
    );
  }

  Future<void> _toggleFloatingNav(bool v) async {
    setState(() => _useFloatingNav = v);
    await _settings?.setUseFloatingNav(v);
    // Notify HomeScreen immediately so the nav style switches in real time.
    HomeScreen.floatingNavNotifier.value = v;
  }

  Future<void> _onLocaleChanged(Locale? locale) async {
    if (locale == null) return;
    await LocaleProvider.instance.setLocale(locale);
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.logoutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogCtx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final navigator = Navigator.of(context);
      navigator.popUntil((route) => route.isFirst);
      await fb.FirebaseAuth.instance.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to logout: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          // ── Language ─────────────────────────────────────────────────────
          ListenableBuilder(
            listenable: LocaleProvider.instance,
            builder: (context, _) {
              final currentLocale = LocaleProvider.instance.locale;
              return ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.language),
                trailing: DropdownButton<Locale>(
                  value: currentLocale,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: const Locale('en'),
                      child: Text(l10n.languageEnglish),
                    ),
                    DropdownMenuItem(
                      value: const Locale('nl'),
                      child: Text(l10n.languageDutch),
                    ),
                  ],
                  onChanged: _onLocaleChanged,
                ),
              );
            },
          ),
          const Divider(height: 1),
          // ── Navigation ───────────────────────────────────────────────────
          SwitchListTile(
            title: Text(l10n.floatingNavTitle),
            subtitle: Text(l10n.floatingNavSubtitle),
            value: _useFloatingNav,
            onChanged: _toggleFloatingNav,
          ),
          // ── Notifications ─────────────────────────────────────────────────
          SwitchListTile(
            title: Text(l10n.dailyNotificationsTitle),
            subtitle: Text(l10n.dailyNotificationsSubtitle),
            value: _enabled,
            onChanged: _toggleEnabled,
          ),
          ListTile(
            title: Text(l10n.startOfDayTime),
            subtitle: Text(formatTimeWithSystemDefault(_start, context)),
            trailing: const Icon(Icons.access_time),
            onTap: _pickStart,
          ),
          ListTile(
            title: Text(l10n.endOfDayTime),
            subtitle: Text(formatTimeWithSystemDefault(_end, context)),
            trailing: const Icon(Icons.access_time),
            onTap: _pickEnd,
          ),
          // ── Account ───────────────────────────────────────────────────────
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.accountSection,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          StreamBuilder<fb.User?>(
            stream: fb.FirebaseAuth.instance.userChanges(),
            initialData: fb.FirebaseAuth.instance.currentUser,
            builder: (context, snapshot) {
              final current =
                  snapshot.data ?? fb.FirebaseAuth.instance.currentUser;
              final displayName = current?.displayName?.trim();
              final email = current?.email?.trim();
              final subtitleText = displayName != null && displayName.isNotEmpty
                  ? (email != null && email.isNotEmpty
                        ? '$displayName • $email'
                        : displayName)
                  : (email != null && email.isNotEmpty
                        ? email
                        : l10n.viewAccountSubtitle);

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: current?.photoURL != null
                      ? NetworkImage(current!.photoURL!)
                      : null,
                  child: current?.photoURL == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(l10n.viewAccount),
                subtitle: Text(subtitleText),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final targetUser =
                      current ?? fb.FirebaseAuth.instance.currentUser;
                  if (targetUser != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(user: targetUser),
                      ),
                    );
                  }
                },
              );
            },
          ),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.logout,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmLogout(context),
          ),
          const Divider(height: 1),
          // ── Diagnostics ───────────────────────────────────────────────────
          ExpansionTile(
            title: Text(l10n.diagnostics),
            leading: const Icon(Icons.bug_report),
            children: [
              ListTile(
                title: Text(l10n.testNotification),
                subtitle: Text(l10n.testNotificationSubtitle),
                trailing: const Icon(Icons.notifications_active),
                onTap: () async {
                  await NotificationService.instance.showTestNotification();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
