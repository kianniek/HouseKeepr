import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/ui/common/widgets/simple_cropper.dart';
import 'package:image/image.dart' as img;

import 'helpers/food_tracker_e2e_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E1 ToolsLibraryPage Platform & Marquee Harness Smoke Tests', () {
    testWidgets(
      'ToolsLibraryPage renders across Android and non-Android platforms, filters Health, and flushes Marquee timers on grid teardown',
      (tester) async {
        final shortcuts = installShortcutsChannelMock(canPin: true);

        await runWithTargetPlatform(TargetPlatform.android, () async {
          await pumpToolsLibraryPage(tester);
          expect(find.text('Tools Library'), findsOneWidget);
          expect(find.text('HealthKeepr'), findsOneWidget);
          expect(shortcuts.calls.map((c) => c.method), contains('canPinShortcuts'));

          await tester.tap(find.text('Health'));
          await tester.pump();
          expect(find.text('HealthKeepr'), findsOneWidget);
          expect(find.text('Coffee Picker'), findsNothing);

          await tester.tap(find.byIcon(Icons.grid_view));
          await tester.pump();
          expect(find.byType(GridView), findsOneWidget);

          await disposeToolsLibraryPage(tester);
        });

        await runWithTargetPlatform(TargetPlatform.windows, () async {
          final windowsShortcuts = installShortcutsChannelMock(canPin: true);
          await pumpToolsLibraryPage(tester);
          expect(find.text('HealthKeepr'), findsOneWidget);
          expect(windowsShortcuts.calls, isEmpty);
          await disposeToolsLibraryPage(tester);
        });
      },
    );

    testWidgets(
      'ToolsLibraryPage navigates to HealthKeeprHubScreen cleanly with path_provider mock',
      (tester) async {
        installPathProviderMock();
        installShortcutsChannelMock(canPin: false);

        await runWithTargetPlatform(TargetPlatform.android, () async {
          await pumpToolsLibraryPage(tester);
          await tester.tap(find.text('HealthKeepr'));
          await tester.pumpAndSettle();

          expect(find.text('Private & On-Device'), findsOneWidget);
          expect(find.text('Modules'), findsOneWidget);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
      },
    );
  });

  group('E1 SimpleCropper PNG Export Smoke Tests', () {
    testWidgets(
      'SimpleCropper loads temp plate PNG, applies rotation, and returns decodable PNG bytes',
      (tester) async {
        final plateFile = createTempPlatePng(width: 128, height: 128);

        final croppedBytes = await pumpSimpleCropperAndConfirm(
          tester,
          imagePath: plateFile.path,
          rotateRightTaps: 2,
          rotateLeftTaps: 1,
        );

        expect(croppedBytes, isNotNull);
        expect(croppedBytes!.length, greaterThan(8));
        expect(
          croppedBytes.sublist(0, 4),
          equals(<int>[0x89, 0x50, 0x4E, 0x47]),
        );

        final decoded = img.decodePng(croppedBytes);
        expect(decoded, isNotNull);
        expect(decoded!.width, greaterThan(0));
        expect(decoded.height, greaterThan(0));
      },
    );

    testWidgets(
      'pumpSimpleCropperAndCancel pops null when BackButton is tapped',
      (tester) async {
        final plateFile = createTempPlatePng(width: 96, height: 96);

        final result = await pumpSimpleCropperAndCancel(
          tester,
          imagePath: plateFile.path,
        );

        expect(result, isNull);
      },
    );

    testWidgets(
      'createTempPlatePng addTearDown completes without deadlock when SimpleCropper is not manually unmounted',
      (tester) async {
        final plateFile = createTempPlatePng(width: 64, height: 64);

        await tester.pumpWidget(
          MaterialApp(home: SimpleCropper(imagePath: plateFile.path)),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();

        expect(find.byType(SimpleCropper), findsOneWidget);
        // Intentionally exit without manual SizedBox.shrink() unmount to verify
        // addTearDown cleans up synchronously without FakeAsync deadlock.
      },
    );
  });

  group('E1 Root FakeHealthConnectChannel Smoke Tests', () {
    test('FakeHealthConnectChannel verifies writeNutrition contract and fallback modes', () async {
      final hc = FakeHealthConnectChannel()
        ..mode = FakeHealthConnectMode.available
        ..install();

      final status = await FakeHealthConnectChannel.channel
          .invokeMethod<String>('getSdkStatus');
      expect(status, 'available');

      final recordId = await FakeHealthConnectChannel.channel
          .invokeMethod<String>('writeNutrition', <String, dynamic>{
        'id': 'root-meal-1',
        'name': 'Oatmeal',
        'mealType': 'breakfast',
        'timeIso': '2026-11-22T07:30:00.000Z',
        'kcal': 163.2,
        'proteinGrams': 5.76,
        'carbsGrams': 28.8,
        'fatGrams': 3.36,
      });
      expect(recordId, 'hc_nutrition_root-meal-1');
      expect(hc.writtenNutritionPayloads, hasLength(1));

      hc
        ..mode = FakeHealthConnectMode.unavailable
        ..install();
      expect(
        await FakeHealthConnectChannel.channel
            .invokeMethod<String>('getSdkStatus'),
        'unavailable',
      );
      await expectLater(
        FakeHealthConnectChannel.channel.invokeMethod<String>(
          'writeNutrition',
          <String, dynamic>{
            'id': 'root-meal-2',
            'name': 'Apple',
            'mealType': 'snack',
            'timeIso': '2026-11-22T10:00:00.000Z',
            'kcal': 95.0,
            'proteinGrams': 0.5,
            'carbsGrams': 25.0,
            'fatGrams': 0.3,
          },
        ),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'HC_UNAVAILABLE')),
      );
    });

    test(
      'FakeHealthConnectChannel rejects null/int/whitespace args, empty hasPermissions, ungranted write_nutrition, and simulates openSettingsException',
      () async {
        final hc = FakeHealthConnectChannel()
          ..mode = FakeHealthConnectMode.available
          ..install();

        await expectLater(
          FakeHealthConnectChannel.channel.invokeMethod<String>('writeNutrition'),
          throwsA(
            isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGS'),
          ),
        );

        await expectLater(
          FakeHealthConnectChannel.channel.invokeMethod<String>(
            'writeNutrition',
            <String, dynamic>{
              'id': 'root-int',
              'name': 'Apple',
              'mealType': 'snack',
              'timeIso': '2026-11-22T10:00:00.000Z',
              'kcal': 95,
              'proteinGrams': 0.5,
              'carbsGrams': 25.0,
              'fatGrams': 0.3,
            },
          ),
          throwsA(
            isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGS'),
          ),
        );

        await expectLater(
          FakeHealthConnectChannel.channel.invokeMethod<String>(
            'writeNutrition',
            <String, dynamic>{
              'id': 'root-ws',
              'name': '   ',
              'mealType': 'snack',
              'timeIso': '2026-11-22T10:00:00.000Z',
              'kcal': 95.0,
              'proteinGrams': 0.5,
              'carbsGrams': 25.0,
              'fatGrams': 0.3,
            },
          ),
          throwsA(
            isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGS'),
          ),
        );

        expect(
          await FakeHealthConnectChannel.channel.invokeMethod<bool>(
            'hasPermissions',
            <String, dynamic>{'permissions': <String>[]},
          ),
          isFalse,
        );

        hc.grantedPermissions.clear();
        expect(
          await FakeHealthConnectChannel.channel.invokeMethod<bool>(
            'hasPermissions',
            <String, dynamic>{
              'permissions': <String>['write_nutrition'],
            },
          ),
          isFalse,
        );
        await expectLater(
          FakeHealthConnectChannel.channel.invokeMethod<String>(
            'writeNutrition',
            <String, dynamic>{
              'id': 'root-ungranted',
              'name': 'Apple',
              'mealType': 'snack',
              'timeIso': '2026-11-22T10:00:00.000Z',
              'kcal': 95.0,
              'proteinGrams': 0.5,
              'carbsGrams': 25.0,
              'fatGrams': 0.3,
            },
          ),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'SECURITY_EXCEPTION',
            ),
          ),
        );

        hc.openSettingsException = PlatformException(
          code: 'HC_SETTINGS_ERROR',
          message: 'Settings unavailable.',
        );
        await expectLater(
          FakeHealthConnectChannel.channel.invokeMethod<bool>(
            'openHealthConnectSettings',
          ),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'HC_SETTINGS_ERROR',
            ),
          ),
        );
      },
    );
  });
}
