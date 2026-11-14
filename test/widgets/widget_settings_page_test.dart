import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/core/widget_settings.dart';
import 'package:housekeepr/ui/features/profile/pages/widget_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WidgetSettingsRepository', () {
    test('returns defaults and persists updated settings', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WidgetSettingsRepository(prefs);

      final initial = repo.load();
      expect(initial.pillHideUnusedToggles, isFalse);
      expect(initial.pillWidgetTitle, 'Pillen');
      expect(initial.pillShowDoseCount, isFalse);
      expect(initial.shoppingHideChecked, isFalse);
      expect(initial.shoppingShowItemCount, isTrue);
      expect(initial.coffeeIncludeCustomRecipes, isTrue);
      expect(initial.coffeeShowSubtitle, isTrue);

      final updated = initial.copyWith(
        pillHideUnusedToggles: true,
        pillWidgetTitle: 'Meds',
        pillShowDoseCount: true,
        shoppingHideChecked: true,
        shoppingShowItemCount: false,
        coffeeIncludeCustomRecipes: false,
        coffeeShowSubtitle: false,
      );
      await repo.save(updated);

      final reloaded = repo.load();
      expect(reloaded.pillHideUnusedToggles, isTrue);
      expect(reloaded.pillWidgetTitle, 'Meds');
      expect(reloaded.pillShowDoseCount, isTrue);
      expect(reloaded.shoppingHideChecked, isTrue);
      expect(reloaded.shoppingShowItemCount, isFalse);
      expect(reloaded.coffeeIncludeCustomRecipes, isFalse);
      expect(reloaded.coffeeShowSubtitle, isFalse);
    });
  });

  group('Separate widget settings screens', () {
    testWidgets('hub navigates to each dedicated widget settings screen', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: WidgetSettingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Pill Reminder Widget'), findsOneWidget);
      expect(find.text('Shopping List Widget'), findsOneWidget);
      expect(find.text('Coffee Picker Widget'), findsOneWidget);
      expect(find.text('Hide unused toggles'), findsNothing);

      await tester.tap(find.text('Pill Reminder Widget'));
      await tester.pumpAndSettle();

      expect(find.text('Hide unused toggles'), findsOneWidget);
      expect(find.text('Hide checked items'), findsNothing);
    });

    testWidgets('PillWidgetSettingsPage persists hide unused toggles', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: PillWidgetSettingsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hide unused toggles'), findsOneWidget);
      expect(find.text('Hide checked items'), findsNothing);
      expect(find.text('Include custom recipes'), findsNothing);

      await tester.tap(find.text('Hide unused toggles'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        WidgetSettingsRepository(prefs).load().pillHideUnusedToggles,
        isTrue,
      );
    });

    testWidgets('ShoppingWidgetSettingsPage persists hide checked items', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ShoppingWidgetSettingsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hide checked items'), findsOneWidget);
      expect(find.text('Hide unused toggles'), findsNothing);

      await tester.tap(find.text('Hide checked items'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        WidgetSettingsRepository(prefs).load().shoppingHideChecked,
        isTrue,
      );
    });

    testWidgets('CoffeeWidgetSettingsPage persists show recipe subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: CoffeeWidgetSettingsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show recipe subtitle'), findsOneWidget);
      expect(find.text('Hide unused toggles'), findsNothing);

      await tester.tap(find.text('Show recipe subtitle'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        WidgetSettingsRepository(prefs).load().coffeeShowSubtitle,
        isFalse,
      );
    });

    testWidgets(
      'PillWidgetSettingsPage with appWidgetId saves and invokes finishWidgetConfiguration',
      (tester) async {
        const homeWidgetChannel = MethodChannel('home_widget');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(homeWidgetChannel, (call) async => true);
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(homeWidgetChannel, null),
        );

        const channel = MethodChannel('housekeepr/widget_actions');
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return true;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );

        await tester.pumpWidget(
          const MaterialApp(home: PillWidgetSettingsPage(appWidgetId: 42)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Save & Return Home'), findsOneWidget);

        await tester.tap(find.text('Hide unused toggles'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save & Return Home'));
        await tester.pumpAndSettle();

        expect(calls, hasLength(1));
        expect(calls.single.method, 'finishWidgetConfiguration');
        expect(calls.single.arguments, {'appWidgetId': 42});

        final prefs = await SharedPreferences.getInstance();
        expect(
          WidgetSettingsRepository(prefs).load().pillHideUnusedToggles,
          isTrue,
        );
      },
    );
  });
}
