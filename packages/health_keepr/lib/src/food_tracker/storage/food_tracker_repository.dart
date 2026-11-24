import '../../contracts/health_data_store.dart';
import '../../contracts/health_record_metadata.dart';
import '../models/daily_nutrition_summary.dart';
import '../models/meal_log.dart';
import '../models/nutrition_food.dart';

/// Repository for local-first Food Tracker meal logs and settings.
///
/// Wraps [HealthDataStore] under [moduleId] (`'food_tracker'`) so production
/// code (`LocalHealthDataStore`) and in-memory fake stores share identical
/// serialization, sorting, and local-calendar filtering logic.
class FoodTrackerRepository {
  FoodTrackerRepository(this._store);

  static const String moduleId = 'food_tracker';
  static const String mealLogsCollection = 'meal_logs';
  static const String customFoodsCollection = 'custom_foods';
  static const String settingsCollection = 'settings';
  static const String dailyGoalRecordId = 'daily_goal';
  static const String favoriteFoodIdsRecordId = 'favorite_food_ids';
  static const String healthConnectSettingsRecordId =
      'health_connect_settings';
  static const double defaultDailyKcalGoal = 2000.0;

  final HealthDataStore _store;

  /// Inserts or updates a [MealLog] record.
  Future<void> saveMealLog(MealLog log) {
    return _store.upsertRecord(
      moduleId,
      mealLogsCollection,
      log.toJson(),
    );
  }

