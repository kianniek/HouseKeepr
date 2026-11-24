import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';
import 'package:hive/hive.dart';

class _InMemoryHealthDataStore implements HealthDataStore {
  final Map<String, Map<String, Map<String, Map<String, dynamic>>>> _data =
      <String, Map<String, Map<String, Map<String, dynamic>>>>{};

  @override
  Future<List<Map<String, dynamic>>> readCollection(
    String moduleId,
    String collection,
  ) async {
    final items = _data[moduleId]?[collection]?.values ??
        const Iterable<Map<String, dynamic>>.empty();
    return items.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<Map<String, dynamic>?> readRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    final item = _data[moduleId]?[collection]?[id];
    return item == null ? null : Map<String, dynamic>.from(item);
  }

  @override
  Future<void> upsertRecord(
    String moduleId,
    String collection,
    Map<String, dynamic> record,
  ) async {
    final normalized = Map<String, dynamic>.from(record);
    final existingId = normalized['id'];
    final id = (existingId is String && existingId.isNotEmpty)
        ? existingId
        : HealthRecordMetadata.generateId();
    normalized['id'] = id;

    final existingUpdatedAt = normalized['updatedAt'];
    if (existingUpdatedAt is! String || existingUpdatedAt.isEmpty) {
      normalized['updatedAt'] = HealthRecordMetadata.nowUtcIso();
    }
    if (normalized['isSynced'] is! bool) {
      normalized['isSynced'] = false;
    }

    _data
        .putIfAbsent(moduleId, () => <String, Map<String, Map<String, dynamic>>>{})
        .putIfAbsent(collection, () => <String, Map<String, dynamic>>{})[id] =
        normalized;
  }

  @override
  Future<void> deleteRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    _data[moduleId]?[collection]?.remove(id);
  }

  @override
  Future<void> clearModuleData(String moduleId) async {
    _data.remove(moduleId);
  }

  @override
  Future<void> close() async {}
}

