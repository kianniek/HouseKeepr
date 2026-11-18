import 'package:hive_flutter/hive_flutter.dart';

import 'storage_backend_stub.dart';

class _WebHealthStorageBackend implements HealthStorageBackend {
  bool _hiveInitialized = false;

  @override
  Future<String?> init({String? customPath}) async {
    if (!_hiveInitialized) {
      await Hive.initFlutter('health_keepr_db');
      _hiveInitialized = true;
    }
    return null;
  }

  @override
  Future<Box<String>> openBox(String name, String? path) {
    return Hive.openBox<String>(name);
  }

  @override
  Future<void> deleteBox(String name, String? path) {
    return Hive.deleteBoxFromDisk(name);
  }
}

HealthStorageBackend createHealthStorageBackend() => _WebHealthStorageBackend();
