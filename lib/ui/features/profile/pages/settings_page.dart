import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/extensions.dart';
import '../../../../core/locale_provider.dart';
import '../../../../core/settings_repository.dart';
import '../../../../cubits/task_cubit.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../home_screen.dart';
import '../../../../repositories/local_medication_repository.dart';
import '../../../../repositories/task_repository.dart';
import '../../../../services/app_haptics.dart';
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
  bool _tasksDigest = false;
  bool _tasksReminders = false;
  bool _tasksPileup = false;
  bool _medications = true;
  bool _household = true;
  bool _useFloatingNav = true;
  bool _hapticsEnabled = true;
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
      _tasksDigest = s.taskDailyDigestEnabled(respectMaster: false);
      _tasksReminders = s.taskRemindersEnabled(respectMaster: false);
      _tasksPileup = s.taskPileupNudgeEnabled(respectMaster: false);
      _medications = s.medicationNotificationsEnabled(respectMaster: false);
      _household = s.householdNotificationsEnabled(respectMaster: false);
      _useFloatingNav = s.useFloatingNav();
      _hapticsEnabled = s.hapticsEnabled();
      _start = s.notificationStart();
      _end = s.notificationEnd();
      _loading = false;
    });
  }

  Future<void> _rescheduleNotifications() async {
    final s = _settings;
    if (s == null) return;
    final tasks =
        context.read<TaskCubit?>()?.state.tasks ??
        TaskRepository(s.prefs).loadTasks();
    await NotificationService.instance.syncTaskNotifications(
      tasks: tasks,
      settings: s,
    );
  }

  Future<void> _syncMedicationNotifications() async {
    final s = _settings;
    if (s == null) return;
    if (s.medicationNotificationsEnabled()) {
      final repo = LocalMedicationRepository(prefs: s.prefs);
      final meds = await repo.getMedications();
      await NotificationService.instance.rescheduleAllMedications(meds);
    } else {
      await NotificationService.instance.cancelAllMedicationReminders();
    }
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
    await _syncMedicationNotifications();
  }

  Future<void> _toggleTasksDigest(bool v) async {
    setState(() => _tasksDigest = v);
    await _settings?.setTaskDailyDigestEnabled(v);
    await _rescheduleNotifications();
  }

  Future<void> _toggleTasksReminders(bool v) async {
    setState(() => _tasksReminders = v);
    await _settings?.setTaskRemindersEnabled(v);
    if (!v) {
      await NotificationService.instance.cancelAllTaskReminders();
    } else {
      await _rescheduleNotifications();
    }
  }

  Future<void> _toggleTasksPileup(bool v) async {
    setState(() => _tasksPileup = v);
    await _settings?.setTaskPileupNudgeEnabled(v);
    await _rescheduleNotifications();
  }

  Future<void> _toggleMedications(bool v) async {
    setState(() => _medications = v);
    await _settings?.setMedicationNotificationsEnabled(v);
    await _syncMedicationNotifications();
  }

  Future<void> _toggleHousehold(bool v) async {
    setState(() => _household = v);
    await _settings?.setHouseholdNotificationsEnabled(v);
  }

  Future<void> _toggleFloatingNav(bool v) async {
    setState(() => _useFloatingNav = v);
    await _settings?.setUseFloatingNav(v);
    // Notify HomeScreen immediately so the nav style switches in real time.
    HomeScreen.floatingNavNotifier.value = v;
  }

  Future<void> _toggleHaptics(bool v) async {
    setState(() => _hapticsEnabled = v);
    await AppHaptics.instance.setEnabled(v, prefsOverride: _settings?.prefs);
    if (v) {
      AppHaptics.instance.toggleOn();
    }
  }

  Future<void> _onLocaleChanged(Locale? locale) async {
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
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
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
            final selectedLocale =
                (currentLocale != null &&
                    LocaleProvider.supportedLocales.contains(currentLocale))
                ? currentLocale
                : null;
            return ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              trailing: DropdownButton<Locale?>(
                value: selectedLocale,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem<Locale?>(
                    value: null,
                    child: Text(l10n.languageSystemDefault),
                  ),
                  DropdownMenuItem<Locale?>(
                    value: const Locale('en'),
                    child: Text(l10n.languageEnglish),
                  ),
                  DropdownMenuItem<Locale?>(
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
            final scheme = Theme.of(context).brightness == Brightness.dark
                ? controller.darkScheme
                : controller.lightScheme;
            final subtitle = controller.currentTheme == AppThemeType.dynamic
                ? l10n.themeDynamic
                : controller.currentTheme.label;
            return ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.themeTitle),
              subtitle: Text(subtitle),
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
        SwitchListTile(
          secondary: const Icon(Icons.vibration_outlined),
          title: Text(l10n.hapticsTitle),
          subtitle: Text(l10n.hapticsSubtitle),
          value: _hapticsEnabled,
          onChanged: _toggleHaptics,
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

  // NOTE FOR FUTURE NOTIFICATIONS:
  // Any new notification channels added here must default to opt-in (false)
  // in SettingsRepository, with a one-time contextual prompt when the user
  // uses that feature while its notifications are disabled.
  Widget _buildNotificationsSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return _SettingsCard(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: Text(l10n.allNotificationsTitle),
          subtitle: Text(l10n.allNotificationsSubtitle),
          value: _enabled,
          onChanged: _toggleEnabled,
        ),
        ListTile(
          enabled: _enabled,
          leading: const Icon(Icons.wb_sunny_outlined),
          title: Text(l10n.morningBriefing),
          subtitle: Text(formatTimeWithSystemDefault(_start, context)),
          trailing: const Icon(Icons.access_time),
          onTap: _enabled ? _pickStart : null,
        ),
        ListTile(
          enabled: _enabled,
          leading: const Icon(Icons.nights_stay_outlined),
          title: Text(l10n.eveningCheckIn),
          subtitle: Text(formatTimeWithSystemDefault(_end, context)),
          trailing: const Icon(Icons.access_time),
          onTap: _enabled ? _pickEnd : null,
        ),
        ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.tune_outlined),
          title: Text(l10n.appChannels),
          initiallyExpanded: _enabled,
          children: [
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.wb_twilight_outlined),
              title: Text(l10n.notifTasksDigestTitle),
              subtitle: Text(l10n.notifTasksDigestSubtitle),
              value: _tasksDigest,
              onChanged: _enabled ? _toggleTasksDigest : null,
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.alarm_outlined),
              title: Text(l10n.notifTasksRemindersTitle),
              subtitle: Text(l10n.notifTasksRemindersSubtitle),
              value: _tasksReminders,
              onChanged: _enabled ? _toggleTasksReminders : null,
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome_outlined),
              title: Text(l10n.notifTasksPileupTitle),
              subtitle: Text(l10n.notifTasksPileupSubtitle),
              value: _tasksPileup,
              onChanged: _enabled ? _toggleTasksPileup : null,
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.medication_outlined),
              title: Text(l10n.notifMedicationsTitle),
              subtitle: Text(l10n.notifMedicationsSubtitle),
              value: _medications,
              onChanged: _enabled ? _toggleMedications : null,
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.people_outline),
              title: Text(l10n.notifHouseholdTitle),
              subtitle: Text(l10n.notifHouseholdSubtitle),
              value: _household,
              onChanged: _enabled ? _toggleHousehold : null,
            ),
          ],
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
