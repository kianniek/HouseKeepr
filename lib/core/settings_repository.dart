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
  static const _kFloatingNav = 'floating_nav_v1';
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
}
