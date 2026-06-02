import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// (TaskPriority not needed here)

// Optional platform notifications
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Lightweight in-app notification service.
///
/// This provides two features:
/// 1. Immediate in-app notifications using a passed `ScaffoldMessenger` key
///    (SnackBars). If no scaffold key is provided the service falls back to
///    `debugPrint` so tests and headless runs are unaffected.
/// 2. A tiny schedule store for reminders persisted in `SharedPreferences`.
///    Scheduling here only persists the reminder and will fire when
///    `checkAndFireDueReminders` is called (e.g. at app start). This keeps
///    the implementation platform-agnostic; you can later plug in
///    `flutter_local_notifications` for real scheduled platform notifications.

class NotificationService {
  NotificationService._private();
  static final NotificationService instance = NotificationService._private();

  SharedPreferences? _prefs;
  GlobalKey<ScaffoldMessengerState>? _scaffoldKey;

  FlutterLocalNotificationsPlugin? _plugin;
  bool _pluginAvailable = false;
  VoidCallback? _onOpenTasks;

  static const _kPayloadOpenTasks = 'open_tasks';
  static const _kAndroidIntentChannel = 'housekeepr/notification_intents';

  static const _kRemindersKey = 'scheduled_reminders_v1';

  Color? _getColorForPriority(int? priorityLevel) {
    if (priorityLevel == null) {
      return null;
    }
    switch (priorityLevel) {
      case 0: // low
        return const Color(0xFF4CAF50); // Green
      case 1: // medium
        return const Color(0xFFFF9800); // Orange
      case 2: // high
        return const Color(0xFFFF5722); // Deep orange
      case 3: // urgent
        return const Color(0xFFF44336); // Red
      default:
        return null;
    }
  }

  Future<void> init(
    SharedPreferences prefs, {
    GlobalKey<ScaffoldMessengerState>? scaffoldKey,
    VoidCallback? onOpenTasks,
  }) async {
    _prefs = prefs;
    _scaffoldKey = scaffoldKey;
    _onOpenTasks = onOpenTasks;
    // Try to initialize platform notifications. Wrap errors so tests/headless
    // environments don't fail.
    if (!kIsWeb) {
      try {
        _plugin = FlutterLocalNotificationsPlugin();
        const android = AndroidInitializationSettings('ic_launcher_monochrome');
        const iOS = DarwinInitializationSettings(
          defaultPresentAlert: true,
          defaultPresentSound: true,
          defaultPresentBadge: true,
        );
        await _plugin!.initialize(
          settings: const InitializationSettings(android: android, iOS: iOS),
          onDidReceiveNotificationResponse: _handleNotificationResponse,
        );
        await _createNotificationChannels();
        // initialize timezone data
        try {
          tzdata.initializeTimeZones();
          final local = tz.getLocation(DateTime.now().timeZoneName);
          tz.setLocalLocation(local);
        } catch (_) {
          // ignore timezone init failures
        }
        _pluginAvailable = true;
        await _handleLaunchAction();
        await _handleAndroidIntentAction();
      } catch (e) {
        debugPrint('Notification plugin init failed: $e');
        _pluginAvailable = false;
      }
    }
  }

  Future<void> requestPermissions() async {
    if (!_pluginAvailable || _plugin == null || kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin!
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final ios = _plugin!
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
      final macos = _plugin!
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      await macos?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> _createNotificationChannels() async {
    final android = _plugin
        ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    try {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          'task_reminders',
          'Task Reminders',
          importance: Importance.defaultImportance,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          'daily_reminders',
          'Daily reminders',
          importance: Importance.defaultImportance,
        ),
      );
    } catch (_) {
      // ignore
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _handleNotificationPayload(response.payload);
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null || payload == _kPayloadOpenTasks) {
      _onOpenTasks?.call();
    }
  }

  Future<void> _handleLaunchAction() async {
    if (!_pluginAvailable || _plugin == null) return;
    try {
      final launchDetails = await _plugin!.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        _handleNotificationPayload(
          launchDetails?.notificationResponse?.payload,
        );
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _handleAndroidIntentAction() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      const channel = MethodChannel(_kAndroidIntentChannel);
      final action = await channel.invokeMethod<String>(
        'getNotificationAction',
      );
      if (action == _kPayloadOpenTasks) {
        _handleNotificationPayload(action);
      }
    } catch (_) {
      // ignore
    }
  }

  void show(
    String title,
    String body, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final msg = '$title${body.isNotEmpty ? ': $body' : ''}';
    if (_scaffoldKey?.currentState != null) {
      _scaffoldKey!.currentState!.showSnackBar(
        SnackBar(content: Text(msg), duration: duration),
      );
    } else {
      // Fallback for tests or when scaffold key not yet provided
      debugPrint('Notification: $msg');
    }
  }

  Future<void> showTestNotification() async {
    if (_pluginAvailable && _plugin != null) {
      try {
        final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
        await _plugin!.show(
          id: id,
          title: 'Test notification',
          body: 'Notifications are working on this device.',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'task_reminders',
              'Task Reminders',
              importance: Importance.low,
              icon: 'ic_launcher_monochrome',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: _kPayloadOpenTasks,
        );
        return;
      } catch (e) {
        debugPrint('Failed to show test notification: $e');
      }
    }

    show('Test notification', 'Notifications are working on this device.');
  }

