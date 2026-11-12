import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/medication.dart';
import 'package:housekeepr/repositories/local_medication_repository.dart';
import 'package:housekeepr/ui/features/tools/pages/medication_reminders_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalMedicationRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = LocalMedicationRepository();
  });

  Widget buildTestableWidget() {
    return MaterialApp(home: MedicationRemindersPage(repository: repository));
  }

  group('MedicationRemindersPage Widget Tests', () {
    testWidgets(
      'renders app bar, tabs, and empty state when no medications exist',
      (tester) async {
        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        expect(find.text('Medication Reminders'), findsOneWidget);
        expect(find.text("Today's Schedule"), findsOneWidget);
        expect(find.text('Medications'), findsOneWidget);
        expect(find.text('No doses scheduled for today'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
      },
    );

    testWidgets(
      'renders Daytime and Evening slot cards when medications exist',
      (tester) async {
        final now = DateTime.now();
        final med = Medication(
          id: 'med_ui_test',
          name: 'Multivitamin',
          dosage: '1 gummy',
          startDate: now,
          notificationTimes: [
            MedicationTime(hour: 8, minute: 30),
            MedicationTime(hour: 21, minute: 0),
          ],
        );
        await repository.saveMedication(med);

        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        expect(find.text('Daytime'), findsOneWidget);
        expect(find.text('Evening'), findsOneWidget);
        expect(find.text('Multivitamin'), findsNWidgets(2));

        // Toggle Daytime slot switch
        final switches = find.byType(Switch);
        expect(switches, findsAtLeastNWidgets(2));
        await tester.tap(switches.first);
        await tester.pumpAndSettle();

        // Check that daytime dose is marked taken
        final summary = await repository.getWidgetSummary(now);
        expect(summary.isMorningTaken, isTrue);
        expect(summary.isEveningTaken, isFalse);
      },
    );

    testWidgets('switches to Medications tab and lists active medications', (
      tester,
    ) async {
      final now = DateTime.now();
      final med = Medication(
        id: 'med_list_test',
        name: 'Omega 3',
        dosage: '1000mg',
        startDate: now,
        notificationTimes: [MedicationTime(hour: 9, minute: 0)],
      );
      await repository.saveMedication(med);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap "Medications" tab
      await tester.tap(find.text('Medications'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ACTIVE MEDICATIONS'), findsOneWidget);
      expect(find.text('Omega 3'), findsOneWidget);
      expect(find.text('1000mg'), findsOneWidget);
    });

    testWidgets(
      'opens widget & notification bottom sheet and triggers test notification',
      (tester) async {
        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        // Tap the widget / notification options action in AppBar
        final widgetInfoButton = find.byIcon(Icons.widgets_outlined);
        expect(widgetInfoButton, findsOneWidget);
        await tester.tap(widgetInfoButton);
        await tester.pumpAndSettle();

        // Bottom sheet appears with preview and Test Notification button
        expect(find.text('Widget & Notifications'), findsOneWidget);
        expect(find.text('Test Notification'), findsOneWidget);

        // Tap Test Notification
        await tester.tap(find.text('Test Notification'));
        await tester.pumpAndSettle();

        // Bottom sheet is closed and confirmation snackbar is displayed
        expect(find.text('Widget & Notifications'), findsNothing);
        expect(find.textContaining('Test notification sent'), findsOneWidget);
      },
    );
  });
}
