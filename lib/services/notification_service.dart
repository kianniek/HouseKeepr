import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// (TaskPriority not needed here)

// Optional platform notifications
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/settings_repository.dart';
import '../core/sync_mode.dart';
import '../models/medication.dart';
import '../models/task.dart';
import '../repositories/local_medication_repository.dart';
import '../repositories/task_repository.dart';
import '../ui/features/tasks/utils/task_date_utils.dart';
import 'task_rescheduler.dart';
import 'widget_service.dart';
import 'write_queue.dart';

/// Declarative channel configuration so new notification setups can easily
/// specify their own Android Importance/Priority, sound/vibration, and iOS
/// presentation rules in one place.
enum NotificationChannelType {
  taskDigest,
  taskReminders,
  medications,
  householdActivity,
}

class NotificationChannelConfig {
  final String id;
  final String name;
  final String description;
  final Importance androidImportance;
  final Priority androidPriority;
  final bool playSound;
  final bool enableVibration;
  final bool presentAlert;
  final bool presentSound;
  final bool presentBadge;

  const NotificationChannelConfig({
    required this.id,
    required this.name,
    required this.description,
    this.androidImportance = Importance.defaultImportance,
    this.androidPriority = Priority.defaultPriority,
    this.playSound = true,
    this.enableVibration = true,
    this.presentAlert = true,
    this.presentSound = true,
    this.presentBadge = true,
  });
}

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

/// Top-level background callback for notification action buttons (e.g.
/// "Remind me later") invoked by `flutter_local_notifications` in a background
/// isolate when `showsUserInterface` is false.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (response.actionId != NotificationService._kActionRemindLater &&
      response.actionId != NotificationService._kActionMarkTaken &&
      response.actionId != NotificationService._kActionTaskDone &&
      response.actionId != NotificationService._kActionTaskSmartReschedule) {
    return;
  }
  if (!NotificationService.instance.isInitialized) {
    final prefs = await SharedPreferences.getInstance();
    await NotificationService.instance.init(prefs, isBackground: true);
  }
  if (response.actionId == NotificationService._kActionRemindLater) {
    await NotificationService.instance.handleRemindLater(response);
  } else if (response.actionId == NotificationService._kActionMarkTaken) {
    await NotificationService.instance.handleMarkMedicationTaken(response);
  } else if (response.actionId == NotificationService._kActionTaskDone) {
    await NotificationService.instance.handleTaskDone(response);
  } else if (response.actionId ==
      NotificationService._kActionTaskSmartReschedule) {
    await NotificationService.instance.handleTaskSmartReschedule(response);
  }
}

class NotificationService {
  NotificationService._private();
  static final NotificationService instance = NotificationService._private();

  SharedPreferences? _prefs;
  GlobalKey<ScaffoldMessengerState>? _scaffoldKey;

  bool get isInitialized => _prefs != null;

  FlutterLocalNotificationsPlugin? _plugin;
  bool _pluginAvailable = false;
  VoidCallback? _onOpenTasks;
  VoidCallback? _onOpenTasksRebalance;
  VoidCallback? _onOpenMedications;

  static const _kPayloadOpenTasks = 'open_tasks';
  static const _kPayloadOpenTasksRebalance = 'open_tasks_rebalance';
  static const _kPayloadOpenMedications = 'open_medications';
  static const _kActionRemindLater = 'remind_later';
  static const _kActionMarkTaken = 'mark_taken';
  static const _kActionTaskDone = 'task_done';
  static const _kActionTaskSmartReschedule = 'task_smart_reschedule';
  static const _kAndroidIntentChannel = 'housekeepr/notification_intents';
  static const _kActiveUserIdKey = 'notif_active_user_id_v1';

  static const int morningDigestNotificationId = 1001;
  static const int eveningPileupNotificationId = 1002;
  static const _kLegacyStartNotificationId = 1000;

  /// Incremented whenever a notification action updates medication dose state
  /// in the active isolate.
  final ValueNotifier<int> medicationUpdatesNotifier = ValueNotifier<int>(0);

  /// Incremented whenever a notification action updates task state in the
  /// active isolate (or background isolate).
  final ValueNotifier<int> taskUpdatesNotifier = ValueNotifier<int>(0);

