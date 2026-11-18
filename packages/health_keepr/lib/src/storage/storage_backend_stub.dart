import 'package:hive/hive.dart';

/// Platform-agnostic handle for opening and deleting isolated Hive boxes.
abstract class HealthStorageBackend {
  Future<String?> init({String? customPath});
  Future<Box<String>> openBox(String name, String? path);
  Future<void> deleteBox(String name, String? path);
}

HealthStorageBackend createHealthStorageBackend() =>
    throw UnsupportedError('No HealthStorageBackend implementation found.');
