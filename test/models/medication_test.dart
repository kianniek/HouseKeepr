import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/medication.dart';

void main() {
  group('MedicationTime and Slots', () {
    test('classifies hours before 17:00 as morning and 17:00+ as evening', () {
      final morning = MedicationTime(hour: 8, minute: 30);
      final midday = MedicationTime(hour: 16, minute: 59);
      final evening = MedicationTime(hour: 17, minute: 0);
      final night = MedicationTime(hour: 22, minute: 15);

      expect(morning.slot, equals(TimeOfDaySlot.morning));
      expect(midday.slot, equals(TimeOfDaySlot.morning));
      expect(evening.slot, equals(TimeOfDaySlot.evening));
      expect(night.slot, equals(TimeOfDaySlot.evening));
    });

    test('formats 24h string correctly', () {
      final time = MedicationTime(hour: 9, minute: 5);
      expect(time.format24h(), equals('09:05'));
    });

    test('serializes and deserializes MedicationTime', () {
      final time = MedicationTime(hour: 14, minute: 45);
      final map = time.toMap();
      final restored = MedicationTime.fromMap(map);

      expect(restored, equals(time));
      expect(restored.slot, equals(TimeOfDaySlot.morning));
    });
  });

  group('Medication Recurrence & Eligibility', () {
    final baseStart = DateTime(2026, 11, 10);

    test('daily recurrence is scheduled every day between start and end', () {
      final med = Medication(
        id: 'med_daily',
        name: 'Vitamin D',
        dosage: '1000 IU',
        recurrenceType: MedicationRecurrenceType.daily,
        startDate: baseStart,
        endDate: DateTime(2026, 11, 15),
        notificationTimes: [MedicationTime(hour: 9, minute: 0)],
      );

      expect(med.isScheduledForDate(DateTime(2026, 11, 9)), isFalse);
      expect(med.isScheduledForDate(DateTime(2026, 11, 10)), isTrue);
      expect(med.isScheduledForDate(DateTime(2026, 11, 12)), isTrue);
      expect(med.isScheduledForDate(DateTime(2026, 11, 15)), isTrue);
      expect(med.isScheduledForDate(DateTime(2026, 11, 16)), isFalse);
    });

    test('specificDaysOfWeek only triggers on specified days', () {
      // 2026-11-09 is Monday (weekday 1)
      // 2026-11-10 is Tuesday (weekday 2)
      // 2026-11-11 is Wednesday (weekday 3)
      final med = Medication(
        id: 'med_days',
        name: 'Antibiotic',
        recurrenceType: MedicationRecurrenceType.specificDaysOfWeek,
        daysOfWeek: const [1, 3], // Monday and Wednesday
        startDate: DateTime(2026, 11, 9),
        notificationTimes: [MedicationTime(hour: 8, minute: 0)],
      );

      expect(med.isScheduledForDate(DateTime(2026, 11, 9)), isTrue); // Mon
      expect(med.isScheduledForDate(DateTime(2026, 11, 10)), isFalse); // Tue
      expect(med.isScheduledForDate(DateTime(2026, 11, 11)), isTrue); // Wed
      expect(med.isScheduledForDate(DateTime(2026, 11, 12)), isFalse); // Thu
    });

    test('intervalDays triggers every N days from startDate', () {
      final med = Medication(
        id: 'med_interval',
        name: 'Iron Supplement',
        recurrenceType: MedicationRecurrenceType.intervalDays,
        intervalDays: 2, // Every 2 days
        startDate: baseStart, // Nov 10
        notificationTimes: [MedicationTime(hour: 20, minute: 0)],
      );

      expect(med.isScheduledForDate(DateTime(2026, 11, 10)), isTrue); // Day 0
      expect(med.isScheduledForDate(DateTime(2026, 11, 11)), isFalse); // Day 1
      expect(med.isScheduledForDate(DateTime(2026, 11, 12)), isTrue); // Day 2
      expect(med.isScheduledForDate(DateTime(2026, 11, 13)), isFalse); // Day 3
      expect(med.isScheduledForDate(DateTime(2026, 11, 14)), isTrue); // Day 4
    });

    test('inactive medication is never scheduled', () {
      final med = Medication(
        id: 'med_inactive',
        name: 'Inactive Med',
        isActive: false,
        startDate: baseStart,
        notificationTimes: [MedicationTime(hour: 8, minute: 0)],
      );

      expect(med.isScheduledForDate(DateTime(2026, 11, 10)), isFalse);
    });
  });

  group('Dose Generation & Merging', () {
    test('generates doses and maps them to status records', () {
      final date = DateTime(2026, 11, 12);
      final med = Medication(
        id: 'med_1',
        name: 'Blood Pressure',
        dosage: '10mg',
        startDate: DateTime(2026, 11, 1),
        notificationTimes: [
          MedicationTime(hour: 8, minute: 0),
          MedicationTime(hour: 20, minute: 0),
        ],
      );

      final morningDoseId = Medication.doseIdFor(
        'med_1',
        date,
        MedicationTime(hour: 8, minute: 0),
      );

      final records = {
        morningDoseId: DoseRecord(
          doseId: morningDoseId,
          medicationId: 'med_1',
          dateKey: '2026-11-12',
          status: DoseStatus.taken,
          timestamp: DateTime(2026, 11, 12, 8, 5),
        ),
      };

      final doses = med.generateDosesForDate(date, doseRecords: records);

      expect(doses.length, equals(2));
      final morningDose = doses.firstWhere((d) => d.id == morningDoseId);
      final eveningDose = doses.firstWhere((d) => d.id != morningDoseId);

      expect(morningDose.slot, equals(TimeOfDaySlot.morning));
      expect(morningDose.status, equals(DoseStatus.taken));
      expect(morningDose.isTaken, isTrue);

      expect(eveningDose.slot, equals(TimeOfDaySlot.evening));
      expect(eveningDose.status, equals(DoseStatus.pending));
      expect(eveningDose.isPending, isTrue);
    });
  });

  group('Serialization and Deserialization', () {
    test('Medication roundtrips JSON cleanly', () {
      final med = Medication(
        id: 'med_roundtrip',
        name: 'Allergy Med',
        dosage: '5mg',
        isActive: true,
        recurrenceType: MedicationRecurrenceType.specificDaysOfWeek,
        daysOfWeek: const [1, 2, 4, 6],
        intervalDays: 1,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 12, 31),
        notificationTimes: [
          MedicationTime(hour: 7, minute: 30),
          MedicationTime(hour: 19, minute: 0),
        ],
      );

      final jsonString = med.toJson();
      final restored = Medication.fromJson(jsonString);

      expect(restored.id, equals(med.id));
      expect(restored.name, equals(med.name));
      expect(restored.dosage, equals(med.dosage));
      expect(restored.isActive, equals(med.isActive));
      expect(restored.recurrenceType, equals(med.recurrenceType));
      expect(restored.daysOfWeek, equals(med.daysOfWeek));
      expect(restored.notificationTimes.length, equals(2));
      expect(restored.notificationTimes[0].format24h(), equals('07:30'));
      expect(restored.notificationTimes[1].format24h(), equals('19:00'));
    });
  });
}
