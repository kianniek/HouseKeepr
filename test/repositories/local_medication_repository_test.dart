import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/medication.dart';
import 'package:housekeepr/repositories/local_medication_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalMedicationRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = LocalMedicationRepository();
  });

  group('LocalMedicationRepository CRUD', () {
    test('starts with empty medications list', () async {
      final list = await repository.getMedications();
      expect(list, isEmpty);
    });

    test('saves, retrieves, and updates medications', () async {
      final med = Medication(
        id: 'med_test_1',
        name: 'Aspirin',
        dosage: '100mg',
        notificationTimes: [MedicationTime(hour: 8, minute: 0)],
      );

      await repository.saveMedication(med);

      var list = await repository.getMedications();
      expect(list.length, equals(1));
      expect(list.first.name, equals('Aspirin'));

      // Update
      final updatedMed = med.copyWith(dosage: '200mg');
      await repository.saveMedication(updatedMed);

      list = await repository.getMedications();
      expect(list.length, equals(1));
      expect(list.first.dosage, equals('200mg'));

      // Get single
      final fetched = await repository.getMedication('med_test_1');
      expect(fetched, isNotNull);
      expect(fetched!.dosage, equals('200mg'));
    });

    test('deletes medication', () async {
      final med = Medication(
        id: 'med_to_delete',
        name: 'Temporary Med',
        notificationTimes: [MedicationTime(hour: 9, minute: 0)],
      );

      await repository.saveMedication(med);
      expect((await repository.getMedications()).length, equals(1));

      await repository.deleteMedication('med_to_delete');
      expect((await repository.getMedications()), isEmpty);
    });

    test('toggles active status', () async {
      final med = Medication(
        id: 'med_active',
        name: 'Omega 3',
        isActive: true,
        notificationTimes: [MedicationTime(hour: 8, minute: 0)],
      );

      await repository.saveMedication(med);
      await repository.setMedicationActive('med_active', false);

      final fetched = await repository.getMedication('med_active');
      expect(fetched!.isActive, isFalse);
    });
  });

  group('Doses & Widget Summary Interactions', () {
    final today = DateTime(2026, 11, 12);

    test('materializes doses for today and groups by slot', () async {
      final med = Medication(
        id: 'med_slots',
        name: 'Daily Pills',
        dosage: '1 tablet',
        startDate: DateTime(2026, 11, 1),
        notificationTimes: [
          MedicationTime(hour: 8, minute: 30), // Morning (Sun)
          MedicationTime(hour: 12, minute: 0), // Morning (Sun)
          MedicationTime(hour: 20, minute: 0), // Evening (Moon)
        ],
      );

      await repository.saveMedication(med);

      final summary = await repository.getWidgetSummary(today);

      expect(summary.hasMorningDoses, isTrue);
      expect(summary.morningDoses.length, equals(2));
      expect(summary.isMorningTaken, isFalse);

      expect(summary.hasEveningDoses, isTrue);
      expect(summary.eveningDoses.length, equals(1));
      expect(summary.isEveningTaken, isFalse);
    });

    test(
      'setSlotDosesStatus flips all doses in a slot to taken/pending',
      () async {
        final med = Medication(
          id: 'med_toggle_slot',
          name: 'Heart Meds',
          dosage: '1 tab',
          startDate: DateTime(2026, 11, 1),
          notificationTimes: [
            MedicationTime(hour: 8, minute: 0), // Morning
            MedicationTime(hour: 10, minute: 0), // Morning
            MedicationTime(hour: 19, minute: 0), // Evening
          ],
        );

        await repository.saveMedication(med);

        // Simulate tapping Sun switch ON
        await repository.setSlotDosesStatus(
          date: today,
          slot: TimeOfDaySlot.morning,
          status: DoseStatus.taken,
        );

        var summary = await repository.getWidgetSummary(today);
        expect(summary.isMorningTaken, isTrue);
        expect(summary.isEveningTaken, isFalse);

        // Evening remains pending
        expect(summary.eveningDoses.first.isPending, isTrue);

        // Now simulate tapping Sun switch OFF (un-toggle back to pending)
        await repository.setSlotDosesStatus(
          date: today,
          slot: TimeOfDaySlot.morning,
          status: DoseStatus.pending,
        );

        summary = await repository.getWidgetSummary(today);
        expect(summary.isMorningTaken, isFalse);
        expect(summary.morningDoses.every((d) => d.isPending), isTrue);
      },
    );

    test('toggleDoseStatus flips an individual dose', () async {
      final med = Medication(
        id: 'med_single_toggle',
        name: 'Single Dose Med',
        startDate: DateTime(2026, 11, 1),
        notificationTimes: [MedicationTime(hour: 9, minute: 0)],
      );

      await repository.saveMedication(med);
      var doses = await repository.getDosesForDate(today);
      expect(doses.first.isPending, isTrue);

      // Toggle to taken
      await repository.toggleDoseStatus(doses.first);
      doses = await repository.getDosesForDate(today);
      expect(doses.first.isTaken, isTrue);

      // Toggle back to pending
      await repository.toggleDoseStatus(doses.first);
      doses = await repository.getDosesForDate(today);
      expect(doses.first.isPending, isTrue);
    });
  });
}
