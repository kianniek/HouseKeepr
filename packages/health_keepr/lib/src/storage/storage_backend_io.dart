import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'storage_backend_stub.dart';

class _IoHealthStorageBackend implements HealthStorageBackend {
  static const String _dbDirectoryName = 'health_keepr.db';

  @override
  Future<String?> init({String? customPath}) async {
    final path = customPath ??
        '${(await getApplicationDocumentsDirectory()).path}'
            '${Platform.pathSeparator}$_dbDirectoryName';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  @override
  Future<Box<String>> openBox(String name, String? path) {
    return Hive.openBox<String>(name, path: path);
  }

  @override
  Future<void> deleteBox(String name, String? path) {
    return Hive.deleteBoxFromDisk(name, path: path);
  }
}

HealthStorageBackend createHealthStorageBackend() => _IoHealthStorageBackend();