  static const _kRemindersKey = 'scheduled_reminders_v1';
  static const _kScheduledTaskReminderIdsKey =
      'scheduled_task_reminder_ids_v1';
  static const _kMedicationRemindersKey = 'scheduled_medication_reminders_v1';

  /// Centralized channel registry. Add new [NotificationChannelType] entries
  /// here to configure custom Android Importance/Priority and sound/vibration
  /// rules for future notification setups.
  static const Map<NotificationChannelType, NotificationChannelConfig>
  channelConfigs = {
    NotificationChannelType.taskDigest: NotificationChannelConfig(
      id: 'housekeepr_task_digest',
      name: 'Task Digest & Check-ins',
      description: 'Morning daily summary and gentle evening pile-up check-in',
      androidImportance: Importance.defaultImportance,
      androidPriority: Priority.defaultPriority,
      enableVibration: false,
    ),
    NotificationChannelType.taskReminders: NotificationChannelConfig(
      id: 'housekeepr_task_reminders',
      name: 'Task Reminders',
      description: 'Scheduled alerts for tasks with a specific reminder time',
      androidImportance: Importance.high,
      androidPriority: Priority.high,
    ),
    NotificationChannelType.medications: NotificationChannelConfig(
      id: 'housekeepr_medications',
      name: 'Medication Reminders',
      description: 'Scheduled daytime and evening medication dose reminders',
      androidImportance: Importance.high,
      androidPriority: Priority.high,
    ),
    NotificationChannelType.householdActivity: NotificationChannelConfig(
      id: 'housekeepr_household',
      name: 'Household Updates',
      description: 'Shared list and chore updates from household members',
      androidImportance: Importance.defaultImportance,
      androidPriority: Priority.defaultPriority,
    ),
  };

