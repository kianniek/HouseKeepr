import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NotificationService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('deterministic task notification IDs stay in 10000..1009999', () {
      final id1 = NotificationService.taskNotificationId('task-abc-123');
      final id2 = NotificationService.taskNotificationId('task-abc-123');
      final id3 = NotificationService.taskNotificationId('task-xyz-999');

      expect(id1, equals(id2));
      expect(id1, greaterThanOrEqualTo(10000));
      expect(id1, lessThan(1010000));
      expect(id3, greaterThanOrEqualTo(10000));
      expect(id3, lessThan(1010000));
      expect(
        id1,
        isNot(equals(NotificationService.morningDigestNotificationId)),
      );
      expect(
        id1,
        isNot(equals(NotificationService.eveningPileupNotificationId)),
      );
    });

    test(
      'channelConfigs defines distinct Android priority/importance rules',
      () {
        final digest = NotificationService
            .channelConfigs[NotificationChannelType.taskDigest]!;
        final reminders = NotificationService
            .channelConfigs[NotificationChannelType.taskReminders]!;
        final meds = NotificationService
            .channelConfigs[NotificationChannelType.medications]!;

        expect(digest.id, equals('housekeepr_task_digest'));
        expect(digest.androidImportance, equals(Importance.defaultImportance));
        expect(digest.enableVibration, isFalse);

        expect(reminders.id, equals('housekeepr_task_reminders'));
        expect(reminders.androidImportance, equals(Importance.high));
        expect(reminders.androidPriority, equals(Priority.high));

        expect(meds.id, equals('housekeepr_medications'));
        expect(meds.androidImportance, equals(Importance.max));
      },
    );

    test('buildMorningDigestContent returns null when 0 due and 0 overdue', () {
      final now = DateTime(2026, 11, 16, 8, 0);
      final futureTask = Task(
        id: 't1',
        title: 'Future task',
        deadline: DateTime(2026, 11, 18, 12, 0),
      );

      final content = NotificationService.buildMorningDigestContent([
        futureTask,
      ], now: now);
      expect(content, isNull);
    });

    test(
      'buildMorningDigestContent lists top 2 prioritized titles on normal day',
      () {
        final now = DateTime(2026, 11, 16, 8, 0);
        final tasks = [
          Task(
            id: 't1',
            title: 'Low prio',
            priority: TaskPriority.low,
            deadline: DateTime(2026, 11, 16, 12, 0),
          ),
          Task(
            id: 't2',
            title: 'Urgent task',
            priority: TaskPriority.urgent,
            deadline: DateTime(2026, 11, 16, 12, 0),
          ),
          Task(
            id: 't3',
            title: 'High task',
            priority: TaskPriority.high,
            deadline: DateTime(2026, 11, 16, 14, 0),
          ),
        ];

        final content = NotificationService.buildMorningDigestContent(
          tasks,
          now: now,
        );
        expect(content, isNotNull);
        expect(content!.title, equals("Today's Plan: 3 tasks"));
        expect(content.body, equals('Urgent task, High task +1 more'));
      },
    );

    test(
      'buildMorningDigestContent uses open_tasks_rebalance when >= 3 overdue',
      () {
        final now = DateTime(2026, 11, 16, 8, 0);
        final tasks = [
          Task(
            id: 'o1',
            title: 'Overdue 1',
            deadline: DateTime(2026, 11, 14, 12, 0),
          ),
          Task(
            id: 'o2',
            title: 'Overdue 2',
            deadline: DateTime(2026, 11, 14, 12, 0),
          ),
          Task(
            id: 'o3',
            title: 'Overdue 3',
            deadline: DateTime(2026, 11, 15, 12, 0),
          ),
          Task(
            id: 'd1',
            title: 'Due today',
            deadline: DateTime(2026, 11, 16, 12, 0),
          ),
        ];

        final content = NotificationService.buildMorningDigestContent(
          tasks,
          now: now,
        );
        expect(content, isNotNull);
        expect(content!.title, equals('1 task due today · 3 piled up'));
        final payload = jsonDecode(content.payload) as Map<String, dynamic>;
        expect(payload['action'], equals('open_tasks_rebalance'));
      },
    );

    test(
      'syncTaskNotifications tracks active IDs and clears when disabled',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final settings = SettingsRepository(prefs);
        await NotificationService.instance.init(prefs);

        final futureDue = DateTime.now().add(const Duration(hours: 3));
        final tasks = [
          Task(
            id: 't-active',
            title: 'Active reminder',
            deadline: futureDue,
            reminderEnabled: true,
            reminderOffsetMinutes: 30,
          ),
          Task(
            id: 't-past',
            title: 'Past reminder',
            deadline: DateTime.now().subtract(const Duration(hours: 2)),
            reminderEnabled: true,
            reminderOffsetMinutes: 30,
          ),
          Task(
            id: 't-off',
            title: 'No reminder',
            deadline: futureDue,
            reminderEnabled: false,
          ),
        ];

        await NotificationService.instance.syncTaskNotifications(
          tasks: tasks,
          settings: settings,
        );

        final storedIds = prefs.getStringList('scheduled_task_reminder_ids_v1');
        expect(
          storedIds,
          equals([
            NotificationService.taskNotificationId('t-active').toString(),
          ]),
        );

        await settings.setTaskRemindersEnabled(false);
        await NotificationService.instance.syncTaskNotifications(
          tasks: tasks,
          settings: settings,
        );

        expect(prefs.getStringList('scheduled_task_reminder_ids_v1'), isEmpty);
      },
    );
  });
}
