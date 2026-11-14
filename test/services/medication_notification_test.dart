import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/medication.dart';
import 'package:housekeepr/repositories/local_medication_repository.dart';
import 'package:housekeepr/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await NotificationService.instance.init(prefs);
  });

  group('Medication Notification Scheduling', () {
    test(
      'schedules upcoming medication reminders in SharedPreferences store',
      () async {
        final now = DateTime.now();
        final med = Medication(
          id: 'med_notif_1',
          name: 'Blood Pressure Med',
          dosage: '10mg',
          startDate: now,
          notificationTimes: [MedicationTime(hour: 23, minute: 59)],
        );

        await NotificationService.instance.scheduleMedicationReminders(med);

        final list = prefs.getStringList('scheduled_medication_reminders_v1');
        expect(list, isNotNull);
        expect(list!.isNotEmpty, isTrue);
        expect(list.any((e) => e.contains('Blood Pressure Med')), isTrue);
      },
    );

    test('canceling removes medication reminders from store', () async {
      final now = DateTime.now();
      final med = Medication(
        id: 'med_to_cancel',
        name: 'Iron',
        startDate: now,
        notificationTimes: [MedicationTime(hour: 23, minute: 58)],
      );

      await NotificationService.instance.scheduleMedicationReminders(med);
      var list = prefs.getStringList('scheduled_medication_reminders_v1');
      expect(list!.any((e) => e.contains('Iron')), isTrue);

      await NotificationService.instance.cancelMedicationReminders(
        'med_to_cancel',
      );
      list = prefs.getStringList('scheduled_medication_reminders_v1');
      expect(list!.any((e) => e.contains('Iron')), isFalse);
    });

    test(
      'rescheduling cancels previous entries and schedules updated ones',
      () async {
        final now = DateTime.now();
        final med = Medication(
          id: 'med_resched',
          name: 'Original Med Name',
          startDate: now,
          notificationTimes: [MedicationTime(hour: 23, minute: 50)],
        );

        await NotificationService.instance.scheduleMedicationReminders(med);

        // Edit medication name
        final updatedMed = med.copyWith(name: 'Updated Med Name');
        await NotificationService.instance.scheduleMedicationReminders(
          updatedMed,
        );

        final list = prefs.getStringList('scheduled_medication_reminders_v1');
        expect(list!.any((e) => e.contains('Original Med Name')), isFalse);
        expect(list.any((e) => e.contains('Updated Med Name')), isTrue);
      },
    );

    test('inactive medication does not schedule reminders', () async {
      final now = DateTime.now();
      final med = Medication(
        id: 'med_inactive',
        name: 'Inactive',
        isActive: false,
        startDate: now,
        notificationTimes: [MedicationTime(hour: 23, minute: 45)],
      );

      await NotificationService.instance.scheduleMedicationReminders(med);
      final list = prefs.getStringList('scheduled_medication_reminders_v1');
      expect(list, isEmpty);
    });

    test('showTestMedicationNotification executes without error', () async {
      await NotificationService.instance.showTestMedicationNotification(
        medicationName: 'Multivitamin',
        dosage: '1 gummy',
      );
      // Completes successfully in all test environments
    });

    test('handleRemindLater reschedules reminder for 1 hour later', () async {
      final payload = jsonEncode({
        'action': 'open_medications',
        'medicationId': 'med_snooze',
        'doseId': 'dose_snooze',
        'title': 'Medication reminder',
        'body': 'Aspirin (100mg)',
      });

      final response = NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: 'remind_later',
        id: 9999,
        payload: payload,
      );

      await NotificationService.instance.handleRemindLater(response);

      final list = prefs.getStringList('scheduled_medication_reminders_v1');
      expect(list, isNotNull);
      expect(list!.isNotEmpty, isTrue);

      final entry = jsonDecode(list.last) as Map<String, dynamic>;
      expect(entry['body'], equals('Aspirin (100mg)'));
      expect(entry['medicationId'], equals('med_snooze'));

      // Check that scheduled time is roughly 1 hour in the future
      final scheduledAt = DateTime.parse(entry['at'] as String);
      final differenceMinutes = scheduledAt
          .difference(DateTime.now().toUtc())
          .inMinutes;
      expect(differenceMinutes, greaterThanOrEqualTo(58));
      expect(differenceMinutes, lessThanOrEqualTo(62));
    });

    test(
      'notificationTapBackground handles remind_later and reschedules 1 hour later',
      () async {
        final payload = jsonEncode({
          'action': 'open_medications',
          'medicationId': 'med_bg_snooze',
          'doseId': 'dose_bg_snooze',
          'title': 'Medication reminder',
          'body': 'Ibuprofen (200mg)',
        });

        final response = NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'remind_later',
          id: 8888,
          payload: payload,
        );

        await notificationTapBackground(response);

        final list = prefs.getStringList('scheduled_medication_reminders_v1');
        expect(list, isNotNull);
        expect(list!.isNotEmpty, isTrue);

        final entry = jsonDecode(list.last) as Map<String, dynamic>;
        expect(entry['body'], equals('Ibuprofen (200mg)'));
        expect(entry['medicationId'], equals('med_bg_snooze'));

        final scheduledAt = DateTime.parse(entry['at'] as String);
        final differenceMinutes = scheduledAt
            .difference(DateTime.now().toUtc())
            .inMinutes;
        expect(differenceMinutes, greaterThanOrEqualTo(58));
        expect(differenceMinutes, lessThanOrEqualTo(62));
      },
    );

    test(
      'handleRemindLater reschedules test notification for 10 seconds later',
      () async {
        final payload = jsonEncode({
          'action': 'open_medications',
          'title': 'Medication reminder',
          'body': 'Vitamin D',
          'isTest': true,
        });

        final response = NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'remind_later',
          id: 7777,
          payload: payload,
        );

        await NotificationService.instance.handleRemindLater(response);

        final list = prefs.getStringList('scheduled_medication_reminders_v1');
        expect(list, isNotNull);
        expect(list!.isNotEmpty, isTrue);

        final entry = jsonDecode(list.last) as Map<String, dynamic>;
        expect(entry['body'], equals('Vitamin D'));

        final scheduledAt = DateTime.parse(entry['at'] as String);
        final differenceSeconds = scheduledAt
            .difference(DateTime.now().toUtc())
            .inSeconds;
        expect(differenceSeconds, greaterThanOrEqualTo(8));
        expect(differenceSeconds, lessThanOrEqualTo(12));
      },
    );

    test(
      'notificationTapBackground handles mark_taken for specific doseId',
      () async {
        final now = DateTime.now();
        final dateKey = Medication.dateToKey(now);
        final morningTime = MedicationTime(hour: 8, minute: 0);
        final eveningTime = MedicationTime(hour: 20, minute: 0);
        final med = Medication(
          id: 'med_mark_taken',
          name: 'Vitamin D',
          dosage: '1000 IU',
          startDate: now,
          notificationTimes: [morningTime, eveningTime],
        );

        final repo = LocalMedicationRepository(prefs: prefs);
        await repo.saveMedication(med);

        final morningDoseId = Medication.doseIdFor(med.id, now, morningTime);
        final eveningDoseId = Medication.doseIdFor(med.id, now, eveningTime);

        await prefs.setStringList('scheduled_medication_reminders_v1', [
          jsonEncode({
            'medicationId': med.id,
            'doseId': morningDoseId,
            'notificationId': 111,
            'at': now.toUtc().toIso8601String(),
          }),
          jsonEncode({
            'medicationId': med.id,
            'doseId': eveningDoseId,
            'notificationId': 222,
            'at': now.toUtc().toIso8601String(),
          }),
        ]);

        final beforeUpdates =
            NotificationService.instance.medicationUpdatesNotifier.value;

        final response = NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'mark_taken',
          id: 111,
          payload: jsonEncode({
            'action': 'open_medications',
            'medicationId': med.id,
            'doseId': morningDoseId,
            'dateKey': dateKey,
            'title': 'Medication reminder',
            'body': 'Vitamin D (1000 IU)',
          }),
        );

        await notificationTapBackground(response);

        final doses = await repo.getDosesForDate(now);
        final morningDose = doses.firstWhere((d) => d.id == morningDoseId);
        final eveningDose = doses.firstWhere((d) => d.id == eveningDoseId);
        expect(morningDose.status, DoseStatus.taken);
        expect(eveningDose.status, DoseStatus.pending);

        final remaining = prefs.getStringList(
          'scheduled_medication_reminders_v1',
        );
        expect(remaining, hasLength(1));
        expect(remaining!.single, contains(eveningDoseId));
        expect(
          NotificationService.instance.medicationUpdatesNotifier.value,
          greaterThan(beforeUpdates),
        );
      },
    );

    test(
      'handleMarkMedicationTaken extracts dateKey from doseId when omitted',
      () async {
        final now = DateTime.now();
        final time = MedicationTime(hour: 9, minute: 30);
        final med = Medication(
          id: 'med_extract_date',
          name: 'Magnesium',
          dosage: '200 mg',
          startDate: now,
          notificationTimes: [time],
        );
        final repo = LocalMedicationRepository(prefs: prefs);
        await repo.saveMedication(med);
        final doseId = Medication.doseIdFor(med.id, now, time);

        final response = NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'mark_taken',
          id: 333,
          payload: jsonEncode({
            'action': 'open_medications',
            'medicationId': med.id,
            'doseId': doseId,
          }),
        );

        await NotificationService.instance.handleMarkMedicationTaken(response);

        final doses = await repo.getDosesForDate(now);
        expect(doses.single.status, DoseStatus.taken);
      },
    );
  });
}
