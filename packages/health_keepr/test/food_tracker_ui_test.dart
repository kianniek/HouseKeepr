import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';
import 'package:health_keepr/src/food_tracker/ai/on_device_llm_storage_stub.dart';

class _InMemoryHealthDataStore implements HealthDataStore {
  final Map<String, Map<String, Map<String, Map<String, dynamic>>>> _data =
      <String, Map<String, Map<String, Map<String, dynamic>>>>{};

  @override
  Future<void> clearModuleData(String moduleId) async {
    _data.remove(moduleId);
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    _data[moduleId]?[collection]?.remove(id);
  }

  @override
  Future<List<Map<String, dynamic>>> readCollection(
    String moduleId,
    String collection,
  ) async {
    final col = _data[moduleId]?[collection];
    if (col == null) return const <Map<String, dynamic>>[];
    return col.values
        .map((r) => Map<String, dynamic>.from(r))
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>?> readRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    final rec = _data[moduleId]?[collection]?[id];
    return rec == null ? null : Map<String, dynamic>.from(rec);
  }

  @override
  Future<void> upsertRecord(
    String moduleId,
    String collection,
    Map<String, dynamic> record,
  ) async {
    final copy = Map<String, dynamic>.from(record);
    final id = (copy['id'] as String?) ?? HealthRecordMetadata.generateId();
    copy['id'] = id;
    _data
        .putIfAbsent(
          moduleId,
          () => <String, Map<String, Map<String, dynamic>>>{},
        )
        .putIfAbsent(collection, () => <String, Map<String, dynamic>>{})[id] =
        copy;
  }
}

class _FakeFoodClassifier implements FoodClassifier {
  _FakeFoodClassifier(this.predictions);

  final List<FoodPrediction> predictions;
  Uint8List? lastBytes;
  int classifyCalls = 0;

  @override
  Future<void> warmUp() async {}

  @override
  Future<List<FoodPrediction>> classifyImageBytes(
    Uint8List imageBytes, {
    int topK = 5,
  }) async {
    classifyCalls++;
    lastBytes = imageBytes;
    return predictions.take(topK).toList();
  }

  @override
  Future<void> dispose() async {}
}

class _FakeHealthConnectGateway implements NutritionHealthConnectGateway {
  _FakeHealthConnectGateway({
    this.status = NutritionHealthConnectStatus.unavailable,
    this.hasPermission = false,
    this.grantOnRequest = false,
  });

  NutritionHealthConnectStatus status;
  bool hasPermission;
  bool grantOnRequest;
  final List<MealLog> writtenLogs = <MealLog>[];
  bool openedSettings = false;

  @override
  Future<NutritionHealthConnectStatus> getSdkStatus() async => status;

  @override
  Future<bool> hasWriteNutritionPermission() async => hasPermission;

  @override
  Future<bool> requestWriteNutritionPermission() async {
    if (grantOnRequest) {
      hasPermission = true;
    }
    return hasPermission;
  }

  @override
  Future<void> openHealthConnectSettings() async {
    openedSettings = true;
  }

  @override
  Future<String?> writeNutritionRecord(MealLog log) async {
    writtenLogs.add(log);
    return 'hc_${log.id}';
  }
}

class _FakeLlmRunner implements OnDeviceLlmRunner {
  _FakeLlmRunner({required this.ready, this.responseJson});

  final bool ready;
  final String? responseJson;

  @override
  Future<bool> isModelReady() async => ready;

  @override
  Future<String?> generateNutritionJson(String prompt) async => responseJson;
}

class _FakeLlmStorageBackend implements OnDeviceLlmStorageBackend {
  bool present = true;
  bool deleted = false;
  int bytes = 20 * 1024 * 1024;

  @override
  Future<bool> exists(String fileName) async => present;

  @override
  Future<int> fileSizeBytes(String fileName) async => bytes;

  @override
  Future<bool> isBundledDeleted(String fileName) async => deleted;

  @override
  Future<void> setBundledDeleted(String fileName, bool isDeleted) async {
    deleted = isDeleted;
  }

  @override
  Future<void> downloadToFile({
    required String url,
    required String fileName,
    required void Function(int receivedBytes, int totalBytes) onProgress,
  }) async {
    onProgress(50, 100);
    onProgress(100, 100);
    present = true;
    deleted = false;
    bytes = 20 * 1024 * 1024;
  }

