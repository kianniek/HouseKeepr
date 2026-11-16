import 'package:uuid/uuid.dart';

/// Base contract for all local-first HealthKeepr records.
///
/// Ensures every record stored in `health_keepr.db` carries the fields
/// required for future opt-in cloud synchronization without schema migrations.
abstract mixin class HealthRecordMetadata {
  static const Uuid _uuid = Uuid();

  /// Generates a new RFC 4122 UUID v4 string.
  static String generateId() => _uuid.v4();

  /// Returns the current UTC timestamp formatted as an ISO-8601 string.
  static String nowUtcIso() => DateTime.now().toUtc().toIso8601String();

  /// Unique record identifier (UUID v4).
  String get id;

  /// Last modification timestamp in UTC ISO-8601 format.
  String get updatedAt;

  /// Whether this record has been synchronized to a remote backend.
  bool get isSynced;

  /// Serializes the metadata fields into a JSON-compatible map.
  Map<String, dynamic> metadataToJson() => <String, dynamic>{
        'id': id,
        'updatedAt': updatedAt,
        'isSynced': isSynced,
      };
}
