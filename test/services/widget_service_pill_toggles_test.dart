import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/medication.dart';
import 'package:housekeepr/repositories/local_medication_repository.dart';
import 'package:housekeepr/services/widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WidgetService.reconcilePendingPillTogglesData', () {
    late LocalMedicationRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repository = LocalMedicationRepository(prefs: prefs);
      await repository.saveMedication(
        Medication(
          id: 'med-1',
          name: 'Vitamin D',
          startDate: DateTime(2026, 11, 1),
          notificationTimes: [
            MedicationTime(hour: 8, minute: 0),
            MedicationTime(hour: 20, minute: 0),
          ],
        ),
      );
    });

    test('applies date-stamped toggle to the exact recorded date', () async {
      final yesterday = DateTime(2026, 11, 19);
      final today = DateTime(2026, 11, 20);

      await WidgetService.instance.reconcilePendingPillTogglesData(
        'morning:true:2026-11-19',
        repository,
        now: today,
      );

      final yesterdaySummary = await repository.getWidgetSummary(yesterday);
      final todaySummary = await repository.getWidgetSummary(today);

      expect(yesterdaySummary.isMorningTaken, isTrue);
      expect(yesterdaySummary.isEveningTaken, isFalse);
      expect(todaySummary.isMorningTaken, isFalse);
      expect(todaySummary.isEveningTaken, isFalse);
    });

    test('applies today toggle and legacy 2-part toggle to fallback now date', () async {
      final today = DateTime(2026, 11, 20);

      await WidgetService.instance.reconcilePendingPillTogglesData(
        'morning:true,evening:true:2026-11-20',
        repository,
        now: today,
      );

      final todaySummary = await repository.getWidgetSummary(today);
      expect(todaySummary.isMorningTaken, isTrue);
      expect(todaySummary.isEveningTaken, isTrue);
    });
  });
}