  Future<void> scheduleReminder(
    String taskId,
    DateTime at, {
    String? title,
    String? body,
    int? priorityLevel,
  }) async {
    if (_prefs == null) return;
    final list = _prefs!.getStringList(_kRemindersKey) ?? <String>[];
    final entry = jsonEncode({
      'taskId': taskId,
      'at': at.toUtc().toIso8601String(),
      'title': title ?? '',
      'body': body ?? '',
    });
    list.add(entry);
    await _prefs!.setStringList(_kRemindersKey, list);
    // Also schedule a platform notification if available for that exact time
    if (_pluginAvailable && _plugin != null) {
      try {
        final id = _hashId(taskId);
        final scheduled = tz.TZDateTime.from(at.toUtc(), tz.local);
        final color = _getColorForPriority(priorityLevel);
        await _plugin!.zonedSchedule(
          id: id,
          title: title ?? 'Reminder',
          body: body ?? '',
          scheduledDate: scheduled,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'task_reminders',
              'Task Reminders',
              importance: Importance.low,
              icon: 'ic_launcher_monochrome',
              color: color,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
          payload: _kPayloadOpenTasks,
        );
      } catch (e) {
        debugPrint('Failed to schedule platform reminder: $e');
      }
    }
  }

  Future<void> cancelReminder(String taskId) async {
    if (_prefs == null) return;
    final list = _prefs!.getStringList(_kRemindersKey) ?? <String>[];
    final filtered = list.where((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return m['taskId'] != taskId;
      } catch (_) {
        return true;
      }
    }).toList();
    await _prefs!.setStringList(_kRemindersKey, filtered);
    if (_pluginAvailable && _plugin != null) {
      try {
        await _plugin!.cancel(id: _hashId(taskId));
      } catch (_) {}
    }
  }

  int _hashId(String s) {
    // Simple stable hash to map a string id to an int notification id
    var h = 0;
    for (var i = 0; i < s.length; i++) {
      h = ((h << 5) - h) + s.codeUnitAt(i);
      h = h & 0x7fffffff;
    }
    // ensure non-zero and limited range
    return (h == 0) ? 1 : (h % 0x7fffffff);
  }

  /// Schedule two daily notifications at start and end times (local time).
  /// If [enabled] is false the scheduled start/end notifications will be canceled.
  Future<void> scheduleDailyStartEnd({
    required bool enabled,
    required TimeOfDay start,
    required TimeOfDay end,
  }) async {
    // IDs reserved for the daily start/end notifications
    const startId = 1000;
    const endId = 1001;
    if (!enabled) {
      if (_pluginAvailable && _plugin != null) {
        try {
          await _plugin!.cancel(id: startId);
          await _plugin!.cancel(id: endId);
        } catch (_) {}
      }
      return;
    }
    // compute next occurrences in local tz
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime nextStart = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      start.hour,
      start.minute,
    );
    if (!nextStart.isAfter(now)) {
      nextStart = nextStart.add(const Duration(days: 1));
    }
    tz.TZDateTime nextEnd = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      end.hour,
      end.minute,
    );
    if (!nextEnd.isAfter(now)) nextEnd = nextEnd.add(const Duration(days: 1));

    if (_pluginAvailable && _plugin != null) {
      try {
        await _plugin!.zonedSchedule(
          id: startId,
          title: 'Start of day',
          body: 'Tasks for your day',
          scheduledDate: nextStart,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_reminders',
              'Daily reminders',
              importance: Importance.low,
              icon: 'ic_launcher_monochrome',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: _kPayloadOpenTasks,
        );

        await _plugin!.zonedSchedule(
          id: endId,
          title: 'End of day',
          body: 'Review completed tasks',
          scheduledDate: nextEnd,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_reminders',
              'Daily reminders',
              importance: Importance.low,
              icon: 'ic_launcher_monochrome',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: _kPayloadOpenTasks,
        );
      } catch (e) {
        debugPrint('Failed to schedule start/end notifications: $e');
      }
    }
  }

  /// Check persisted reminders and fire any that are due at or before [now].
  /// Fired reminders are removed from the persisted store.
  Future<void> checkAndFireDueReminders({DateTime? now}) async {
    if (_prefs == null) return;
    now ??= DateTime.now().toUtc();
    final list = _prefs!.getStringList(_kRemindersKey) ?? <String>[];
    final remaining = <String>[];
    for (final s in list) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        final at = DateTime.parse(m['at']).toUtc();
        if (!at.isAfter(now)) {
          final title = (m['title'] as String?) ?? 'Reminder';
          final body = (m['body'] as String?) ?? '';
          show(title, body, duration: const Duration(seconds: 6));
        } else {
          remaining.add(s);
        }
      } catch (_) {
        // Keep malformed entries out of firing but drop them
      }
    }
    await _prefs!.setStringList(_kRemindersKey, remaining);
  }
}
