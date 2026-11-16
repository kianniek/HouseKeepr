/// Namespaced local-first storage contract for HealthKeepr mini-apps.
///
/// All data is stored strictly on-device, isolated from HouseKeepr's
/// household/Firebase storage.
abstract class HealthDataStore {
  /// Reads all records in [collection] for [moduleId].
  Future<List<Map<String, dynamic>>> readCollection(
    String moduleId,
    String collection,
  );

  /// Reads a single record by [id] in [collection] for [moduleId], or `null`.
  Future<Map<String, dynamic>?> readRecord(
    String moduleId,
    String collection,
    String id,
  );

  /// Inserts or updates [record] in [collection] for [moduleId].
  ///
  /// Implementations must ensure `id` (UUID v4), `updatedAt` (UTC ISO-8601),
  /// and `isSynced` (`bool`, default `false`) are populated on the stored map.
  Future<void> upsertRecord(
    String moduleId,
    String collection,
    Map<String, dynamic> record,
  );

  /// Deletes the record with [id] from [collection] for [moduleId].
  Future<void> deleteRecord(
    String moduleId,
    String collection,
    String id,
  );

  /// Deletes all locally stored collections and records for [moduleId].
  Future<void> clearModuleData(String moduleId);

  /// Releases any open database handles.
  Future<void> close();
}