  /// Builds [NotificationDetails] from the declarative [channelConfigs] entry.
  static NotificationDetails buildNotificationDetails(
    NotificationChannelType channel, {
    Color? color,
    List<AndroidNotificationAction>? actions,
  }) {
    final cfg = channelConfigs[channel]!;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        cfg.id,
        cfg.name,
        channelDescription: cfg.description,
        importance: cfg.androidImportance,
        priority: cfg.androidPriority,
        playSound: cfg.playSound,
        enableVibration: cfg.enableVibration,
        icon: 'ic_launcher_monochrome',
        color: color,
        actions: actions,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: cfg.presentAlert,
        presentSound: cfg.presentSound,
        presentBadge: cfg.presentBadge,
      ),
    );
  }

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

  static final _medicationNotificationDetails = buildNotificationDetails(
    NotificationChannelType.medications,
    actions: const <AndroidNotificationAction>[
      AndroidNotificationAction(
        _kActionMarkTaken,
        'Mark as taken',
        cancelNotification: true,
        showsUserInterface: false,
      ),
      AndroidNotificationAction(
        _kActionRemindLater,
        'Remind me later',
        cancelNotification: true,
      ),
    ],
  );

  Future<void> init(
    SharedPreferences prefs, {
    GlobalKey<ScaffoldMessengerState>? scaffoldKey,
    VoidCallback? onOpenTasks,
    VoidCallback? onOpenTasksRebalance,
    VoidCallback? onOpenMedications,
    String? userId,
    bool isBackground = false,
  }) async {
    _prefs = prefs;
    _scaffoldKey = scaffoldKey;
    _onOpenTasks = onOpenTasks;
    _onOpenTasksRebalance = onOpenTasksRebalance;
    _onOpenMedications = onOpenMedications;
    if (userId != null && userId.isNotEmpty) {
      await prefs.setString(_kActiveUserIdKey, userId);
    }
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
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
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
        if (!isBackground) {
          await _handleLaunchAction();
          await _handleAndroidIntentAction();
        }
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
      for (final cfg in channelConfigs.values) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            cfg.id,
            cfg.name,
            description: cfg.description,
            importance: cfg.androidImportance,
            playSound: cfg.playSound,
            enableVibration: cfg.enableVibration,
          ),
        );
      }
    } catch (_) {
      // ignore
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.actionId == _kActionRemindLater) {
      handleRemindLater(response);
      return;
    }
    if (response.actionId == _kActionMarkTaken) {
      handleMarkMedicationTaken(response);
      return;
    }
    if (response.actionId == _kActionTaskDone) {
      handleTaskDone(response);
      return;
    }
    if (response.actionId == _kActionTaskSmartReschedule) {
      handleTaskSmartReschedule(response);
      return;
    }
    _handleNotificationPayload(response.payload);
  }

  void _handleNotificationPayload(String? payload) {
    if (payload != null) {
      if (payload.startsWith('{')) {
        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          final action = map['action'] as String?;
          if (action == _kPayloadOpenTasksRebalance) {
            (_onOpenTasksRebalance ?? _onOpenTasks)?.call();
            return;
          }
          if (action == _kPayloadOpenTasks) {
            _onOpenTasks?.call();
            return;
          }
          if (action == _kPayloadOpenMedications ||
              (action != null && action.startsWith('open_medication'))) {
            _onOpenMedications?.call();
            return;
          }
        } catch (_) {}
      }
      if (payload == _kPayloadOpenTasksRebalance) {
        (_onOpenTasksRebalance ?? _onOpenTasks)?.call();
        return;
      }
      if (payload == _kPayloadOpenMedications ||
          payload.startsWith('open_medication')) {
        _onOpenMedications?.call();
        return;
      }
    }
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
      if (action == _kPayloadOpenTasks || action == _kPayloadOpenMedications) {
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

  /// Show an immediate test notification for a medication preview, including
  /// the "Mark as taken" and "Remind me later" action buttons.
  Future<void> showTestMedicationNotification({
    String? medicationName,
    String? dosage,
    String? medicationId,
    String? doseId,
    String? dateKey,
  }) async {
    final name = (medicationName != null && medicationName.trim().isNotEmpty)
        ? medicationName.trim()
        : 'Vitamin D';
    final dose = dosage?.trim() ?? '';
    final body = dose.isNotEmpty ? '$name ($dose)' : name;
    const title = 'Medication reminder';

    final payloadMap = <String, dynamic>{
      'action': _kPayloadOpenMedications,
      'title': title,
      'body': body,
      'isTest': true,
    };
    if (medicationId != null) payloadMap['medicationId'] = medicationId;
    if (doseId != null) payloadMap['doseId'] = doseId;
    if (dateKey != null) payloadMap['dateKey'] = dateKey;
    final payload = jsonEncode(payloadMap);

    if (_pluginAvailable && _plugin != null) {
      try {
        final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
        await _plugin!.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: _medicationNotificationDetails,
          payload: payload,
        );
        return;
      } catch (e) {
        debugPrint('Failed to show test medication notification: $e');
      }
    }

    show(title, body);
  }

  /// Handle "Remind me later" action by dismissing the current notification
  /// and rescheduling it to 1 hour later.
  Future<void> handleRemindLater(NotificationResponse response) async {
    if (response.id != null && _pluginAvailable && _plugin != null) {
      try {
        await _plugin!.cancel(id: response.id!);
      } catch (_) {}
    }

    String title = 'Medication reminder';
    String body = 'Time to take your medication';
    String? medicationId;
    String? doseId;
    String? dateKey;
    bool isTest = false;

    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        if (response.payload!.startsWith('{')) {
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          if (data['title'] != null) title = data['title'] as String;
          if (data['body'] != null) body = data['body'] as String;
          medicationId = data['medicationId'] as String?;
          doseId = data['doseId'] as String?;
          dateKey = data['dateKey'] as String?;
          isTest = data['isTest'] == true;
        }
      } catch (_) {}
    }

    final delay = isTest
        ? const Duration(seconds: 10)
        : const Duration(hours: 1);
    final newTime = DateTime.now().add(delay);
    final newId = _hashId(
      'remind_later_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (_prefs != null) {
      final list =
          _prefs!.getStringList(_kMedicationRemindersKey) ?? <String>[];
      final entry = jsonEncode({
        'medicationId': medicationId ?? 'rescheduled',
        'doseId': doseId ?? 'snoozed_$newId',
        'notificationId': newId,
        'at': newTime.toUtc().toIso8601String(),
        'title': title,
        'body': body,
      });
      list.add(entry);
      await _prefs!.setStringList(_kMedicationRemindersKey, list);
    }

    final payloadMap = <String, dynamic>{
      'action': _kPayloadOpenMedications,
      'title': title,
      'body': body,
    };
    if (medicationId != null) payloadMap['medicationId'] = medicationId;
    if (doseId != null) payloadMap['doseId'] = doseId;
    if (dateKey != null) payloadMap['dateKey'] = dateKey;
    if (isTest) payloadMap['isTest'] = true;
    final payload = jsonEncode(payloadMap);

    if (_pluginAvailable && _plugin != null) {
      try {
        final scheduled = tz.TZDateTime.from(newTime.toUtc(), tz.local);
        await _zonedScheduleWithFallback(
          id: newId,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: _medicationNotificationDetails,
          payload: payload,
        );
      } catch (e) {
        debugPrint('Failed to reschedule reminder: $e');
      }
    }

    show(
      'Reminder rescheduled',
      isTest
          ? 'We will remind you again in 10 seconds'
          : 'We will remind you again in 1 hour',
    );
  }

  /// Handle "Mark as taken" action by dismissing the notification, recording
  /// the dose as [DoseStatus.taken], updating the home-screen pill widget, and
  /// notifying any mounted foreground listeners.
  Future<void> handleMarkMedicationTaken(NotificationResponse response) async {
    if (response.id != null && _pluginAvailable && _plugin != null) {
      try {
        await _plugin!.cancel(id: response.id!);
      } catch (_) {}
    }

    String? medicationId;
    String? doseId;
    String? dateKey;

    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        if (response.payload!.startsWith('{')) {
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          medicationId = data['medicationId'] as String?;
          doseId = data['doseId'] as String?;
          dateKey = data['dateKey'] as String?;
        }
      } catch (_) {}
    }

    if (doseId != null && doseId.isNotEmpty && medicationId != null) {
      final resolvedDateKey =
          dateKey ??
          _extractDateKeyFromDoseId(doseId) ??
          Medication.dateToKey(DateTime.now());
      final repo = LocalMedicationRepository(prefs: _prefs);
      await repo.recordDoseStatus(
        doseId: doseId,
        medicationId: medicationId,
        dateKey: resolvedDateKey,
        status: DoseStatus.taken,
      );

      if (_prefs != null) {
        final list =
            _prefs!.getStringList(_kMedicationRemindersKey) ?? <String>[];
        final updated = list.where((raw) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            return map['doseId'] != doseId;
          } catch (_) {
            return true;
          }
        }).toList();
        await _prefs!.setStringList(_kMedicationRemindersKey, updated);
      }

      final summary = await repo.getWidgetSummary(DateTime.now());
      await WidgetService.instance.updateMedicationWidget(summary);
      medicationUpdatesNotifier.value++;
    }
  }

  String? _extractDateKeyFromDoseId(String doseId) {
    final match = RegExp(r'_(\d{4}-\d{2}-\d{2})_\d{4}$').firstMatch(doseId);
    return match?.group(1);
  }

  /// Schedules a zoned notification using exact alarms when permitted, falling
  /// back to inexact alarms on Android 14+ when exact alarm permission is denied.
  Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required String payload,
  }) async {
    try {
      await _plugin!.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        await _plugin!.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Deterministic 32-bit notification ID for a task (range 10000..1009999).
  static int taskNotificationId(String taskId) {
    return (taskId.hashCode & 0x7FFFFFFF) % 1000000 + 10000;
  }

  /// Synchronizes all task-related OS notifications (individual task reminders,
  /// morning digest, and evening pile-up nudge) with [tasks] and [settings].
  Future<void> syncTaskNotifications({
    required List<Task> tasks,
    required SettingsRepository settings,
  }) async {
    // Cancel legacy start-of-day ID if present from older app versions.
    await _cancelPlatformId(_kLegacyStartNotificationId);

    // 1. Respect master & per-feature switches for individual reminders.
    if (!settings.taskRemindersEnabled()) {
      await cancelAllTaskReminders();
    } else {
      final now = DateTime.now();
      final activeIds = <int>{};

      for (final task in tasks) {
        if (task.archived || task.completed || !task.reminderEnabled) continue;

        final due = effectiveDueDate(task, now: now);
        if (due == null) continue;

        final offset = Duration(minutes: task.reminderOffsetMinutes ?? 60);
        final triggerAt = due.toLocal().subtract(offset);

        // Never fire stale past reminders; let the morning digest handle overdue items.
        if (triggerAt.isBefore(now)) continue;

        final notifId = taskNotificationId(task.id);
        activeIds.add(notifId);

        await _scheduleSingleTaskReminder(
          id: notifId,
          task: task,
          triggerAt: triggerAt,
        );
      }

      // Cancel any scheduled task reminders whose tasks were completed, deleted, or turned off.
      await _cancelOrphanedTaskReminders(keepIds: activeIds);
    }

    // 2. Refresh daily digest & evening pile-up check-in.
    if (settings.taskDailyDigestEnabled()) {
      await _scheduleMorningDigest(tasks, settings.notificationStart());
    } else {
      await _cancelPlatformId(morningDigestNotificationId);
    }

    if (settings.taskPileupNudgeEnabled()) {
      await _scheduleEveningPileupCheck(tasks, settings.notificationEnd());
    } else {
      await _cancelPlatformId(eveningPileupNotificationId);
    }
  }

  Future<void> _cancelPlatformId(int id) async {
    if (_pluginAvailable && _plugin != null) {
      try {
        await _plugin!.cancel(id: id);
      } catch (_) {}
    }
  }

  Future<void> cancelAllTaskReminders() async {
    if (_prefs != null) {
      final rawIds =
          _prefs!.getStringList(_kScheduledTaskReminderIdsKey) ?? <String>[];
      for (final raw in rawIds) {
        final id = int.tryParse(raw);
        if (id != null) {
          await _cancelPlatformId(id);
        }
      }
      await _prefs!.setStringList(_kScheduledTaskReminderIdsKey, <String>[]);
      await _prefs!.setStringList(_kRemindersKey, <String>[]);
    }
  }

  Future<void> _cancelOrphanedTaskReminders({
    required Set<int> keepIds,
  }) async {
    if (_prefs == null) return;
    final rawIds =
        _prefs!.getStringList(_kScheduledTaskReminderIdsKey) ?? <String>[];
    for (final raw in rawIds) {
      final id = int.tryParse(raw);
      if (id != null && !keepIds.contains(id)) {
        await _cancelPlatformId(id);
      }
    }
    await _prefs!.setStringList(
      _kScheduledTaskReminderIdsKey,
      keepIds.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _scheduleSingleTaskReminder({
    required int id,
    required Task task,
    required DateTime triggerAt,
  }) async {
    if (!_pluginAvailable || _plugin == null) return;
    try {
      final scheduled = tz.TZDateTime.from(triggerAt.toUtc(), tz.local);
      final color = _getColorForPriority(task.priority.index);
      final details = buildNotificationDetails(
        NotificationChannelType.taskReminders,
        color: color,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            _kActionTaskDone,
            'Done',
            cancelNotification: true,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            _kActionTaskSmartReschedule,
            'Smart Reschedule',
            cancelNotification: true,
            showsUserInterface: false,
          ),
        ],
      );
      final payload = jsonEncode({
        'action': _kPayloadOpenTasks,
        'taskId': task.id,
      });
      await _zonedScheduleWithFallback(
        id: id,
        title: 'Task due',
        body: task.title,
        scheduledDate: scheduled,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to schedule single task reminder: $e');
    }
  }

  /// Builds the morning digest title, body, and payload for [tasks] at [now],
  /// or returns `null` when both due-today and overdue counts are 0.
  static ({String title, String body, String payload})? buildMorningDigestContent(
    List<Task> tasks, {
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final dueToday = <Task>[];
    final overdue = <Task>[];

    for (final t in tasks) {
      if (t.archived || t.completed) continue;
      final due = effectiveDueDate(t, now: ref);
      if (due == null) continue;
      final localDue = due.toLocal();
      final day = DateTime(localDue.year, localDue.month, localDue.day);
      if (day.isBefore(today)) {
        overdue.add(t);
      } else if (day.isAtSameMomentAs(today)) {
        dueToday.add(t);
      }
    }

    if (dueToday.isEmpty && overdue.isEmpty) {
      return null;
    }

    if (overdue.length >= 3) {
      final dueCount = dueToday.length;
      final overdueCount = overdue.length;
      final dueLabel = '$dueCount ${dueCount == 1 ? 'task' : 'tasks'} due today';
      return (
        title: '$dueLabel · $overdueCount piled up',
        body: 'Tap to auto-balance your backlog across this week.',
        payload: jsonEncode({'action': _kPayloadOpenTasksRebalance}),
      );
    }

    final combined = <Task>[...overdue, ...dueToday]
      ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
    final total = combined.length;
    final topTitles = combined.take(2).map((t) => t.title.trim()).join(', ');
    final remaining = total - combined.take(2).length;
    final body = remaining > 0 ? '$topTitles +$remaining more' : topTitles;

    return (
      title: "Today's Plan: $total ${total == 1 ? 'task' : 'tasks'}",
      body: body,
      payload: jsonEncode({'action': _kPayloadOpenTasks}),
    );
  }

  Future<void> _scheduleMorningDigest(
    List<Task> tasks,
    TimeOfDay start,
  ) async {
    final content = buildMorningDigestContent(tasks);
    if (content == null) {
      await _cancelPlatformId(morningDigestNotificationId);
      return;
    }
    if (!_pluginAvailable || _plugin == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var nextStart = tz.TZDateTime(
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

    try {
      await _zonedScheduleWithFallback(
        id: morningDigestNotificationId,
        title: content.title,
        body: content.body,
        scheduledDate: nextStart,
        notificationDetails: buildNotificationDetails(
          NotificationChannelType.taskDigest,
        ),
        payload: content.payload,
      );
    } catch (e) {
      debugPrint('Failed to schedule morning digest: $e');
    }
  }

  Future<void> _scheduleEveningPileupCheck(
    List<Task> tasks,
    TimeOfDay end,
  ) async {
    final ref = DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    int unfinishedCount = 0;

    for (final t in tasks) {
      if (t.archived || t.completed) continue;
      final due = effectiveDueDate(t, now: ref);
      if (due == null) continue;
      final localDue = due.toLocal();
      final day = DateTime(localDue.year, localDue.month, localDue.day);
      if (!day.isAfter(today)) {
        unfinishedCount++;
      }
    }

    if (unfinishedCount < 3) {
      await _cancelPlatformId(eveningPileupNotificationId);
      return;
    }
    if (!_pluginAvailable || _plugin == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var nextEnd = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      end.hour,
      end.minute,
    );
    if (!nextEnd.isAfter(now)) {
      nextEnd = nextEnd.add(const Duration(days: 1));
    }

    try {
      await _zonedScheduleWithFallback(
        id: eveningPileupNotificationId,
        title: '$unfinishedCount tasks still open today',
        body: 'Tap to auto-balance unfinished tasks into lighter days.',
        scheduledDate: nextEnd,
        notificationDetails: buildNotificationDetails(
          NotificationChannelType.taskDigest,
        ),
        payload: jsonEncode({'action': _kPayloadOpenTasksRebalance}),
      );
    } catch (e) {
      debugPrint('Failed to schedule evening pile-up nudge: $e');
    }
  }

  Future<void> _ensureTaskHiveBoxesOpen() async {
    try {
      if (!Hive.isBoxOpen('tasks')) {
        await Hive.initFlutter();
      }
      await Future.wait([
        if (!Hive.isBoxOpen('tasks')) Hive.openBox('tasks'),
        if (!Hive.isBoxOpen('tasks_meta')) Hive.openBox('tasks_meta'),
        if (!Hive.isBoxOpen('history')) Hive.openBox('history'),
      ]);
    } catch (e) {
      debugPrint('Failed to open Hive boxes in notification handler: $e');
    }
  }

  String? _extractTaskId(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return null;
    try {
      if (raw.startsWith('{')) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return map['taskId'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _enqueueTaskSaveIfSyncEnabled(Task updated, Task previous) async {
    if (_prefs == null) return;
    final settings = SettingsRepository(_prefs!);
    if (settings.getSyncMode() == SyncMode.localOnly) return;
    final wq = WriteQueue(_prefs!);
    final uid = _prefs!.getString(_kActiveUserIdKey);
    if (uid != null && uid.isNotEmpty) {
      wq.setUserId(uid);
    }
    final payload = updated.toMap();
    try {
      payload['_previous'] = previous.toMap();
    } catch (_) {}
    wq.enqueueOp(
      QueueOp(type: QueueOpType.saveTask, id: updated.id, payload: payload),
    );
  }

  /// Zero-open notification action: marks the task (or today's occurrence for
  /// repeating tasks) complete in [TaskRepository] and [WriteQueue].
  Future<void> handleTaskDone(NotificationResponse response) async {
    if (response.id != null) {
      await _cancelPlatformId(response.id!);
    }
    final taskId = _extractTaskId(response);
    if (taskId == null || taskId.isEmpty || _prefs == null) return;

    await _ensureTaskHiveBoxesOpen();
    final repo = TaskRepository(_prefs!);
    final tasks = repo.loadTasks();
    final idx = tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final task = tasks[idx];
    final todayStr = DateTime.now().toUtc().toIso8601String().split('T')[0];
    final Task updated;
    if (task.isRepeating) {
      final dates = List<String>.from(task.completedDates ?? <String>[]);
      if (!dates.contains(todayStr)) dates.add(todayStr);
      updated = task.copyWith(
        completedDates: dates,
        syncStatus: SyncStatus.pending,
      );
    } else {
      updated = task.copyWith(completed: true, syncStatus: SyncStatus.pending);
    }

    final nextList = List<Task>.from(tasks)..[idx] = updated;
    await repo.saveTasks(nextList);
    await _enqueueTaskSaveIfSyncEnabled(updated, task);
    await syncTaskNotifications(
      tasks: nextList,
      settings: SettingsRepository(_prefs!),
    );
    taskUpdatesNotifier.value++;
  }

  /// Zero-open notification action: runs [TaskRescheduler.suggestBestDate],
  /// moves the task to the lightest upcoming day, and reschedules its alarm.
  Future<void> handleTaskSmartReschedule(NotificationResponse response) async {
    if (response.id != null) {
      await _cancelPlatformId(response.id!);
    }
    final taskId = _extractTaskId(response);
    if (taskId == null || taskId.isEmpty || _prefs == null) return;

    await _ensureTaskHiveBoxesOpen();
    final repo = TaskRepository(_prefs!);
    final tasks = repo.loadTasks();
    final idx = tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final task = tasks[idx];
    final suggestion = TaskRescheduler.suggestBestDate(task, tasks);
    final origTime = (task.deadline ?? DateTime.now()).toLocal();
    final target = DateTime(
      suggestion.targetDate.year,
      suggestion.targetDate.month,
      suggestion.targetDate.day,
      origTime.hour,
      origTime.minute,
    ).toUtc();

    final updated = task.copyWith(
      deadline: target,
      inactiveUntil: task.isRepeating ? target : task.inactiveUntil,
      putOffCount: task.putOffCount + 1,
      syncStatus: SyncStatus.pending,
    );

    final nextList = List<Task>.from(tasks)..[idx] = updated;
    await repo.saveTasks(nextList);
    await _enqueueTaskSaveIfSyncEnabled(updated, task);
    await syncTaskNotifications(
      tasks: nextList,
      settings: SettingsRepository(_prefs!),
    );
    taskUpdatesNotifier.value++;
  }

  /// Cancel all scheduled medication notifications across all medications.
  Future<void> cancelAllMedicationReminders() async {
    if (_prefs == null) return;
    final list = _prefs!.getStringList(_kMedicationRemindersKey) ?? <String>[];
    for (final s in list) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        final notificationId = m['notificationId'] as int?;
        if (notificationId != null) {
          await _cancelPlatformId(notificationId);
        }
      } catch (_) {}
    }
    await _prefs!.setStringList(_kMedicationRemindersKey, <String>[]);
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

  /// Schedule upcoming medication notifications for the next [daysAhead] days (default 14).
  /// Stale notifications for this medication are first canceled.
  Future<void> scheduleMedicationReminders(
    Medication medication, {
    int daysAhead = 14,
  }) async {
    await cancelMedicationReminders(medication.id);
    if (!medication.isActive || medication.notificationTimes.isEmpty) return;
    if (_prefs == null) return;
    if (!SettingsRepository(_prefs!).medicationNotificationsEnabled()) return;

    final list = _prefs!.getStringList(_kMedicationRemindersKey) ?? <String>[];
    final now = DateTime.now();

    for (var d = 0; d < daysAhead; d++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: d));
      if (!medication.isScheduledForDate(date)) continue;

      for (final time in medication.notificationTimes) {
        final scheduledLocal = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (scheduledLocal.isBefore(now)) continue;

        final doseId = Medication.doseIdFor(medication.id, date, time);
        final notificationId = _hashId('med_$doseId');
        const title = 'Medication reminder';
        final body = medication.dosage.isNotEmpty
            ? '${medication.name} (${medication.dosage})'
            : medication.name;

        final entry = jsonEncode({
          'medicationId': medication.id,
          'doseId': doseId,
          'notificationId': notificationId,
          'at': scheduledLocal.toUtc().toIso8601String(),
          'title': title,
          'body': body,
        });
        list.add(entry);

        final payload = jsonEncode({
          'action': _kPayloadOpenMedications,
          'medicationId': medication.id,
          'doseId': doseId,
          'dateKey': Medication.dateToKey(date),
          'title': title,
          'body': body,
        });

        if (_pluginAvailable && _plugin != null) {
          try {
            final scheduled = tz.TZDateTime.from(
              scheduledLocal.toUtc(),
              tz.local,
            );
            await _zonedScheduleWithFallback(
              id: notificationId,
              title: title,
              body: body,
              scheduledDate: scheduled,
              notificationDetails: _medicationNotificationDetails,
              payload: payload,
            );
          } catch (e) {
            debugPrint('Failed to schedule platform medication reminder: $e');
          }
        }
      }
    }

    await _prefs!.setStringList(_kMedicationRemindersKey, list);
  }

  /// Cancel all scheduled notifications for a given medication.
  Future<void> cancelMedicationReminders(String medicationId) async {
    if (_prefs == null) return;
    final list = _prefs!.getStringList(_kMedicationRemindersKey) ?? <String>[];
    final remaining = <String>[];

    for (final s in list) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        if (m['medicationId'] == medicationId) {
          final notificationId = m['notificationId'] as int?;
          if (notificationId != null && _pluginAvailable && _plugin != null) {
            try {
              await _plugin!.cancel(id: notificationId);
            } catch (_) {}
          }
        } else {
          remaining.add(s);
        }
      } catch (_) {
        // drop malformed entry
      }
    }

    await _prefs!.setStringList(_kMedicationRemindersKey, remaining);
  }

  /// Reschedule all active medications (or cancel all if medication notifications
  /// are disabled in settings).
  Future<void> rescheduleAllMedications(List<Medication> medications) async {
    if (_prefs != null &&
        !SettingsRepository(_prefs!).medicationNotificationsEnabled()) {
      await cancelAllMedicationReminders();
      return;
    }
    for (final med in medications) {
      if (med.isActive) {
        await scheduleMedicationReminders(med);
      } else {
        await cancelMedicationReminders(med.id);
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

    final medList =
        _prefs!.getStringList(_kMedicationRemindersKey) ?? <String>[];
    final medRemaining = <String>[];
    for (final s in medList) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        final at = DateTime.parse(m['at']).toUtc();
        if (!at.isAfter(now)) {
          final title = (m['title'] as String?) ?? 'Medication reminder';
          final body = (m['body'] as String?) ?? '';
          show(title, body, duration: const Duration(seconds: 6));
        } else {
          medRemaining.add(s);
        }
      } catch (_) {
        // Keep malformed entries out of firing
      }
    }
    await _prefs!.setStringList(_kMedicationRemindersKey, medRemaining);
  }
}
