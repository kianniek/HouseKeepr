import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';

import 'food_tracker_e2e_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E1 Storage & Fixture Harness Smoke Tests', () {
    late TempHealthStoreHarness tempHarness;

    setUp(() {
      tempHarness = TempHealthStoreHarness();
    });

    tearDown(() async {
      await tempHarness.dispose();
    });

    test(
      'TempHealthStoreHarness persists food_tracker logs and settings across reopen',
      () async {
        final store1 = await tempHarness.open();
        final lunchRecord = FoodTrackerRecordFixtures.mealLogRecord(
          id: 'meal-lunch-1',
          foodName: 'Margherita Pizza',
          mealType: 'lunch',
          kcal: 399.0,
          loggedAt: FoodTrackerRecordFixtures.localBoundaryUtcIso(
            year: 2026,
            month: 11,
            day: 22,
            hour: 12,
            minute: 30,
          ),
        );
        await store1.upsertRecord(
          FoodTrackerRecordFixtures.moduleId,
          FoodTrackerRecordFixtures.mealLogsCollection,
          lunchRecord,
        );
        await store1.upsertRecord(
          FoodTrackerRecordFixtures.moduleId,
          FoodTrackerRecordFixtures.settingsCollection,
          FoodTrackerRecordFixtures.dailyGoalSetting(dailyKcalGoal: 2250.0),
        );
        await store1.upsertRecord('open_gym', 'workouts', <String, dynamic>{
          'id': 'workout-1',
          'name': 'Squats',
        });

        final store2 = await tempHarness.reopen();
        final reloadedMeals = await store2.readCollection(
          FoodTrackerRecordFixtures.moduleId,
          FoodTrackerRecordFixtures.mealLogsCollection,
        );
        expect(reloadedMeals, hasLength(1));
        FoodTrackerRecordFixtures.expectValidMealLogSchema(
          reloadedMeals.single,
        );
        expect(reloadedMeals.single['foodName'], 'Margherita Pizza');
        expect(reloadedMeals.single['kcal'], 399.0);

        final reloadedGoal = await store2.readRecord(
          FoodTrackerRecordFixtures.moduleId,
          FoodTrackerRecordFixtures.settingsCollection,
          FoodTrackerRecordFixtures.dailyGoalRecordId,
        );
        expect(reloadedGoal?['dailyKcalGoal'], 2250.0);

        await store2.clearModuleData(FoodTrackerRecordFixtures.moduleId);
        expect(
          await store2.readCollection(
            FoodTrackerRecordFixtures.moduleId,
            FoodTrackerRecordFixtures.mealLogsCollection,
          ),
          isEmpty,
        );
        expect(
          await store2.readRecord('open_gym', 'workouts', 'workout-1'),
          isNotNull,
        );
      },
    );

    test(
      'InMemoryHealthDataStore performs defensive copies and populates metadata',
      () async {
        final memoryStore = InMemoryHealthDataStore();
        final input = FoodTrackerRecordFixtures.mealLogRecord(
          foodName: 'Apple',
          mealType: 'snack',
          servingGrams: 182.0,
          kcal: 94.64,
        );

        await memoryStore.upsertRecord(
          FoodTrackerRecordFixtures.moduleId,
          FoodTrackerRecordFixtures.mealLogsCollection,
          input,
        );

        expect(
          memoryStore.recordCount(
            FoodTrackerRecordFixtures.moduleId,
            FoodTrackerRecordFixtures.mealLogsCollection,
          ),
          1,
        );

        final stored = memoryStore
            .dumpCollection(
              FoodTrackerRecordFixtures.moduleId,
              FoodTrackerRecordFixtures.mealLogsCollection,
            )
            .single;
        FoodTrackerRecordFixtures.expectValidMealLogSchema(stored);

        // Mutating returned map must not affect stored record.
        stored['foodName'] = 'Mutated';
        final reread = await memoryStore.readRecord(
          FoodTrackerRecordFixtures.moduleId,
          FoodTrackerRecordFixtures.mealLogsCollection,
          stored['id'] as String,
        );
        expect(reread?['foodName'], 'Apple');
      },
    );

    test(
      'NutritionDatasetFixtures validates schema and rejects malformed data',
      () {
        final parsed = NutritionDatasetFixtures.validateCatalogJson(
          NutritionDatasetFixtures.sampleCatalogJson(),
        );
        expect(parsed, hasLength(5));
        expect(parsed.first['id'], 'pizza');
        expect(parsed[3]['proteinPer100g'], 0.0);
        expect(parsed[4]['protein'], 2.4);

        expect(
          () => NutritionDatasetFixtures.validateCatalogJson(
            NutritionDatasetFixtures.malformedCatalogJson(),
          ),
          throwsFormatException,
        );
      },
    );

    test(
      'ImageByteFixtures produces genuine PNG bytes decodable by dart:ui',
      () async {
        final bytes = ImageByteFixtures.validPngBytes(width: 16, height: 12);
        expect(bytes.sublist(0, 8), equals(ImageByteFixtures.pngSignature));

        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 16);
        expect(frame.image.height, 12);
        frame.image.dispose();
        codec.dispose();

        expect(ImageByteFixtures.emptyBytes(), isEmpty);
        expect(ImageByteFixtures.truncatedHeaderBytes(), hasLength(4));
        expect(
          ImageByteFixtures.corruptPngBytes().length,
          greaterThan(ImageByteFixtures.pngSignature.length),
        );
      },
    );

    test(
      'TempHealthStoreHarness.open closes prior store and dispose cleans directory',
      () async {
        final localHarness = TempHealthStoreHarness(prefix: 'hk_double_open_');
        final first = await localHarness.open();
        await first.upsertRecord(
          FoodTrackerRecordFixtures.moduleId,
          FoodTrackerRecordFixtures.mealLogsCollection,
          FoodTrackerRecordFixtures.mealLogRecord(id: 'double-open-1'),
        );

        final second = await localHarness.open();
        final reloaded = await second.readRecord(
          FoodTrackerRecordFixtures.moduleId,
          FoodTrackerRecordFixtures.mealLogsCollection,
          'double-open-1',
        );
        expect(reloaded?['id'], 'double-open-1');

        await localHarness.dispose();
        expect(localHarness.dir.existsSync(), isFalse);
      },
    );
  });

  group('E1 Health Connect MethodChannel Driver Smoke Tests', () {
    late MockHealthConnectChannelDriver hcDriver;

    setUp(() {
      hcDriver = MockHealthConnectChannelDriver();
    });

    tearDown(() {
      hcDriver.uninstall();
    });

    test(
      'available mode handles permissions and validates writeNutrition payload',
      () async {
        hcDriver
          ..mode = MockHcMode.available
          ..install();

        final status = await MockHealthConnectChannelDriver.channel
            .invokeMethod<String>('getSdkStatus');
        expect(status, 'available');

        final hasPerm = await MockHealthConnectChannelDriver.channel
            .invokeMethod<bool>('hasPermissions', <String, dynamic>{
              'permissions': <String>['write_nutrition'],
            });
        expect(hasPerm, isTrue);

        final req = await MockHealthConnectChannelDriver.channel
            .invokeMethod<Map<dynamic, dynamic>>(
              'requestPermissions',
              <String, dynamic>{
                'permissions': <String>['write_nutrition'],
              },
            );
        expect(req?['granted'], isTrue);

        final recordId = await MockHealthConnectChannelDriver.channel
            .invokeMethod<String>('writeNutrition', <String, dynamic>{
              'id': 'meal-1',
              'name': 'Chicken Salad',
              'mealType': 'lunch',
              'timeIso': '2026-11-22T12:00:00.000Z',
              'kcal': 355.0,
              'proteinGrams': 38.75,
              'carbsGrams': 13.0,
              'fatGrams': 16.0,
            });
        expect(recordId, 'hc_nutrition_meal-1');
        expect(hcDriver.writtenNutritionCalls, hasLength(1));
      },
    );

    test(
      'unavailable, providerUpdateRequired, permissionsDeclined, writeFailure, unsupportedSdk, and missingPlugin behave cleanly',
      () async {
        hcDriver
          ..mode = MockHcMode.providerUpdateRequired
          ..install();
        expect(
          await MockHealthConnectChannelDriver.channel.invokeMethod<String>(
            'getSdkStatus',
          ),
          'providerUpdateRequired',
        );
        await expectLater(
          MockHealthConnectChannelDriver.channel
              .invokeMethod<String>('writeNutrition', <String, dynamic>{
                'id': 'm2',
                'name': 'Apple',
                'mealType': 'snack',
                'timeIso': '2026-11-22T15:00:00.000Z',
                'kcal': 95.0,
                'proteinGrams': 0.5,
                'carbsGrams': 25.0,
                'fatGrams': 0.3,
              }),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'HC_UNAVAILABLE',
            ),
          ),
        );

        hcDriver
          ..mode = MockHcMode.permissionsDeclined
          ..install();
        expect(
          await MockHealthConnectChannelDriver.channel.invokeMethod<bool>(
            'hasPermissions',
            <String, dynamic>{
              'permissions': <String>['write_nutrition'],
            },
          ),
          isFalse,
        );
        final declined = await MockHealthConnectChannelDriver.channel
            .invokeMethod<Map<dynamic, dynamic>>(
              'requestPermissions',
              <String, dynamic>{
                'permissions': <String>['write_nutrition'],
              },
            );
        expect(declined?['granted'], isFalse);

        hcDriver
          ..mode = MockHcMode.writeFailure
          ..install();
        await expectLater(
          MockHealthConnectChannelDriver.channel
              .invokeMethod<String>('writeNutrition', <String, dynamic>{
                'id': 'm3',
                'name': 'Pizza',
                'mealType': 'dinner',
                'timeIso': '2026-11-22T19:00:00.000Z',
                'kcal': 400.0,
                'proteinGrams': 16.0,
                'carbsGrams': 48.0,
                'fatGrams': 14.0,
              }),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'WRITE_NUTRITION_FAILED',
            ),
          ),
        );

        hcDriver
          ..mode = MockHcMode.unsupportedSdk
          ..install();
        expect(
          await MockHealthConnectChannelDriver.channel.invokeMethod<String>(
            'getSdkStatus',
          ),
          'unavailable',
        );
        await expectLater(
          MockHealthConnectChannelDriver.channel.invokeMethod<String>(
            'writeNutrition',
            const <String, dynamic>{},
          ),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'UNSUPPORTED_SDK',
            ),
          ),
        );

        hcDriver
          ..mode = MockHcMode.missingPlugin
          ..install();
        await expectLater(
          MockHealthConnectChannelDriver.channel.invokeMethod<String>(
            'getSdkStatus',
          ),
          throwsA(isA<MissingPluginException>()),
        );
      },
    );

    test(
      'enforces null args, double fields, trimmed name, non-empty hasPermissions, SECURITY_EXCEPTION, and openSettingsException',
      () async {
        hcDriver
          ..mode = MockHcMode.available
          ..install();

        await expectLater(
          MockHealthConnectChannelDriver.channel.invokeMethod<String>(
            'writeNutrition',
          ),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'INVALID_ARGS',
            ),
          ),
        );

        await expectLater(
          MockHealthConnectChannelDriver.channel
              .invokeMethod<String>('writeNutrition', <String, dynamic>{
                'id': 'm-int',
                'name': 'Apple',
                'mealType': 'snack',
                'timeIso': '2026-11-22T15:00:00.000Z',
                'kcal': 95,
                'proteinGrams': 0.5,
                'carbsGrams': 25.0,
                'fatGrams': 0.3,
              }),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'INVALID_ARGS',
            ),
          ),
        );

        await expectLater(
          MockHealthConnectChannelDriver.channel
              .invokeMethod<String>('writeNutrition', <String, dynamic>{
                'id': 'm-ws',
                'name': '   ',
                'mealType': 'snack',
                'timeIso': '2026-11-22T15:00:00.000Z',
                'kcal': 95.0,
                'proteinGrams': 0.5,
                'carbsGrams': 25.0,
                'fatGrams': 0.3,
              }),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'INVALID_ARGS',
            ),
          ),
        );

        expect(
          await MockHealthConnectChannelDriver.channel.invokeMethod<bool>(
            'hasPermissions',
            <String, dynamic>{'permissions': <String>[]},
          ),
          isFalse,
        );

        hcDriver.grantedPermissions.clear();
        expect(
          await MockHealthConnectChannelDriver.channel.invokeMethod<bool>(
            'hasPermissions',
            <String, dynamic>{
              'permissions': <String>['write_nutrition'],
            },
          ),
          isFalse,
        );
        await expectLater(
          MockHealthConnectChannelDriver.channel
              .invokeMethod<String>('writeNutrition', <String, dynamic>{
                'id': 'm-ungranted',
                'name': 'Apple',
                'mealType': 'snack',
                'timeIso': '2026-11-22T15:00:00.000Z',
                'kcal': 95.0,
                'proteinGrams': 0.5,
                'carbsGrams': 25.0,
                'fatGrams': 0.3,
              }),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'SECURITY_EXCEPTION',
            ),
          ),
        );

        hcDriver.openSettingsException = PlatformException(
          code: 'HC_SETTINGS_UNAVAILABLE',
          message: 'Simulated settings failure.',
        );
        await expectLater(
          MockHealthConnectChannelDriver.channel.invokeMethod<bool>(
            'openHealthConnectSettings',
          ),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'HC_SETTINGS_UNAVAILABLE',
            ),
          ),
        );
      },
    );
  });

  group('E1 HubScreenTestHarness Smoke Tests', () {
    testWidgets(
      'HubScreenTestHarness renders HealthKeeprHubScreen, launches module, and clears module data',
      (tester) async {
        final store = InMemoryHealthDataStore();
        await store.upsertRecord(
          FoodTrackerRecordFixtures.moduleId,
          FoodTrackerRecordFixtures.mealLogsCollection,
          FoodTrackerRecordFixtures.mealLogRecord(),
        );
        var launched = false;

        await HubScreenTestHarness.runWithHub(
          tester,
          store: store,
          platform: TargetPlatform.android,
          modules: <HealthMiniApp>[
            HealthMiniApp(
              id: FoodTrackerRecordFixtures.moduleId,
              title: 'Food Snap & Tracker',
              subtitle: 'calorie & macro log',
              icon: Icons.restaurant_rounded,
              isInstalled: true,
              onLaunch: (context, injectedStore) async {
                launched = identical(injectedStore, store);
              },
            ),
          ],
          action: () async {
            expect(find.text('HealthKeepr'), findsOneWidget);
            expect(find.text('Food Snap & Tracker'), findsOneWidget);

            await tester.tap(find.text('Food Snap & Tracker'));
            await tester.pump();
            expect(launched, isTrue);

            await tester.longPress(find.text('Food Snap & Tracker'));
            await tester.pumpAndSettle();
            expect(
              find.text('Clear Food Snap & Tracker data?'),
              findsOneWidget,
            );

            await tester.tap(find.text('Clear data'));
            await tester.pumpAndSettle();

            expect(
              store.recordCount(
                FoodTrackerRecordFixtures.moduleId,
                FoodTrackerRecordFixtures.mealLogsCollection,
              ),
              0,
            );
            expect(store.isClosed, isFalse);
          },
        );
      },
    );
  });
}
