import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/extensions.dart';
import '../../../../core/locale_provider.dart';
import '../../../../core/settings_repository.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../home_screen.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/theme_controller.dart';
import '../../../common/app_theme.dart';
import '../../../common/widgets/theme_picker_sheet.dart';
import 'profile_page.dart';
import 'widget_settings_page.dart';

/// Settings page exposing account actions, UI preferences, notification
/// controls, and diagnostics. Changes are persisted via [SettingsRepository]
/// and applied immediately.
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
    if (!mounted) return;
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

  Future<void> _rescheduleNotifications() async {
    await NotificationService.instance.scheduleDailyStartEnd(
      enabled: _enabled,
      start: _start,
      end: _end,
    );
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t == null) return;
    setState(() => _start = t);
    await _settings?.setNotificationStart(t);
    await _rescheduleNotifications();
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t == null) return;
    setState(() => _end = t);
    await _settings?.setNotificationEnd(t);
    await _rescheduleNotifications();
  }

  Future<void> _toggleEnabled(bool v) async {
    setState(() => _enabled = v);
    await _settings?.setNotificationsEnabled(v);
    await _rescheduleNotifications();
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

  Future<void> _confirmLogout() async {
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
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.failedToLogout('$e'))));
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SectionHeader(title: l10n.accountSection),
          _buildAccountSection(context, l10n),
          const SizedBox(height: 20),
          _SectionHeader(title: l10n.preferencesSection),
          _buildPreferencesSection(context, l10n),
          const SizedBox(height: 20),
          _SectionHeader(title: l10n.notificationsSection),
          _buildNotificationsSection(context, l10n),
          const SizedBox(height: 20),
          _buildDiagnosticsSection(l10n),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, AppLocalizations l10n) {
    final errorColor = Theme.of(context).colorScheme.error;
    return _SettingsCard(
      children: [
        StreamBuilder<fb.User?>(
          stream: fb.FirebaseAuth.instance.userChanges(),
          initialData: fb.FirebaseAuth.instance.currentUser,
          builder: (context, snapshot) {
            final current =
                snapshot.data ?? fb.FirebaseAuth.instance.currentUser;
            final subtitleText = _accountSubtitle(current, l10n);

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
          leading: Icon(Icons.logout, color: errorColor),
          title: Text(l10n.logout, style: TextStyle(color: errorColor)),
          onTap: _confirmLogout,
        ),
      ],
    );
  }

  String _accountSubtitle(fb.User? user, AppLocalizations l10n) {
    final displayName = user?.displayName?.trim();
    final email = user?.email?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return email != null && email.isNotEmpty
          ? '$displayName • $email'
          : displayName;
    }
    if (email != null && email.isNotEmpty) return email;
    return l10n.viewAccountSubtitle;
  }

  Widget _buildPreferencesSection(BuildContext context, AppLocalizations l10n) {
    return _SettingsCard(
      children: [
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
        ListenableBuilder(
          listenable: ThemeController.instance,
          builder: (context, _) {
            final controller = ThemeController.instance;
            final palette = AppThemePalette.forType(controller.currentTheme);
            final scheme = Theme.of(context).brightness == Brightness.dark
                ? palette.darkScheme()
                : palette.lightScheme();
            return ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.themeTitle),
              subtitle: Text(controller.currentTheme.label),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ThemePreviewRow(scheme: scheme),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => showThemePickerSheet(context),
            );
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.dock_outlined),
          title: Text(l10n.floatingNavTitle),
          subtitle: Text(l10n.floatingNavSubtitle),
          value: _useFloatingNav,
          onChanged: _toggleFloatingNav,
        ),
        ListTile(
          leading: const Icon(Icons.widgets_outlined),
          title: Text(l10n.homeScreenWidgetsTitle),
          subtitle: Text(l10n.homeScreenWidgetsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WidgetSettingsPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return _SettingsCard(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: Text(l10n.dailyNotificationsTitle),
          subtitle: Text(l10n.dailyNotificationsSubtitle),
          value: _enabled,
          onChanged: _toggleEnabled,
        ),
        ListTile(
          enabled: _enabled,
          leading: const Icon(Icons.wb_sunny_outlined),
          title: Text(l10n.startOfDayTime),
          subtitle: Text(formatTimeWithSystemDefault(_start, context)),
          trailing: const Icon(Icons.access_time),
          onTap: _enabled ? _pickStart : null,
        ),
        ListTile(
          enabled: _enabled,
          leading: const Icon(Icons.nights_stay_outlined),
          title: Text(l10n.endOfDayTime),
          subtitle: Text(formatTimeWithSystemDefault(_end, context)),
          trailing: const Icon(Icons.access_time),
          onTap: _enabled ? _pickEnd : null,
        ),
      ],
    );
  }

  Widget _buildDiagnosticsSection(AppLocalizations l10n) {
    return _SettingsCard(
      children: [
        ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.bug_report_outlined),
          title: Text(l10n.diagnostics),
          children: [
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.testNotification),
              subtitle: Text(l10n.testNotificationSubtitle),
              onTap: () async {
                await NotificationService.instance.showTestNotification();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}
