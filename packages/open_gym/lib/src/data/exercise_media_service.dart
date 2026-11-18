import 'dart:convert';
import 'dart:typed_data';

import 'package:health_keepr/health_keepr.dart';
import 'package:http/http.dart' as http;

/// Resolves and locally caches exercise stills (`.webp`) and animation URLs (`.mp4`).
///
/// Uses the connected self-hosted server if configured, otherwise falls back to
/// the public `DuarteSantos8/openGym` media repository. Cached stills are
/// stored in `health_keepr.db` so they remain available offline on Android & Web.
class ExerciseMediaService {
  ExerciseMediaService({
    required HealthDataStore store,
    http.Client? httpClient,
  })  : _store = store,
        _client = httpClient ?? http.Client();

  static const String moduleId = 'open_gym';
  static const String _cacheCollection = 'media_cache';
  static const String _publicMediaBase =
      'https://raw.githubusercontent.com/DuarteSantos8/openGym/main/catalogue/media';

  final HealthDataStore _store;
  final http.Client _client;
  final Map<String, Uint8List> _memoryStillCache = <String, Uint8List>{};

  /// Returns the `.webp` still URL for [exerciseId].
  static String stillUrlFor(String exerciseId, {String? serverUrl}) {
    if (serverUrl != null && serverUrl.trim().isNotEmpty) {
      final base = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
      return '$base/exercise-media/still/$exerciseId.webp';
    }
    return '$_publicMediaBase/still/$exerciseId.webp';
  }

  /// Returns the looping `.mp4` animation clip URL for [exerciseId].
  static String clipUrlFor(String exerciseId, {String? serverUrl}) {
    if (serverUrl != null && serverUrl.trim().isNotEmpty) {
      final base = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
      return '$base/exercise-media/clip/$exerciseId.mp4';
    }
    return '$_publicMediaBase/clip/$exerciseId.mp4';
  }

  /// Loads the `.webp` still bytes from local cache, or fetches & caches them.
  ///
  /// Returns `null` if offline and not yet cached, or if the exercise has no
  /// matching media (e.g. custom user exercises).
  Future<Uint8List?> loadStillBytes(
    String exerciseId, {
    String? serverUrl,
  }) async {
    final mem = _memoryStillCache[exerciseId];
    if (mem != null) return mem;

    final cacheKey = 'still_$exerciseId';
    try {
      final cached = await _store.readRecord(
        moduleId,
        _cacheCollection,
        cacheKey,
      );
      final b64 = cached?['data'] as String?;
      if (b64 != null && b64.isNotEmpty) {
        final bytes = base64Decode(b64);
        _memoryStillCache[exerciseId] = bytes;
        return bytes;
      }
    } catch (_) {
      // Ignore cache read failures and attempt network fetch.
    }

    try {
      final uri = Uri.parse(stillUrlFor(exerciseId, serverUrl: serverUrl));
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300 && res.bodyBytes.isNotEmpty) {
        final bytes = res.bodyBytes;
        _memoryStillCache[exerciseId] = bytes;
        await _store.upsertRecord(moduleId, _cacheCollection, <String, dynamic>{
          'id': cacheKey,
          'data': base64Encode(bytes),
        });
        return bytes;
      }
    } catch (_) {
      // Offline or unreachable.
    }
    return null;
  }
}
