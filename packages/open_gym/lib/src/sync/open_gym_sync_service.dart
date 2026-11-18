import 'dart:convert';

import 'package:health_keepr/health_keepr.dart';

import '../models/server_connection.dart';
import 'open_gym_server_client.dart';

/// Result of a two-way sync pass against a connected self-hosted server.
class SyncResult {
  const SyncResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.syncedAt,
  });

  final int pushedCount;
  final int pulledCount;
  final String syncedAt;
}

/// Handles local JSON export/import and optional two-way server sync.
class OpenGymSyncService {
  OpenGymSyncService({
    required HealthDataStore store,
    OpenGymServerClient? client,
  })  : _store = store,
        _client = client ?? OpenGymServerClient();

  static const String moduleId = 'open_gym';
  static const List<String> syncableCollections = <String>[
    'workouts',
    'templates',
    'exercises',
    'weigh_ins',
    'measurements',
    'programmes',
  ];

  final HealthDataStore _store;
  final OpenGymServerClient _client;

  /// Exports all local OpenGym collections as a portable JSON string.
  Future<String> exportBackupJson() async {
    final dump = <String, dynamic>{
      'format': 'open_gym_flutter_backup_v1',
      'exportedAt': HealthRecordMetadata.nowUtcIso(),
      'collections': <String, dynamic>{},
    };
    final collections = dump['collections'] as Map<String, dynamic>;
    for (final col in syncableCollections) {
      collections[col] = await _store.readCollection(moduleId, col);
    }
    return const JsonEncoder.withIndent('  ').convert(dump);
  }

  /// Restores records from a JSON backup using last-write-wins on `updatedAt`.
  Future<int> importBackupJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Invalid backup JSON');
    }
    final collections = decoded['collections'];
    if (collections is! Map) {
      throw const FormatException('Missing collections in backup JSON');
    }

    int imported = 0;
    for (final col in syncableCollections) {
      final list = collections[col];
      if (list is! List) continue;
      for (final item in list) {
        if (item is Map) {
          await _mergeRecord(col, Map<String, dynamic>.from(item), markSynced: false);
          imported++;
        }
      }
    }
    return imported;
  }

  /// Pushes unsynced local records (`isSynced == false`) and pulls remote updates.
  Future<SyncResult> syncWithServer(ServerConnectionConfig config) async {
    final unsyncedPayload = <String, List<Map<String, dynamic>>>{};
    int pushedCount = 0;

    for (final col in syncableCollections) {
      final records = await _store.readCollection(moduleId, col);
      final unsynced = records
          .where((r) => r['isSynced'] != true)
          .toList();
      if (unsynced.isNotEmpty) {
        unsyncedPayload[col] = unsynced;
        pushedCount += unsynced.length;
      }
    }

    if (pushedCount > 0) {
      await _client.pushSync(config, <String, dynamic>{
        'collections': unsyncedPayload,
      });
      for (final entry in unsyncedPayload.entries) {
        for (final record in entry.value) {
          final updated = Map<String, dynamic>.from(record)
            ..['isSynced'] = true;
          await _store.upsertRecord(moduleId, entry.key, updated);
        }
      }
    }

    final remote = await _client.pullSync(config, since: config.lastSyncedAt);
    int pulledCount = 0;
    final remoteCollections = remote['collections'];
    if (remoteCollections is Map) {
      for (final col in syncableCollections) {
        final list = remoteCollections[col];
        if (list is! List) continue;
        for (final item in list) {
          if (item is Map) {
            final merged = await _mergeRecord(
              col,
              Map<String, dynamic>.from(item),
              markSynced: true,
            );
            if (merged) pulledCount++;
          }
        }
      }
    }

    return SyncResult(
      pushedCount: pushedCount,
      pulledCount: pulledCount,
      syncedAt: HealthRecordMetadata.nowUtcIso(),
    );
  }

  Future<bool> _mergeRecord(
    String collection,
    Map<String, dynamic> incoming, {
    required bool markSynced,
  }) async {
    final id = incoming['id'] as String?;
    if (id == null || id.isEmpty) return false;
    final existing = await _store.readRecord(moduleId, collection, id);
    if (existing != null) {
      final localTs = DateTime.tryParse(existing['updatedAt'] as String? ?? '');
      final remoteTs = DateTime.tryParse(incoming['updatedAt'] as String? ?? '');
      if (localTs != null && remoteTs != null && !remoteTs.isAfter(localTs)) {
        return false;
      }
    }
    final toSave = Map<String, dynamic>.from(incoming)
      ..['isSynced'] = markSynced;
    await _store.upsertRecord(moduleId, collection, toSave);
    return true;
  }
}
