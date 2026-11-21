import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_mode.dart';

class SettingsRepository {
  static const _kSyncMode = 'sync_mode_v1';
  static const _kNotificationsEnabled = 'notifications_enabled_v1';
  static const _kNotificationsPermissionPrompted =
      'notifications_permission_prompted_v1';
  static const _kNotificationStart = 'notification_start_v1';
  static const _kNotificationEnd = 'notification_end_v1';

  // RULE FOR FUTURE NOTIFICATIONS:
  // Any new notification category/channel added in the future MUST be opt-in
  // (defaulting to `false` in SettingsRepository). However, when the user
  // interacts with that part of the system while its notification is disabled
  // (and has not been prompted yet), show a one-time contextual prompt asking
  // whether they want to turn on notifications for that feature, and persist
  // a `*_prompted` flag so the prompt is only shown once.
  static const _kTasksDigest = 'notif_tasks_daily_digest';
  static const _kTasksReminders = 'notif_tasks_reminders';
  static const _kTasksPileup = 'notif_tasks_pileup_nudge';
  static const _kMedications = 'notif_medications_enabled';
  static const _kHousehold = 'notif_household_activity';
  static const _kFloatingNav = 'floating_nav_v1';
  static const _kHapticsEnabled = 'haptics_enabled_v1';
  final SharedPreferences prefs;

  SettingsRepository(this.prefs);

  SyncMode getSyncMode() {
    final raw = prefs.getString(_kSyncMode);
    return SyncModeExtension.fromKey(raw);
  }

  Future<void> setSyncMode(SyncMode mode) async {
    await prefs.setString(_kSyncMode, mode.toKey());
  }

  bool notificationsEnabled() {
    return prefs.getBool(_kNotificationsEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool v) async {
    await prefs.setBool(_kNotificationsEnabled, v);
  }

  bool taskDailyDigestEnabled({bool respectMaster = true}) =>
      (!respectMaster || notificationsEnabled()) &&
      (prefs.getBool(_kTasksDigest) ?? true);
  Future<void> setTaskDailyDigestEnabled(bool v) =>
      prefs.setBool(_kTasksDigest, v);

  bool taskRemindersEnabled({bool respectMaster = true}) =>
      (!respectMaster || notificationsEnabled()) &&
      (prefs.getBool(_kTasksReminders) ?? true);
  Future<void> setTaskRemindersEnabled(bool v) =>
      prefs.setBool(_kTasksReminders, v);

  bool taskPileupNudgeEnabled({bool respectMaster = true}) =>
      (!respectMaster || notificationsEnabled()) &&
      (prefs.getBool(_kTasksPileup) ?? true);
  Future<void> setTaskPileupNudgeEnabled(bool v) =>
      prefs.setBool(_kTasksPileup, v);

  bool medicationNotificationsEnabled({bool respectMaster = true}) =>
      (!respectMaster || notificationsEnabled()) &&
      (prefs.getBool(_kMedications) ?? true);
  Future<void> setMedicationNotificationsEnabled(bool v) =>
      prefs.setBool(_kMedications, v);

  bool householdNotificationsEnabled({bool respectMaster = true}) =>
      (!respectMaster || notificationsEnabled()) &&
      (prefs.getBool(_kHousehold) ?? true);
  Future<void> setHouseholdNotificationsEnabled(bool v) =>
      prefs.setBool(_kHousehold, v);

  bool notificationPermissionPrompted() {
    return prefs.getBool(_kNotificationsPermissionPrompted) ?? false;
  }

  Future<void> setNotificationPermissionPrompted(bool v) async {
    await prefs.setBool(_kNotificationsPermissionPrompted, v);
  }

  /// Stored as 'HH:mm' string in local time
  TimeOfDay notificationStart() {
    final raw = prefs.getString(_kNotificationStart) ?? '07:00';
    final parts = raw.split(':');
    final h = int.tryParse(parts[0]) ?? 7;
    final m = int.tryParse(parts.elementAt(1)) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> setNotificationStart(TimeOfDay t) async {
    final raw =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await prefs.setString(_kNotificationStart, raw);
  }

  TimeOfDay notificationEnd() {
    final raw = prefs.getString(_kNotificationEnd) ?? '17:00';
    final parts = raw.split(':');
    final h = int.tryParse(parts[0]) ?? 17;
    final m = int.tryParse(parts.elementAt(1)) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> setNotificationEnd(TimeOfDay t) async {
    final raw =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await prefs.setString(_kNotificationEnd, raw);
  }

  bool useFloatingNav() {
    return prefs.getBool(_kFloatingNav) ?? true;
  }

  Future<void> setUseFloatingNav(bool v) async {
    await prefs.setBool(_kFloatingNav, v);
  }

  bool hapticsEnabled() {
    return prefs.getBool(_kHapticsEnabled) ?? true;
  }

  Future<void> setHapticsEnabled(bool v) async {
    await prefs.setBool(_kHapticsEnabled, v);
  }

  static const _kLocale = 'app_locale_v1';
  static const _kLocaleMigrated = 'app_locale_migrated_v1';

  /// Returns the stored locale language code, or `null` for System default.
  String? getLocaleCode() {
    final raw = prefs.getString(_kLocale);
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  Future<void> setLocaleCode(String? code) async {
    if (code == null || code.isEmpty) {
      await prefs.remove(_kLocale);
    } else {
      await prefs.setString(_kLocale, code);
    }
  }

  bool isLocaleMigrated() {
    return prefs.getBool(_kLocaleMigrated) ?? false;
  }

  Future<void> setLocaleMigrated(bool v) async {
    await prefs.setBool(_kLocaleMigrated, v);
  }
}
