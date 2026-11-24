import 'dart:convert';

import 'package:hive/hive.dart';

import '../contracts/health_data_store.dart';
import '../contracts/health_record_metadata.dart';
import '../food_tracker/models/meal_log.dart';
import '../food_tracker/storage/food_tracker_repository.dart';
import 'storage_backend_stub.dart';
import 'storage_backend_stub.dart'
    if (dart.library.io) 'storage_backend_io.dart'
    if (dart.library.js_interop) 'storage_backend_web.dart' as backend_impl;

/// Signature for resolving a custom storage path (primarily for VM tests).
typedef HealthStoragePathProvider = Future<String> Function();

/// Hive-backed local-only implementation of [HealthDataStore].
///
/// Works on both Android (`health_keepr.db` directory) and Web (IndexedDB),
/// lazily initializing on first access and keeping all HealthKeepr and
/// mini-app data strictly on-device and isolated from HouseKeepr's storage.
class LocalHealthDataStore implements HealthDataStore {
  LocalHealthDataStore({
    HealthStoragePathProvider? storagePathProvider,
  })  : _storagePathProvider = storagePathProvider,
        _backend = backend_impl.createHealthStorageBackend();

  static const String _manifestBoxName = '__health_keepr_manifest__';

  final HealthStoragePathProvider? _storagePathProvider;
  final HealthStorageBackend _backend;

  String? _dbPath;
  bool _initialized = false;
  final Map<String, Box<String>> _openBoxes = <String, Box<String>>{};
  Box<String>? _manifestBox;
  Future<void>? _initFuture;
  late final FoodTrackerRepository _foodTrackerRepository =
      FoodTrackerRepository(this);

  /// Whether the underlying `health_keepr.db` store has been initialized.
  bool get isInitialized => _initialized;

  Future<void> _ensureInitialized() {
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    final customPath =
        _storagePathProvider != null ? await _storagePathProvider() : null;
    _dbPath = await _backend.init(customPath: customPath);
    _manifestBox = await _backend.openBox(_manifestBoxName, _dbPath);
    _initialized = true;
  }

  String _boxName(String moduleId, String collection) {
    final safeModule = moduleId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeCollection =
        collection.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'hk_${safeModule}__$safeCollection';
  }

  Future<Box<String>> _getCollectionBox(
    String moduleId,
    String collection,
  ) async {
    await _ensureInitialized();
    final name = _boxName(moduleId, collection);
    final existing = _openBoxes[name];
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final box = await _backend.openBox(name, _dbPath);
    _openBoxes[name] = box;
    await _registerCollectionForModule(moduleId, name);
    return box;
  }

  Future<void> _registerCollectionForModule(
    String moduleId,
    String boxName,
  ) async {
    final manifest = _manifestBox;
    if (manifest == null) return;
    final raw = manifest.get(moduleId);
    final collections = _decodeManifestSet(raw);
    if (collections.add(boxName) || (raw != null && collections.length == 1)) {
      await manifest.put(moduleId, jsonEncode(collections.toList()));
    }
  }

