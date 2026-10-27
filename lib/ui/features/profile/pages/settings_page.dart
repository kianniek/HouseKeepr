import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/services/household_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/locale_provider.dart';
import '../../../../core/settings_repository.dart';
import '../../../../cubits/user_cubit.dart';
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
            subtitle: Text(_start.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: _pickStart,
          ),
          ListTile(
            title: Text(l10n.endOfDayTime),
            subtitle: Text(_end.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: _pickEnd,
          ),
          // ── Profile ───────────────────────────────────────────────────────
          ListTile(
            title: Text(l10n.profile),
            subtitle: Text(l10n.profileSubtitle),
            leading: const Icon(Icons.person),
            onTap: () {
              final userCubit = context.read<UserCubit?>();
              final user = userCubit?.state;
              if (user != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProfilePage(user: user)),
                );
              }
            },
          ),
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