void main() {
  late Directory tempDir;
  late LocalHealthDataStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('food_tracker_storage_test_');
    store = LocalHealthDataStore(
      storagePathProvider: () async => tempDir.path,
    );
  });

  tearDown(() async {
    await store.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Food Tracker Models & Macro Scaling', () {
    test('MealType parses strings and selects defaults by local time', () {
      expect(MealType.fromString('breakfast'), MealType.breakfast);
      expect(MealType.fromString('  LUNCH  '), MealType.lunch);
      expect(MealType.fromString('Dinner'), MealType.dinner);
      expect(MealType.fromString('unknown'), MealType.snack);
      expect(
        MealType.fromString(null, fallback: MealType.breakfast),
        MealType.breakfast,
      );

      expect(
        MealType.defaultForLocalTime(DateTime(2026, 11, 22, 8, 30)),
        MealType.breakfast,
      );
      expect(
        MealType.defaultForLocalTime(DateTime(2026, 11, 22, 12, 15)),
        MealType.lunch,
      );
      expect(
        MealType.defaultForLocalTime(DateTime(2026, 11, 22, 18, 45)),
        MealType.dinner,
      );
      expect(
        MealType.defaultForLocalTime(DateTime(2026, 11, 22, 22, 10)),
        MealType.snack,
      );
    });

    test('NutritionFood parses primary and fallback macro keys and scales accurately', () {
      final primary = NutritionFood.fromJson(<String, dynamic>{
        'id': 'pizza',
        'name': 'Pizza',
        'category': 'pizza',
        'aliases': <String>['cheese pizza'],
        'kcalPer100g': 266.0,
        'proteinPer100g': 11.4,
        'carbsPer100g': 33.3,
        'fatPer100g': 9.8,
        'defaultServingGrams': 150.0,
        'servingLabel': '1 slice (150g)',
      });
      final fallback = NutritionFood.fromJson(<String, dynamic>{
        'id': 'oats',
        'name': 'Oats',
        'category': 'breakfast',
        'kcal': 380.0,
        'protein': 13.0,
        'carbs': 67.0,
        'fat': 7.0,
        'defaultServingGrams': 50.0,
      });

      expect(primary.protein, 11.4);
      expect(primary.carbs, 33.3);
      expect(primary.fat, 9.8);
      expect(fallback.proteinPer100g, 13.0);
      expect(fallback.carbsPer100g, 67.0);
      expect(fallback.fatPer100g, 7.0);
      expect(fallback.servingLabel, '50g');

      final scaled = primary.macrosForGrams(150.0);
      expect(scaled.servingGrams, 150.0);
      expect(scaled.kcal, closeTo(399.0, 0.001));
      expect(scaled.proteinGrams, closeTo(17.1, 0.001));
      expect(scaled.carbsGrams, closeTo(49.95, 0.001));
      expect(scaled.fatGrams, closeTo(14.7, 0.001));

      expect(primary.forServing(0.0), NutritionMacros.zero);
      expect(primary.forServing(-25.0), NutritionMacros.zero);
      expect(primary.forServing(double.nan), NutritionMacros.zero);
    });

    test('MealLog metadata, copyWith, and JSON round-trip work accurately', () async {
      final food = const NutritionFood(
        id: 'chicken_breast_grilled',
        name: 'Chicken Breast (Grilled)',
        category: 'poultry',
        kcalPer100g: 165.0,
        proteinPer100g: 31.0,
        carbsPer100g: 0.0,
        fatPer100g: 3.6,
        defaultServingGrams: 150.0,
        servingLabel: '1 breast (150g)',
      );

      final created = MealLog.fromNutritionFood(
        food: food,
        mealType: MealType.dinner,
        servingGrams: 200.0,
        loggedAt: DateTime(2026, 11, 22, 19, 0),
        healthConnectId: 'hc-123',
      );

      expect(created.id, isNotEmpty);
      expect(created.updatedAt, endsWith('Z'));
      expect(created.isSynced, isFalse);
      expect(created.kcal, closeTo(330.0, 0.001));
      expect(created.proteinGrams, closeTo(62.0, 0.001));
      expect(created.fatGrams, closeTo(7.2, 0.001));

      final roundTripped = MealLog.fromJson(created.toJson());
      expect(roundTripped, created);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      final updated = created.copyWith(servingGrams: 100.0, kcal: 165.0);
      expect(updated.id, created.id);
      expect(updated.updatedAt, isNot(created.updatedAt));
      expect(updated.servingGrams, 100.0);
      expect(updated.kcal, 165.0);
    });

    test('FoodPrediction preserves rawIndex, confidencePercent, and JSON round-trip', () {
      const food = NutritionFood(
        id: 'pizza',
        name: 'Pizza',
        category: 'pizza',
        kcalPer100g: 266.0,
        proteinPer100g: 11.4,
        carbsPer100g: 33.3,
        fatPer100g: 9.8,
        defaultServingGrams: 150.0,
        servingLabel: '1 slice (150g)',
      );
      const prediction = FoodPrediction(
        label: 'Pizza',
        rawIndex: 42,
        confidence: 0.875,
        matchedFood: food,
        matchSource: 'exact',
      );

      expect(prediction.confidencePercent, closeTo(87.5, 0.001));
      expect(FoodPrediction.fromJson(prediction.toJson()), prediction);

      final cleared = prediction.copyWith(clearMatchedFood: true);
      expect(cleared.matchedFood, isNull);
      expect(cleared.rawIndex, 42);
    });
  });

  group('LocalHealthDataStore Food Tracker Persistence', () {
    test('persists meal logs across close() and reopen with newest-first sorting', () async {
      final breakfast = MealLog.create(
        foodName: 'Oatmeal',
        foodId: 'oatmeal_cooked',
        mealType: MealType.breakfast,
        servingGrams: 234.0,
        kcal: 166.14,
        proteinGrams: 5.85,
        carbsGrams: 28.08,
        fatGrams: 3.51,
        loggedAt: DateTime(2026, 11, 22, 8, 0),
      );
      final lunch = MealLog.create(
        foodName: 'Chicken Breast',
        foodId: 'chicken_breast_grilled',
        mealType: MealType.lunch,
        servingGrams: 150.0,
        kcal: 247.5,
        proteinGrams: 46.5,
        carbsGrams: 0.0,
        fatGrams: 5.4,
        loggedAt: DateTime(2026, 11, 22, 13, 0),
      );
      final snack = MealLog.create(
        foodName: 'Banana',
        foodId: 'banana',
        mealType: MealType.snack,
        servingGrams: 118.0,
        kcal: 105.02,
        proteinGrams: 1.3,
        carbsGrams: 26.9,
        fatGrams: 0.35,
        loggedAt: DateTime(2026, 11, 22, 16, 0),
      );

      await store.saveMealLog(breakfast);
      await store.saveMealLog(snack);
      await store.saveMealLog(lunch);
      await store.close();

      final reopened = LocalHealthDataStore(
        storagePathProvider: () async => tempDir.path,
      );
      final loaded = await reopened.loadMealLogs();
      expect(loaded, hasLength(3));
      expect(loaded.map((l) => l.id).toList(), <String>[
        snack.id,
        lunch.id,
        breakfast.id,
      ]);
      expect(loaded[1].mealType, MealType.lunch);
      expect(loaded[1].proteinGrams, closeTo(46.5, 0.001));

      // Update existing entry without duplicating ID.
      final editedLunch = lunch.copyWith(servingGrams: 200.0, kcal: 330.0);
      await reopened.saveMealLog(editedLunch);
      await reopened.close();

      final reopened2 = LocalHealthDataStore(
        storagePathProvider: () async => tempDir.path,
      );
      final afterUpdate = await reopened2.loadMealLogs();
      expect(afterUpdate, hasLength(3));
      final updatedLunch = afterUpdate.firstWhere((l) => l.id == lunch.id);
      expect(updatedLunch.kcal, closeTo(330.0, 0.001));

      // Delete one entry and verify persistence.
      await reopened2.deleteMealLog(snack.id);
      await reopened2.close();

      final reopened3 = LocalHealthDataStore(
        storagePathProvider: () async => tempDir.path,
      );
      final afterDelete = await reopened3.loadMealLogs();
      expect(afterDelete, hasLength(2));
      expect(afterDelete.any((l) => l.id == snack.id), isFalse);
      await reopened3.close();
    });

    test('loadMealLogsForDate filters strictly by local calendar day', () async {
      final prevDayLate = MealLog.create(
        foodName: 'Late Snack Nov 21',
        mealType: MealType.snack,
        servingGrams: 50,
        kcal: 120,
        proteinGrams: 3,
        carbsGrams: 18,
        fatGrams: 4,
        loggedAt: DateTime(2026, 11, 21, 23, 55),
      );
      final targetEarly = MealLog.create(
        foodName: 'Early Nov 22',
        mealType: MealType.breakfast,
        servingGrams: 100,
        kcal: 220,
        proteinGrams: 8,
        carbsGrams: 30,
        fatGrams: 7,
        loggedAt: DateTime(2026, 11, 22, 0, 5),
      );
      final targetLate = MealLog.create(
        foodName: 'Late Nov 22',
        mealType: MealType.dinner,
        servingGrams: 200,
        kcal: 450,
        proteinGrams: 30,
        carbsGrams: 40,
        fatGrams: 16,
        loggedAt: DateTime(2026, 11, 22, 23, 55),
      );
      final nextDayEarly = MealLog.create(
        foodName: 'Early Nov 23',
        mealType: MealType.snack,
        servingGrams: 60,
        kcal: 150,
        proteinGrams: 4,
        carbsGrams: 20,
        fatGrams: 5,
        loggedAt: DateTime(2026, 11, 23, 0, 5),
      );

      await store.saveMealLog(prevDayLate);
      await store.saveMealLog(targetEarly);
      await store.saveMealLog(targetLate);
      await store.saveMealLog(nextDayEarly);

      final nov22Logs =
          await store.loadMealLogsForDate(DateTime(2026, 11, 22, 14, 0));
      expect(nov22Logs, hasLength(2));
      expect(
        nov22Logs.map((l) => l.foodName).toSet(),
        <String>{'Early Nov 22', 'Late Nov 22'},
      );
    });

    test('persists daily kcal goal and Health Connect toggle across restarts', () async {
      expect(await store.loadDailyKcalGoal(), 2000.0);
      expect(await store.loadHealthConnectSyncEnabled(), isFalse);

      expect(
        () => store.saveDailyKcalGoal(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => store.saveDailyKcalGoal(-500),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => store.saveDailyKcalGoal(double.infinity),
        throwsA(isA<ArgumentError>()),
      );

      await store.saveDailyKcalGoal(2350.0);
      await store.saveHealthConnectSyncEnabled(true);
      await store.close();

      final reopened = LocalHealthDataStore(
        storagePathProvider: () async => tempDir.path,
      );
      expect(await reopened.loadDailyKcalGoal(), 2350.0);
      expect(await reopened.loadHealthConnectSyncEnabled(), isTrue);

      final rawGoal = await reopened.readRecord(
        'food_tracker',
        'settings',
        'daily_goal',
      );
      expect(rawGoal?['dailyKcalGoal'], 2350.0);
      expect(rawGoal?['updatedAt'], endsWith('Z'));
      expect(rawGoal?['isSynced'], isFalse);

      final rawHc = await reopened.readRecord(
        'food_tracker',
        'settings',
        'health_connect_settings',
      );
      expect(rawHc?['enabled'], isTrue);
      await reopened.close();
    });

    test('clearModuleData(food_tracker) clears food tracker without touching open_gym', () async {
      await store.upsertRecord('open_gym', 'workouts', <String, dynamic>{
        'title': 'Push Workout',
      });
      await store.saveMealLog(
        MealLog.create(
          foodName: 'Greek Yogurt',
          mealType: MealType.breakfast,
          servingGrams: 170,
          kcal: 124.1,
          proteinGrams: 17.0,
          carbsGrams: 6.63,
          fatGrams: 3.23,
        ),
      );
      await store.saveDailyKcalGoal(2400.0);
      await store.saveHealthConnectSyncEnabled(true);

      await store.clearModuleData('food_tracker');

      expect(await store.loadMealLogs(), isEmpty);
      expect(await store.loadDailyKcalGoal(), 2000.0);
      expect(await store.loadHealthConnectSyncEnabled(), isFalse);

      final openGymWorkouts = await store.readCollection('open_gym', 'workouts');
      expect(openGymWorkouts, hasLength(1));
      expect(openGymWorkouts.first['title'], 'Push Workout');
    });
  });

  group('DailyNutritionSummary & FoodTrackerRepository with Fake Store', () {
    test('aggregates logs across all 4 MealType buckets and calculates totals', () async {
      final repo = FoodTrackerRepository(_InMemoryHealthDataStore());
      final day = DateTime(2026, 11, 22);

      await repo.saveDailyKcalGoal(1800.0);
      await repo.saveHealthConnectSyncEnabled(true);

      await repo.saveMealLog(
        MealLog.create(
          foodName: 'Oatmeal',
          mealType: MealType.breakfast,
          servingGrams: 200,
          kcal: 500,
          proteinGrams: 20,
          carbsGrams: 80,
          fatGrams: 10,
          loggedAt: DateTime(2026, 11, 22, 8, 15),
        ),
      );
      await repo.saveMealLog(
        MealLog.create(
          foodName: 'Salmon Bowl',
          mealType: MealType.lunch,
          servingGrams: 330,
          kcal: 700,
          proteinGrams: 45,
          carbsGrams: 60,
          fatGrams: 25,
          loggedAt: DateTime(2026, 11, 22, 12, 30),
        ),
      );
      await repo.saveMealLog(
        MealLog.create(
          foodName: 'Steak Dinner',
          mealType: MealType.dinner,
          servingGrams: 250,
          kcal: 800,
          proteinGrams: 55,
          carbsGrams: 30,
          fatGrams: 42,
          loggedAt: DateTime(2026, 11, 22, 19, 10),
        ),
      );
      // Different day log must be excluded from day summary.
      await repo.saveMealLog(
        MealLog.create(
          foodName: 'Yesterday Pizza',
          mealType: MealType.dinner,
          servingGrams: 150,
          kcal: 400,
          proteinGrams: 18,
          carbsGrams: 48,
          fatGrams: 14,
          loggedAt: DateTime(2026, 11, 21, 19, 10),
        ),
      );

      final summary = await repo.loadDailySummary(day);
      expect(summary.mealCount, 3);
      expect(summary.mealsByType.keys, containsAll(MealType.values));
      expect(summary.logsForMealType(MealType.breakfast), hasLength(1));
      expect(summary.logsForMealType(MealType.lunch), hasLength(1));
      expect(summary.logsForMealType(MealType.dinner), hasLength(1));
      expect(summary.logsForMealType(MealType.snack), isEmpty);
      expect(summary.kcalForMealType(MealType.snack), 0.0);

      expect(summary.totalKcal, closeTo(2000.0, 0.001));
      expect(summary.totalProteinGrams, closeTo(120.0, 0.001));
      expect(summary.totalCarbsGrams, closeTo(170.0, 0.001));
      expect(summary.totalFatGrams, closeTo(77.0, 0.001));
      expect(summary.dailyKcalGoal, 1800.0);
      expect(summary.isOverGoal, isTrue);
      expect(summary.overageKcal, closeTo(200.0, 0.001));
      expect(summary.remainingKcal, closeTo(-200.0, 0.001));
      expect(summary.goalProgress, 1.0);

      await repo.clearAllData();
      expect(await repo.loadMealLogs(), isEmpty);
      expect(await repo.loadDailyKcalGoal(), 2000.0);
    });
  });

  group('Adversarial Resilience & Edge Cases', () {
    test('survives corrupt JSON in Hive meal_logs, settings, and manifest', () async {
      final valid = MealLog.create(
        foodName: 'Valid Oats',
        mealType: MealType.breakfast,
        servingGrams: 100,
        kcal: 150,
        proteinGrams: 5,
        carbsGrams: 27,
        fatGrams: 2.5,
      );
      await store.saveMealLog(valid);
      await store.saveDailyKcalGoal(2100.0);
      await store.saveHealthConnectSyncEnabled(true);
      await store.close();

      Hive.init(tempDir.path);
      final mealBox = await Hive.openBox<String>('hk_food_tracker__meal_logs');
      await mealBox.put('corrupt_1', '{corrupt_json_truncated');
      await mealBox.put('non_map_1', jsonEncode(<int>[1, 2, 3]));
      await mealBox.close();

      final settingsBox = await Hive.openBox<String>('hk_food_tracker__settings');
      await settingsBox.put('daily_goal', 'NOT_JSON{{{');
      await settingsBox.put('health_connect_settings', 'NOT_JSON{{{');
      await settingsBox.close();

      final manifestBox = await Hive.openBox<String>('__health_keepr_manifest__');
      await manifestBox.put('food_tracker', '{corrupt_manifest');
      await manifestBox.close();

      final reopened = LocalHealthDataStore(
        storagePathProvider: () async => tempDir.path,
      );
      final loadedLogs = await reopened.loadMealLogs();
      expect(loadedLogs, hasLength(1));
      expect(loadedLogs.single.id, valid.id);
      expect(await reopened.loadDailyKcalGoal(), 2000.0);
      expect(await reopened.loadHealthConnectSyncEnabled(), isFalse);
      expect(
        await reopened.readRecord('food_tracker', 'settings', 'daily_goal'),
        isNull,
      );

      await reopened.clearModuleData('food_tracker');
      expect(await reopened.loadMealLogs(), isEmpty);
      await reopened.close();
    });

    test('backfills missing id from Hive key so orphan records are deterministically deletable', () async {
      Hive.init(tempDir.path);
      final mealBox = await Hive.openBox<String>('hk_food_tracker__meal_logs');
      await mealBox.put(
        'hive-orphan-key',
        jsonEncode(<String, dynamic>{
          'foodName': 'Orphan Toast',
          'mealType': 'breakfast',
          'servingGrams': 60,
          'kcal': 160,
          'proteinGrams': 5,
          'carbsGrams': 30,
          'fatGrams': 2,
          'loggedAt': '2026-11-22T09:00:00.000Z',
          'updatedAt': '2026-11-22T09:00:00.000Z',
          'isSynced': false,
        }),
      );
      await mealBox.close();

      final first = await store.loadMealLogs();
      expect(first, hasLength(1));
      expect(first.single.id, 'hive-orphan-key');

      final second = await store.loadMealLogs();
      expect(second.single.id, 'hive-orphan-key');

      await store.deleteMealLog(first.single.id);
      expect(await store.loadMealLogs(), isEmpty);
    });

    test('synchronous MealLog.copyWith strictly advances updatedAt across back-to-back calls', () {
      var current = MealLog.create(
        foodName: 'Greek Yogurt',
        mealType: MealType.breakfast,
        servingGrams: 170,
        kcal: 124,
        proteinGrams: 17,
        carbsGrams: 6.6,
        fatGrams: 3.2,
      );

      for (var i = 0; i < 50; i++) {
        final next = current.copyWith(servingGrams: 170.0 + i + 1);
        final prevDt = DateTime.parse(current.updatedAt).toUtc();
        final nextDt = DateTime.parse(next.updatedAt).toUtc();
        expect(nextDt.isAfter(prevDt), isTrue);
        current = next;
      }
    });

    test('sanitizes negative/NaN/overflow macros and wrong-typed JSON fields safely', () async {
      final created = MealLog.create(
        foodName: 'Bad Numbers',
        mealType: MealType.snack,
        servingGrams: -100,
        kcal: -500,
        proteinGrams: double.nan,
        carbsGrams: -10,
        fatGrams: double.negativeInfinity,
      );
      expect(created.servingGrams, 0.0);
      expect(created.kcal, 0.0);
      expect(created.proteinGrams, 0.0);
      expect(created.carbsGrams, 0.0);
      expect(created.fatGrams, 0.0);

      final parsedWrongTypes = MealLog.fromJson(<String, dynamic>{
        'id': 12345,
        'foodName': 999,
        'foodId': 42,
        'mealType': true,
        'servingGrams': -150.0,
        'kcal': -500.0,
        'proteinGrams': 'NaN',
        'carbsGrams': double.infinity,
        'fatGrams': <int>[1],
        'loggedAt': 123,
        'healthConnectId': 99,
        'updatedAt': false,
        'isSynced': 'yes',
      });
      expect(parsedWrongTypes.id, isNotEmpty);
      expect(parsedWrongTypes.foodName, '');
      expect(parsedWrongTypes.foodId, isNull);
      expect(parsedWrongTypes.mealType, MealType.snack);
      expect(parsedWrongTypes.servingGrams, 0.0);
      expect(parsedWrongTypes.kcal, 0.0);
      expect(parsedWrongTypes.proteinGrams, 0.0);
      expect(parsedWrongTypes.carbsGrams, 0.0);
      expect(parsedWrongTypes.fatGrams, 0.0);
      expect(parsedWrongTypes.healthConnectId, isNull);
      expect(parsedWrongTypes.isSynced, isFalse);

      // Extreme finite serving in NutritionFood.macrosForGrams must remain finite & JSON-encodable.
      const rice = NutritionFood(
        id: 'rice',
        name: 'Rice',
        category: 'rice',
        kcalPer100g: 130.0,
        proteinPer100g: 2.7,
        carbsPer100g: 28.0,
        fatPer100g: 0.3,
        defaultServingGrams: 150.0,
        servingLabel: '1 cup',
      );
      final extremeMacros = rice.macrosForGrams(1e308);
      expect(extremeMacros.kcal.isFinite, isTrue);
      expect(extremeMacros.proteinGrams.isFinite, isTrue);
      expect(extremeMacros.carbsGrams.isFinite, isTrue);
      expect(extremeMacros.fatGrams.isFinite, isTrue);

      final extremeLog = MealLog.fromNutritionFood(
        food: rice,
        mealType: MealType.dinner,
        servingGrams: 1e308,
      );
      await store.saveMealLog(extremeLog);
      final reloadedExtreme = await store.loadMealLogs();
      expect(reloadedExtreme.single.kcal.isFinite, isTrue);

      // Wrong-typed settings fallback cleanly.
      final fake = _InMemoryHealthDataStore();
      await fake.upsertRecord('food_tracker', 'settings', <String, dynamic>{
        'id': 'daily_goal',
        'dailyKcalGoal': '2500',
      });
      await fake.upsertRecord('food_tracker', 'settings', <String, dynamic>{
        'id': 'health_connect_settings',
        'enabled': 'true',
      });
      final repo = FoodTrackerRepository(fake);
      expect(await repo.loadDailyKcalGoal(), 2000.0);
      expect(await repo.loadHealthConnectSyncEnabled(), isFalse);
    });

    test('loadMealLogs sorts valid timestamps before malformed loggedAt and NaN goalProgress yields 0.0', () async {
      final fake = _InMemoryHealthDataStore();
      await fake.upsertRecord('food_tracker', 'meal_logs', <String, dynamic>{
        'id': 'corrupt-zzz',
        'foodName': 'Malformed Time',
        'mealType': 'snack',
        'servingGrams': 50.0,
        'kcal': 100.0,
        'proteinGrams': 2.0,
        'carbsGrams': 15.0,
        'fatGrams': 3.0,
        'loggedAt': 'zzz-not-a-date',
        'updatedAt': '2026-11-22T12:00:00.000Z',
        'isSynced': false,
      });
      await fake.upsertRecord('food_tracker', 'meal_logs', <String, dynamic>{
        'id': 'valid-2026',
        'foodName': 'Valid Time',
        'mealType': 'lunch',
        'servingGrams': 100.0,
        'kcal': 300.0,
        'proteinGrams': 20.0,
        'carbsGrams': 30.0,
        'fatGrams': 10.0,
        'loggedAt': '2026-11-22T12:00:00.000Z',
        'updatedAt': '2026-11-22T12:00:00.000Z',
        'isSynced': false,
      });
      await fake.upsertRecord('food_tracker', 'meal_logs', <String, dynamic>{
        'id': 'corrupt-aaa',
        'foodName': 'Malformed Early Alpha',
        'mealType': 'snack',
        'servingGrams': 50.0,
        'kcal': 100.0,
        'proteinGrams': 2.0,
        'carbsGrams': 15.0,
        'fatGrams': 3.0,
        'loggedAt': 'aaa-not-a-date',
        'updatedAt': '2026-11-22T12:00:00.000Z',
        'isSynced': false,
      });

      final repo = FoodTrackerRepository(fake);
      final sorted = await repo.loadMealLogs();
      expect(
        sorted.map((e) => e.id).toList(),
        <String>['valid-2026', 'corrupt-zzz', 'corrupt-aaa'],
      );

      final nanSummary = DailyNutritionSummary.fromMealLogs(
        date: DateTime(2026, 11, 22),
        logs: const <MealLog>[],
        dailyKcalGoal: double.nan,
      );
      expect(nanSummary.goalProgress, 0.0);

      final directNanSummary = DailyNutritionSummary(
        date: DateTime(2026, 11, 22),
        dailyKcalGoal: double.nan,
        totalKcal: 500.0,
        totalProteinGrams: 20.0,
        totalCarbsGrams: 50.0,
        totalFatGrams: 20.0,
        mealsByType: const <MealType, List<MealLog>>{},
        kcalByMealType: const <MealType, double>{},
      );
      expect(directNanSummary.goalProgress, 0.0);
      expect(directNanSummary.isOverGoal, isFalse);
    });
  });
}