  Set<String> _decodeManifestSet(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
    } catch (_) {
      // Recover gracefully from corrupt manifest JSON.
    }
    return <String>{};
  }

  @override
  Future<List<Map<String, dynamic>>> readCollection(
    String moduleId,
    String collection,
  ) async {
    final box = await _getCollectionBox(moduleId, collection);
    final records = <Map<String, dynamic>>[];
    for (final entry in box.toMap().entries) {
      Map<String, dynamic>? record;
      try {
        final decoded = jsonDecode(entry.value);
        if (decoded is Map<String, dynamic>) {
          record = Map<String, dynamic>.from(decoded);
        } else if (decoded is Map) {
          record = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Skip corrupt non-JSON entries so valid records still load.
      }
      if (record == null) continue;
      final existingId = record['id'];
      if (existingId is! String || existingId.isEmpty) {
        record['id'] = entry.key.toString();
      }
      records.add(record);
    }
    return records;
  }

  @override
  Future<Map<String, dynamic>?> readRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    final box = await _getCollectionBox(moduleId, collection);
    final raw = box.get(id);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      Map<String, dynamic>? record;
      if (decoded is Map<String, dynamic>) {
        record = Map<String, dynamic>.from(decoded);
      } else if (decoded is Map) {
        record = Map<String, dynamic>.from(decoded);
      }
      if (record == null) return null;
      final existingId = record['id'];
      if (existingId is! String || existingId.isEmpty) {
        record['id'] = id;
      }
      return record;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsertRecord(
    String moduleId,
    String collection,
    Map<String, dynamic> record,
  ) async {
    final box = await _getCollectionBox(moduleId, collection);
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

    await box.put(id, jsonEncode(normalized));
  }

  @override
  Future<void> deleteRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    final box = await _getCollectionBox(moduleId, collection);
    await box.delete(id);
  }

  @override
  Future<void> clearModuleData(String moduleId) async {
    await _ensureInitialized();
    final manifest = _manifestBox;
    if (manifest == null) return;

    final raw = manifest.get(moduleId);
    if (raw != null) {
      final boxNames = _decodeManifestSet(raw).toList();
      for (final name in boxNames) {
        final openBox = _openBoxes.remove(name);
        if (openBox != null && openBox.isOpen) {
          await openBox.clear();
          await openBox.deleteFromDisk();
        } else {
          await _backend.deleteBox(name, _dbPath);
        }
      }
      await manifest.delete(moduleId);
    }

    final safeModule = moduleId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final prefix = 'hk_${safeModule}__';
    final matchingKeys =
        _openBoxes.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in matchingKeys) {
      final box = _openBoxes.remove(key);
      if (box != null && box.isOpen) {
        await box.clear();
        await box.deleteFromDisk();
      }
    }
  }

  @override
  Future<void> close() async {
    for (final box in _openBoxes.values) {
      if (box.isOpen) {
        await box.close();
      }
    }
    _openBoxes.clear();
    if (_manifestBox != null && _manifestBox!.isOpen) {
      await _manifestBox!.close();
    }
    _manifestBox = null;
    _initFuture = null;
    _dbPath = null;
    _initialized = false;
  }

  /// Inserts or updates a Food Tracker [MealLog].
  Future<void> saveMealLog(MealLog log) =>
      _foodTrackerRepository.saveMealLog(log);

  /// Loads all persisted Food Tracker [MealLog]s sorted newest-first.
  Future<List<MealLog>> loadMealLogs() =>
      _foodTrackerRepository.loadMealLogs();

  /// Loads Food Tracker [MealLog]s matching [date]'s local calendar day.
  Future<List<MealLog>> loadMealLogsForDate(DateTime date) =>
      _foodTrackerRepository.loadMealLogsForDate(date);

  /// Deletes the Food Tracker [MealLog] with [id].
  Future<void> deleteMealLog(String id) =>
      _foodTrackerRepository.deleteMealLog(id);

  /// Persists the daily calorie goal for Food Tracker.
  Future<void> saveDailyKcalGoal(double goal) =>
      _foodTrackerRepository.saveDailyKcalGoal(goal);

  /// Loads the daily calorie goal for Food Tracker (defaults to `2000.0`).
  Future<double> loadDailyKcalGoal() =>
      _foodTrackerRepository.loadDailyKcalGoal();

  /// Persists whether Health Connect nutrition sync is enabled.
  Future<void> saveHealthConnectSyncEnabled(bool enabled) =>
      _foodTrackerRepository.saveHealthConnectSyncEnabled(enabled);

  /// Loads whether Health Connect nutrition sync is enabled.
  Future<bool> loadHealthConnectSyncEnabled() =>
      _foodTrackerRepository.loadHealthConnectSyncEnabled();
}