  @override
  Future<void> deleteFile(String fileName) async {
    present = false;
    bytes = 0;
  }
}

// 1x1 transparent PNG
final Uint8List _valid1x1Png = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

NutritionCatalog _testCatalog() {
  return NutritionCatalog.fromFoods(const <NutritionFood>[
    NutritionFood(
      id: 'pizza',
      name: 'Pizza',
      category: 'main',
      kcalPer100g: 266,
      proteinPer100g: 11,
      carbsPer100g: 33,
      fatPer100g: 10,
      defaultServingGrams: 150,
      servingLabel: '1 slice (150g)',
    ),
    NutritionFood(
      id: 'apple',
      name: 'Apple',
      category: 'fruit',
      kcalPer100g: 52,
      proteinPer100g: 0.3,
      carbsPer100g: 14,
      fatPer100g: 0.2,
      defaultServingGrams: 180,
      servingLabel: '1 medium (180g)',
    ),
    NutritionFood(
      id: 'banana',
      name: 'Banana',
      category: 'fruit',
      kcalPer100g: 89,
      proteinPer100g: 1.1,
      carbsPer100g: 23,
      fatPer100g: 0.3,
      defaultServingGrams: 120,
      servingLabel: '1 medium (120g)',
    ),
    NutritionFood(
      id: 'muesli',
      name: 'Muesli',
      category: 'grain',
      kcalPer100g: 365,
      proteinPer100g: 10,
      carbsPer100g: 64,
      fatPer100g: 6.5,
      defaultServingGrams: 45,
      servingLabel: '1 bowl (45g)',
    ),
    NutritionFood(
      id: 'kwark',
      name: 'Kwark',
      category: 'dairy',
      kcalPer100g: 57,
      proteinPer100g: 9.5,
      carbsPer100g: 3.8,
      fatPer100g: 0.2,
      defaultServingGrams: 150,
      servingLabel: '1 bowl (150g)',
    ),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FoodTrackerScreen widget tests', () {
    testWidgets(
      'renders daily kcal progress bar, macros, and all 4 meal groups',
      (tester) async {
        final store = _InMemoryHealthDataStore();
        final repo = FoodTrackerRepository(store);
        await repo.saveDailyKcalGoal(2200);
        await repo.saveMealLog(
          MealLog.create(
            foodName: 'Oatmeal',
            mealType: MealType.breakfast,
            servingGrams: 200,
            kcal: 300,
            proteinGrams: 10,
            carbsGrams: 50,
            fatGrams: 6,
            loggedAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: FoodTrackerScreen(
              store: store,
              catalog: _testCatalog(),
              healthConnectGateway: _FakeHealthConnectGateway(),
              estimator: CatalogNutritionEstimator(_testCatalog()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('300 / 2200 kcal'), findsOneWidget);
        expect(find.text('1900 kcal remaining'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('Protein'), findsOneWidget);
        expect(find.text('Carbs'), findsOneWidget);
        expect(find.text('Fat'), findsOneWidget);
        expect(find.text('10 g'), findsOneWidget);
        expect(find.text('50 g'), findsOneWidget);
        expect(find.text('6 g'), findsOneWidget);

        expect(find.text('Breakfast'), findsOneWidget);
        expect(find.text('Oatmeal'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('Snack'), 200);
        expect(find.text('Lunch'), findsOneWidget);
        expect(find.text('Dinner'), findsOneWidget);
        expect(find.text('Snack'), findsOneWidget);
      },
    );

    testWidgets('editing daily calorie goal persists and updates summary', (
      tester,
    ) async {
      final store = _InMemoryHealthDataStore();
      await tester.pumpWidget(
        MaterialApp(
          home: FoodTrackerScreen(
            store: store,
            catalog: _testCatalog(),
            healthConnectGateway: _FakeHealthConnectGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 / 2000 kcal'), findsOneWidget);

      await tester.tap(find.text('Edit goal'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '2500');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('0 / 2500 kcal'), findsOneWidget);
      final persistedGoal = await FoodTrackerRepository(
        store,
      ).loadDailyKcalGoal();
      expect(persistedGoal, 2500);
    });

    testWidgets('Manual Add custom meal updates persisted logs and totals', (
      tester,
    ) async {
      final store = _InMemoryHealthDataStore();
      await tester.pumpWidget(
        MaterialApp(
          home: FoodTrackerScreen(
            store: store,
            catalog: _testCatalog(),
            healthConnectGateway: _FakeHealthConnectGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manual Add'));
      await tester.pumpAndSettle();

      expect(find.text('Add Food Manually'), findsOneWidget);

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Food name'),
        'Grilled Chicken Salad',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Calories (kcal)'),
        '420',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Protein (g)'),
        '38',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Carbs (g)'),
        '14',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Fat (g)'),
        '22',
      );

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Lunch'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Lunch'));
      await tester.pumpAndSettle();

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.ensureVisible(find.text('Add Meal'));
      await tester.tap(find.text('Add Meal'));
      await tester.pumpAndSettle();

      expect(find.text('420 / 2000 kcal'), findsOneWidget);
      expect(find.text('Grilled Chicken Salad'), findsOneWidget);

      final logs = await FoodTrackerRepository(store).loadMealLogs();
      expect(logs, hasLength(1));
      expect(logs.first.mealType, MealType.lunch);
      expect(logs.first.kcal, 420);
    });

    testWidgets(
      'Snap Food invokes cropper before classifier, allows editing in confirmation sheet, and saves',
      (tester) async {
        final store = _InMemoryHealthDataStore();
        final callOrder = <String>[];
        final classifier = _FakeFoodClassifier(const <FoodPrediction>[
          FoodPrediction(label: 'Pizza', rawIndex: 1, confidence: 0.91),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: FoodTrackerScreen(
              store: store,
              catalog: _testCatalog(),
              healthConnectGateway: _FakeHealthConnectGateway(),
              imagePicker: (context, origin) async {
                callOrder.add('picker:${origin.name}');
                return '/tmp/plate.jpg';
              },
              cropper: (context, imagePath) async {
                callOrder.add('cropper:$imagePath');
                return _valid1x1Png;
              },
              classifier: classifier,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Snap Food'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Choose from Gallery'));
        await tester.pumpAndSettle();

        expect(callOrder, <String>[
          'picker:gallery',
          'cropper:/tmp/plate.jpg',
        ]);
        expect(classifier.classifyCalls, 1);
        expect(classifier.lastBytes, _valid1x1Png);
        expect(find.text('Confirm Food Snap'), findsOneWidget);

        // Edit portion grams and select Dinner
        await tester.enterText(
          find.widgetWithText(TextField, 'Serving size (g)'),
          '100',
        );
        await tester.pumpAndSettle();

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Dinner'));
        await tester.tap(find.widgetWithText(ChoiceChip, 'Dinner'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Log Meal'));
        await tester.tap(find.text('Log Meal'));
        await tester.pumpAndSettle();

        final logs = await FoodTrackerRepository(store).loadMealLogs();
        expect(logs, hasLength(1));
        expect(logs.first.mealType, MealType.dinner);
        expect(logs.first.servingGrams, 100);
      },
    );

    testWidgets(
      'Health Connect unavailable disables switch and still saves locally; available + granted syncs',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        // 1) Unavailable keeps switch disabled & local logging working
        final unavailableStore = _InMemoryHealthDataStore();
        await tester.pumpWidget(
          MaterialApp(
            home: FoodTrackerScreen(
              store: unavailableStore,
              catalog: _testCatalog(),
              healthConnectGateway: _FakeHealthConnectGateway(
                status: NutritionHealthConnectStatus.unavailable,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SwitchListTile), findsNothing);
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();

        final disabledSwitch = tester.widget<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(disabledSwitch.onChanged, isNull);
        expect(disabledSwitch.value, isFalse);
        expect(
          find.textContaining('Health Connect is unavailable on this device'),
          findsOneWidget,
        );

        // 2) Declined permission keeps toggle off and shows snackbar
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final declinedGateway = _FakeHealthConnectGateway(
          status: NutritionHealthConnectStatus.available,
          hasPermission: false,
          grantOnRequest: false,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: FoodTrackerScreen(
              store: _InMemoryHealthDataStore(),
              catalog: _testCatalog(),
              healthConnectGateway: declinedGateway,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse,
        );
        expect(
          find.textContaining('permission was declined'),
          findsWidgets,
        );

        // 3) Available + granted syncs logged meals
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final grantedGateway = _FakeHealthConnectGateway(
          status: NutritionHealthConnectStatus.available,
          hasPermission: false,
          grantOnRequest: true,
        );
        final syncStore = _InMemoryHealthDataStore();
        await tester.pumpWidget(
          MaterialApp(
            home: FoodTrackerScreen(
              store: syncStore,
              catalog: _testCatalog(),
              healthConnectGateway: grantedGateway,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Manual Add'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Custom'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Food name'),
          'Banana',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Calories (kcal)'),
          '105',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.ensureVisible(find.text('Add Meal'));
        await tester.tap(find.text('Add Meal'));
        await tester.pumpAndSettle();

        expect(grantedGateway.writtenLogs, hasLength(1));
        expect(grantedGateway.writtenLogs.first.foodName, 'Banana');
        final saved = await FoodTrackerRepository(syncStore).loadMealLogs();
        expect(saved.first.healthConnectId, isNotNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  });

  group('FoodConfirmationSheet widget tests', () {
    testWidgets('allows switching predictions and custom mode edits', (
      tester,
    ) async {
      final catalog = _testCatalog();
      final mapped = NutritionMapper(catalog).mapPredictions(const <FoodPrediction>[
        FoodPrediction(label: 'Apple', rawIndex: 1, confidence: 0.8),
        FoodPrediction(label: 'Banana', rawIndex: 2, confidence: 0.2),
      ]);

      MealLog? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<MealLog>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => FoodConfirmationSheet(
                      mappedPredictions: mapped,
                      catalog: catalog,
                      initialMealType: MealType.snack,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Food name'),
        'Custom Apple Bowl',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Calories (kcal)'),
        '180',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.ensureVisible(find.text('Log Meal'));
      await tester.tap(find.text('Log Meal'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.foodName, 'Custom Apple Bowl');
      expect(result!.kcal, 180);
      expect(result!.mealType, MealType.snack);
    });

    testWidgets('supports portion hints (Small/Medium/Large) and multi-item plate', (
      tester,
    ) async {
      final catalog = _testCatalog();
      final mapped = NutritionMapper(catalog).mapPredictions(const <FoodPrediction>[
        FoodPrediction(label: 'Pizza', rawIndex: 1, confidence: 0.9),
      ]);

      List<MealLog>? plateResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showModalBottomSheet<MealLog>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => FoodConfirmationSheet(
                      mappedPredictions: mapped,
                      catalog: catalog,
                      initialMealType: MealType.dinner,
                      onConfirmPlate: (items) {
                        plateResult = items;
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Default Pizza serving is 150g; Large (1.5x) should set 225g
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Large'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Large'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '225'), findsOneWidget);

      await tester.ensureVisible(find.text('Add to plate'));
      await tester.tap(find.text('Add to plate'));
      await tester.pumpAndSettle();

      expect(find.text('Plate items (1)'), findsOneWidget);
      expect(find.text('Log 2 Items'), findsOneWidget);

      // Select Banana from search results and log both items
      await tester.tap(find.text('Banana').first);
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.ensureVisible(find.text('Log 2 Items'));
      await tester.tap(find.text('Log 2 Items'));
      await tester.pumpAndSettle();

      expect(plateResult, isNotNull);
      expect(plateResult, hasLength(2));
      expect(plateResult![0].servingGrams, 225);
      expect(plateResult![1].foodName, 'Banana');
    });
  });

  group('FoodTrackerScreen edit/delete and custom/favorites', () {
    testWidgets('edits a logged meal and deletes with Undo', (tester) async {
      final store = _InMemoryHealthDataStore();
      final repo = FoodTrackerRepository(store);
      await repo.saveMealLog(
        MealLog.create(
          foodName: 'Oatmeal',
          mealType: MealType.breakfast,
          servingGrams: 100,
          kcal: 150,
          proteinGrams: 5,
          carbsGrams: 27,
          fatGrams: 3,
          loggedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FoodTrackerScreen(
            store: store,
            catalog: _testCatalog(),
            healthConnectGateway: _FakeHealthConnectGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Oatmeal'), findsOneWidget);
      expect(find.text('150 / 2000 kcal'), findsOneWidget);

      // Edit meal
      await tester.tap(find.text('Oatmeal'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Meal'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Calories (kcal)'),
        '250',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('250 / 2000 kcal'), findsOneWidget);

      // Delete meal + Undo
      await tester.tap(find.byTooltip('Delete meal'));
      await tester.pumpAndSettle();
      expect(find.text('0 / 2000 kcal'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('250 / 2000 kcal'), findsOneWidget);
    });

    test('repository persists custom foods, favorites, and recents', () async {
      final store = _InMemoryHealthDataStore();
      final repo = FoodTrackerRepository(store);

      const custom = NutritionFood(
        id: 'custom_protein_shake',
        name: 'Protein Shake',
        category: 'custom',
        kcalPer100g: 120,
        proteinPer100g: 20,
        carbsPer100g: 5,
        fatPer100g: 2,
        defaultServingGrams: 300,
        servingLabel: '1 bottle (300g)',
      );
      await repo.saveCustomFood(custom);
      final loadedFoods = await repo.loadCustomFoods();
      expect(loadedFoods, <NutritionFood>[custom]);

      final toggled = await repo.toggleFavoriteFoodId('pizza');
      expect(toggled, <String>['pizza']);
      expect(await repo.loadFavoriteFoodIds(), <String>['pizza']);

      await repo.saveMealLog(
        MealLog.fromNutritionFood(
          food: custom,
          mealType: MealType.snack,
        ),
      );
      expect(await repo.loadRecentFoodIds(), <String>['custom_protein_shake']);
    });
  });

  group('On-device AI Nutrition Auto-fill & Model Manager', () {
    test('HybridNutritionEstimator uses LLM when ready and falls back to catalog', () async {
      final catalog = _testCatalog();

      final fallbackEstimator = HybridNutritionEstimator(
        catalog: catalog,
        llmRunner: _FakeLlmRunner(ready: false),
      );
      final inferred = await fallbackEstimator.estimate(foodName: 'Pizza');
      expect(inferred, isNotNull);
      expect(inferred!.source, NutritionEstimateSource.localCatalog);
      expect(inferred.servingGrams, 150);
      expect(inferred.kcal, closeTo(399, 0.1));

      final llmEstimator = HybridNutritionEstimator(
        catalog: catalog,
        llmRunner: _FakeLlmRunner(
          ready: true,
          responseJson:
              '{"servingGrams":200,"kcal":520,"proteinGrams":24,"carbsGrams":45,"fatGrams":22}',
        ),
      );
      final llmEstimate = await llmEstimator.estimate(
        foodName: 'Custom Pasta',
        servingGrams: 200,
      );
      expect(llmEstimate, isNotNull);
      expect(llmEstimate!.source, NutritionEstimateSource.onDeviceLlm);
      expect(llmEstimate.kcal, 520);
      expect(llmEstimate.proteinGrams, 24);
    });

    testWidgets(
      'ManualFoodAddSheet Auto-fill populates empty fields and never overwrites user-typed values',
      (tester) async {
        final store = _InMemoryHealthDataStore();
        final deletedManager = OnDeviceLlmModelManager(
          backend: _FakeLlmStorageBackend()..deleted = true,
        );
        await deletedManager.refreshStatus();
        await tester.pumpWidget(
          MaterialApp(
            home: FoodTrackerScreen(
              store: store,
              catalog: _testCatalog(),
              healthConnectGateway: _FakeHealthConnectGateway(),
              estimator: CatalogNutritionEstimator(_testCatalog()),
              llmModelManager: deletedManager,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Manual Add'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Custom'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Food name'),
          'Pizza',
        );
        // Clear Serving (g) to test default serving inference
        await tester.enterText(
          find.widgetWithText(TextField, 'Serving (g)'),
          '',
        );
        // User types a custom protein value; Auto-fill must preserve it
        await tester.enterText(
          find.widgetWithText(TextField, 'Protein (g)'),
          '99',
        );

        await tester.ensureVisible(find.text('Auto-fill'));
        await tester.tap(find.text('Auto-fill'));
        await tester.pumpAndSettle();

        // Serving inferred as 150g, kcal as 399, Protein preserved as 99
        expect(find.widgetWithText(TextField, '150'), findsOneWidget);
        expect(find.widgetWithText(TextField, '399'), findsOneWidget);
        expect(find.widgetWithText(TextField, '99'), findsOneWidget);
        expect(find.text('From "Pizza"'), findsOneWidget);

        // Tapping the source badge opens the detail dialog
        await tester.tap(find.text('From "Pizza"'));
        await tester.pumpAndSettle();
        expect(find.text('Auto-fill Source'), findsOneWidget);
        expect(find.textContaining('Per 100g: 266 kcal'), findsOneWidget);
        expect(find.text('Download AI Model'), findsOneWidget);

        await tester.tap(find.text('Download AI Model'));
        await tester.pumpAndSettle();
        expect(find.text('On-Device AI Model'), findsOneWidget);
      },
    );

    testWidgets(
      'FoodConfirmationSheet Custom mode supports Clear + Auto-fill after camera detection',
      (tester) async {
        final catalog = _testCatalog();
        final mapped = NutritionMapper(catalog).mapPredictions(const <FoodPrediction>[
          FoodPrediction(label: 'Pizza', rawIndex: 1, confidence: 0.9),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<MealLog>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => FoodConfirmationSheet(
                        mappedPredictions: mapped,
                        catalog: catalog,
                        initialMealType: MealType.lunch,
                        estimator: CatalogNutritionEstimator(catalog),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Custom'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Clear'));
        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Food name'),
          'Banana',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Serving (g)'),
          '100',
        );

        await tester.ensureVisible(find.text('Auto-fill'));
        await tester.tap(find.text('Auto-fill'));
        await tester.pumpAndSettle();

        // Banana at 100g = 89 kcal
        expect(find.widgetWithText(TextField, '89'), findsOneWidget);
      },
    );

    testWidgets('On-Device AI Model dialog starts ready, supports delete and re-download', (
      tester,
    ) async {
      final manager = OnDeviceLlmModelManager(
        backend: _FakeLlmStorageBackend(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FoodTrackerScreen(
            store: _InMemoryHealthDataStore(),
            catalog: _testCatalog(),
            healthConnectGateway: _FakeHealthConnectGateway(),
            llmModelManager: manager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('On-Device AI Model'));
      await tester.pumpAndSettle();

      expect(find.text('On-Device AI Model'), findsOneWidget);
      expect(manager.isReady, isTrue);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(manager.isReady, isFalse);
      expect(find.text('Download'), findsOneWidget);

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(manager.isReady, isTrue);
      expect(find.text('Delete'), findsOneWidget);
    });

    test('HybridNutritionEstimator parses "40g muesli en 50g kwark" with title cleanup', () async {
      final estimator = HybridNutritionEstimator(
        catalog: _testCatalog(),
        llmRunner: _FakeLlmRunner(ready: false),
      );
      final estimate = await estimator.estimate(
        foodName: '40g muesli en 50g kwark',
      );
      expect(estimate, isNotNull);
      expect(estimate!.cleanedTitle, 'Muesli & Kwark');
      expect(estimate.servingGrams, 90);
      expect(estimate.kcal, closeTo(174.5, 0.1));
      expect(estimate.proteinGrams, closeTo(8.75, 0.1));
    });

    testWidgets(
      'ManualFoodAddSheet Catalog search offers "Estimate with AI" and fixes title, weight, and macros',
      (tester) async {
        final store = _InMemoryHealthDataStore();
        final catalog = _testCatalog();
        await tester.pumpWidget(
          MaterialApp(
            home: FoodTrackerScreen(
              store: store,
              catalog: catalog,
              healthConnectGateway: _FakeHealthConnectGateway(),
              estimator: HybridNutritionEstimator(
                catalog: catalog,
                llmRunner: _FakeLlmRunner(ready: false),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Manual Add'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).first,
          '40g muesli en 50g kwark',
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Estimate "40g muesli en 50g kwark" with AI'),
          findsOneWidget,
        );
        await tester.tap(find.text('Estimate "40g muesli en 50g kwark" with AI'));
        await tester.pumpAndSettle();

        // Title fixed, total weight 90g, kcal 174.5
        expect(find.widgetWithText(TextField, 'Muesli & Kwark'), findsOneWidget);
        expect(find.widgetWithText(TextField, '90'), findsOneWidget);
        expect(find.widgetWithText(TextField, '174.5'), findsOneWidget);
      },
    );
  });
}
