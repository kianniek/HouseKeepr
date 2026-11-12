import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:housekeepr/models/medication.dart';
import 'package:housekeepr/repositories/local_medication_repository.dart';
import 'package:housekeepr/services/widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalMedicationRepository repo;
  final Map<String, dynamic> mockWidgetStore = {};

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockWidgetStore.clear();

    const channel = MethodChannel('home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'saveWidgetData') {
            final args = call.arguments as Map?;
            final key = (args?['id'] ?? args?['key']) as String?;
            final data = args?['data'] ?? args?['value'];
            if (key != null) {
              mockWidgetStore[key] = data;
            }
            return true;
          } else if (call.method == 'getWidgetData') {
            final args = call.arguments as Map?;
            final key = (args?['id'] ?? args?['key']) as String?;
            return key != null ? mockWidgetStore[key] : null;
          } else if (call.method == 'updateWidget') {
            return true;
          }
          return null;
        });

    repo = LocalMedicationRepository();
  });

  tearDown(() {
    const channel = MethodChannel('home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('WidgetService Pill Widget Integration', () {
    test(
      'updateMedicationWidget formats payload matching Android 2x2 RemoteViews',
      () async {
        final now = DateTime.now();
        final morningDose = DoseInstance(
          id: 'dose_1',
          medicationId: 'med_1',
          medicationName: 'Vitamin C',
          dosage: '500mg',
          scheduledDate: now,
          time: MedicationTime(hour: 8, minute: 0),
          slot: TimeOfDaySlot.morning,
          status: DoseStatus.taken,
        );

        final eveningDose = DoseInstance(
          id: 'dose_2',
          medicationId: 'med_2',
          medicationName: 'Magnesium',
          dosage: '200mg',
          scheduledDate: now,
          time: MedicationTime(hour: 21, minute: 0),
          slot: TimeOfDaySlot.evening,
          status: DoseStatus.pending,
        );

        final summary = WidgetDoseSummary(
          date: now,
          morningDoses: [morningDose],
          eveningDoses: [eveningDose],
        );

        await WidgetService.instance.updateMedicationWidget(
          summary,
          title: 'Pillen',
        );

        final rawData = await HomeWidget.getWidgetData<String>(
          'pill_widget_data',
        );
        expect(rawData, isNotNull);

        final decoded = json.decode(rawData!);
        expect(decoded['title'], equals('Pillen'));
        expect(decoded['hasMorning'], isTrue);
        expect(decoded['morningTaken'], isTrue);
        expect(decoded['hasEvening'], isTrue);
        expect(decoded['eveningTaken'], isFalse);
        expect(decoded['morningCount'], equals(1));
        expect(decoded['eveningCount'], equals(1));
      },
    );

    test(
      'processPendingPillToggles reconciles background toggles from widget',
      () async {
        final now = DateTime.now();
        final med = Medication(
          id: 'med_bg_test',
          name: 'Blood Pressure',
          startDate: now,
          notificationTimes: [
            MedicationTime(hour: 9, minute: 0), // morning
            MedicationTime(hour: 20, minute: 0), // evening
          ],
        );
        await repo.saveMedication(med);

        // Simulate the Android widget writing a pending toggle while app was backgrounded
        await HomeWidget.saveWidgetData<String>(
          'pill_pending_toggles',
          'morning:true',
        );

        await WidgetService.instance.processPendingPillToggles(repo);

        final summary = await repo.getWidgetSummary(now);
        expect(summary.isMorningTaken, isTrue);
        expect(summary.isEveningTaken, isFalse);

        // Pending toggles should now be cleared
        final remaining = await HomeWidget.getWidgetData<String>(
          'pill_pending_toggles',
        );
        expect(remaining, isEmpty);
      },
    );
  });
}