  /// Loads all persisted [MealLog] records sorted newest-first by [MealLog.loggedAt].
  Future<List<MealLog>> loadMealLogs() async {
    final rawRecords = await _store.readCollection(
      moduleId,
      mealLogsCollection,
    );
    final logs = rawRecords.map(MealLog.fromJson).toList();
    logs.sort((a, b) {
      final aTime = DateTime.tryParse(a.loggedAt)?.toUtc();
      final bTime = DateTime.tryParse(b.loggedAt)?.toUtc();
      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }
      if (aTime != null) return -1;
      if (bTime != null) return 1;
      return b.loggedAt.compareTo(a.loggedAt);
    });
    return logs;
  }

  /// Loads all [MealLog] records whose local calendar date matches [date].
  Future<List<MealLog>> loadMealLogsForDate(DateTime date) async {
    final logs = await loadMealLogs();
    return logs.where((log) => log.isOnLocalDate(date)).toList();
  }

  /// Deletes the [MealLog] record with [id].
  Future<void> deleteMealLog(String id) {
    return _store.deleteRecord(moduleId, mealLogsCollection, id);
  }

  /// Persists the daily calorie goal in `'settings'` (`'daily_goal'`).
  Future<void> saveDailyKcalGoal(double goal) {
    if (!goal.isFinite || goal <= 0) {
      throw ArgumentError.value(
        goal,
        'goal',
        'Daily kcal goal must be finite and positive.',
      );
    }
    return _store.upsertRecord(
      moduleId,
      settingsCollection,
      <String, dynamic>{
        'id': dailyGoalRecordId,
        'dailyKcalGoal': goal,
        'updatedAt': HealthRecordMetadata.nowUtcIso(),
        'isSynced': false,
      },
    );
  }

  /// Loads the daily calorie goal, defaulting to [defaultDailyKcalGoal] (`2000.0`).
  Future<double> loadDailyKcalGoal() async {
    final raw = await _store.readRecord(
      moduleId,
      settingsCollection,
      dailyGoalRecordId,
    );
    final rawGoal = raw?['dailyKcalGoal'];
    final value = rawGoal is num ? rawGoal.toDouble() : null;
    if (value == null || !value.isFinite || value <= 0) {
      return defaultDailyKcalGoal;
    }
    return value;
  }

  /// Persists whether optional Health Connect nutrition sync is enabled.
  Future<void> saveHealthConnectSyncEnabled(bool enabled) {
    return _store.upsertRecord(
      moduleId,
      settingsCollection,
      <String, dynamic>{
        'id': healthConnectSettingsRecordId,
        'enabled': enabled,
        'updatedAt': HealthRecordMetadata.nowUtcIso(),
        'isSynced': false,
      },
    );
  }

  /// Loads whether Health Connect nutrition sync is enabled (defaults to `false`).
  Future<bool> loadHealthConnectSyncEnabled() async {
    final raw = await _store.readRecord(
      moduleId,
      settingsCollection,
      healthConnectSettingsRecordId,
    );
    final rawEnabled = raw?['enabled'];
    return rawEnabled is bool ? rawEnabled : false;
  }

  /// Loads meal logs for [date] and the daily goal into a [DailyNutritionSummary].
  Future<DailyNutritionSummary> loadDailySummary(DateTime date) async {
    final logs = await loadMealLogsForDate(date);
    final goal = await loadDailyKcalGoal();
    return DailyNutritionSummary.fromMealLogs(
      date: date,
      logs: logs,
      dailyKcalGoal: goal,
    );
  }

  /// Clears all locally stored Food Tracker data.
  Future<void> clearAllData() {
    return _store.clearModuleData(moduleId);
  }

  /// Saves a user-created [NutritionFood] profile in `'custom_foods'`.
  Future<void> saveCustomFood(NutritionFood food) {
    final json = food.toJson();
    json['updatedAt'] = HealthRecordMetadata.nowUtcIso();
    json['isSynced'] = false;
    return _store.upsertRecord(moduleId, customFoodsCollection, json);
  }

  /// Loads all user-created [NutritionFood] profiles.
  Future<List<NutritionFood>> loadCustomFoods() async {
    final rawRecords = await _store.readCollection(
      moduleId,
      customFoodsCollection,
    );
    return rawRecords.map(NutritionFood.fromJson).toList();
  }

  /// Deletes a user-created [NutritionFood] profile by [id].
  Future<void> deleteCustomFood(String id) {
    return _store.deleteRecord(moduleId, customFoodsCollection, id);
  }

  /// Persists the list of favorite food IDs.
  Future<void> saveFavoriteFoodIds(List<String> ids) {
    final deduplicated = ids.where((id) => id.isNotEmpty).toSet().toList();
    return _store.upsertRecord(
      moduleId,
      settingsCollection,
      <String, dynamic>{
        'id': favoriteFoodIdsRecordId,
        'ids': deduplicated,
        'updatedAt': HealthRecordMetadata.nowUtcIso(),
        'isSynced': false,
      },
    );
  }

  /// Loads the persisted list of favorite food IDs.
  Future<List<String>> loadFavoriteFoodIds() async {
    final raw = await _store.readRecord(
      moduleId,
      settingsCollection,
      favoriteFoodIdsRecordId,
    );
    final rawIds = raw?['ids'];
    if (rawIds is! List) return const <String>[];
    return rawIds
        .map((e) => e.toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  /// Toggles [foodId] in the persisted favorites list and returns the updated list.
  Future<List<String>> toggleFavoriteFoodId(String foodId) async {
    if (foodId.isEmpty) return loadFavoriteFoodIds();
    final current = (await loadFavoriteFoodIds()).toList();
    if (current.contains(foodId)) {
      current.remove(foodId);
    } else {
      current.insert(0, foodId);
    }
    await saveFavoriteFoodIds(current);
    return current;
  }

  /// Returns up to [limit] recently logged food IDs (newest-first, deduplicated).
  Future<List<String>> loadRecentFoodIds({int limit = 8}) async {
    if (limit <= 0) return const <String>[];
    final logs = await loadMealLogs();
    final seen = <String>{};
    final recent = <String>[];
    for (final log in logs) {
      final foodId = log.foodId;
      if (foodId == null || foodId.isEmpty) continue;
      if (seen.add(foodId)) {
        recent.add(foodId);
        if (recent.length >= limit) break;
      }
    }
    return recent;
  }
}
