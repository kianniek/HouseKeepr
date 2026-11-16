import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../contracts/health_data_store.dart';
import '../contracts/health_record_metadata.dart';

/// Signature for resolving the root directory where `health_keepr.db` lives.
typedef HealthStorageDirectoryProvider = Future<Directory> Function();

/// Hive-backed local-only implementation of [HealthDataStore].
///
/// Lazily initializes a dedicated `health_keepr.db` directory on first access,
/// keeping all HealthKeepr and mini-app data strictly on-device and isolated
/// from HouseKeepr's Firebase/household boxes.
class LocalHealthDataStore implements HealthDataStore {
  LocalHealthDataStore({
    HealthStorageDirectoryProvider? directoryProvider,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectoryProvider;

  static const String _dbDirectoryName = 'health_keepr.db';
  static const String _manifestBoxName = '__health_keepr_manifest__';

  final HealthStorageDirectoryProvider _directoryProvider;
  String? _dbPath;
  final Map<String, Box<String>> _openBoxes = <String, Box<String>>{};
  Box<String>? _manifestBox;
  Future<void>? _initFuture;

  static Future<Directory> _defaultDirectoryProvider() async {
    final appDocs = await getApplicationDocumentsDirectory();
    return Directory('${appDocs.path}${Platform.pathSeparator}$_dbDirectoryName');
  }

  /// Whether the underlying `health_keepr.db` directory has been initialized.
  bool get isInitialized => _dbPath != null;

  Future<void> _ensureInitialized() {
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    final dir = await _directoryProvider();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dbPath = dir.path;
    _manifestBox = await Hive.openBox<String>(
      _manifestBoxName,
      path: _dbPath,
    );
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
    final box = await Hive.openBox<String>(name, path: _dbPath);
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
    final collections = raw == null
        ? <String>{}
        : (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
    if (collections.add(boxName)) {
      await manifest.put(moduleId, jsonEncode(collections.toList()));
    }
  }

  @override
  Future<List<Map<String, dynamic>>> readCollection(
    String moduleId,
    String collection,
  ) async {
    final box = await _getCollectionBox(moduleId, collection);
    final records = <Map<String, dynamic>>[];
    for (final raw in box.values) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        records.add(decoded);
      } else if (decoded is Map) {
        records.add(Map<String, dynamic>.from(decoded));
      }
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
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
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
      final boxNames = (jsonDecode(raw) as List<dynamic>).cast<String>();
      for (final name in boxNames) {
        final openBox = _openBoxes.remove(name);
        if (openBox != null && openBox.isOpen) {
          await openBox.clear();
          await openBox.deleteFromDisk();
        } else {
          await Hive.deleteBoxFromDisk(name, path: _dbPath);
        }
      }
      await manifest.delete(moduleId);
    }

    // Also clear any open boxes matching the module prefix if not yet flushed.
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
  }
}
