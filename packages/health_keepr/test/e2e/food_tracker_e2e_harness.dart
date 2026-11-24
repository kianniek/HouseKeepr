import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';

/// Disk-backed temporary [LocalHealthDataStore] harness for Windows/VM E2E tests.
///
/// Passes a custom `storagePathProvider` so `path_provider` is never invoked,
/// supports closing and reopening the store on the same directory to verify true
/// persistence across restarts, and closes Hive handles before deleting temp
/// directories on Windows.
class TempHealthStoreHarness {
  TempHealthStoreHarness({String prefix = 'hk_food_e2e_'})
      : dir = Directory.systemTemp.createTempSync(prefix);

  final Directory dir;
  LocalHealthDataStore? _store;

  Future<LocalHealthDataStore> open() async {
    await _store?.close();
    final store = LocalHealthDataStore(
      storagePathProvider: () async => dir.path,
    );
    _store = store;
    return store;
  }

  Future<LocalHealthDataStore> reopen() => open();

  Future<void> dispose() async {
    await _store?.close();
    _store = null;
    for (var attempt = 0; attempt < 5; attempt++) {
      if (!dir.existsSync()) return;
      try {
        dir.deleteSync(recursive: true);
        return;
      } on PathAccessException {
        if (attempt < 4) {
          sleep(const Duration(milliseconds: 50));
        }
      }
    }
  }
}

/// Pure Dart in-memory [HealthDataStore] implementing the exact metadata and
/// defensive-copy contract of [LocalHealthDataStore] without `mocktail`.
class InMemoryHealthDataStore implements HealthDataStore {
  final Map<String, Map<String, Map<String, Map<String, dynamic>>>> _data =
      <String, Map<String, Map<String, Map<String, dynamic>>>>{};

  bool isClosed = false;

  Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
    final decoded = jsonDecode(jsonEncode(source));
    return Map<String, dynamic>.from(decoded as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> readCollection(
    String moduleId,
    String collection,
  ) async {
    final records = _data[moduleId]?[collection]?.values;
    if (records == null) {
      return <Map<String, dynamic>>[];
    }
    return records.map(_cloneMap).toList();
  }

  @override
  Future<Map<String, dynamic>?> readRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    final record = _data[moduleId]?[collection]?[id];
    if (record == null) {
      return null;
    }
    return _cloneMap(record);
  }

  @override
  Future<void> upsertRecord(
    String moduleId,
    String collection,
    Map<String, dynamic> record,
  ) async {
    final normalized = _cloneMap(record);
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

    final moduleCollections = _data.putIfAbsent(
      moduleId,
      () => <String, Map<String, Map<String, dynamic>>>{},
    );
    final records = moduleCollections.putIfAbsent(
      collection,
      () => <String, Map<String, dynamic>>{},
    );
    records[id] = normalized;
  }

  @override
  Future<void> deleteRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    _data[moduleId]?[collection]?.remove(id);
  }

  @override
  Future<void> clearModuleData(String moduleId) async {
    _data.remove(moduleId);
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }

  List<Map<String, dynamic>> dumpCollection(
    String moduleId,
    String collection,
  ) {
    final records = _data[moduleId]?[collection]?.values;
    if (records == null) {
      return const <Map<String, dynamic>>[];
    }
    return records.map(_cloneMap).toList();
  }

  int recordCount(String moduleId, String collection) {
    return _data[moduleId]?[collection]?.length ?? 0;
  }
}

/// Record fixtures & schema assertions matching `PROJECT.md § Interface Contracts #1`.
class FoodTrackerRecordFixtures {
  static const String moduleId = 'food_tracker';
  static const String mealLogsCollection = 'meal_logs';
  static const String settingsCollection = 'settings';
  static const String dailyGoalRecordId = 'daily_goal';
  static const String healthConnectSettingsRecordId = 'health_connect_settings';
  static const Set<String> validMealTypes = <String>{
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  };

  static String localBoundaryUtcIso({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    int second = 0,
  }) {
    return DateTime(year, month, day, hour, minute, second)
        .toUtc()
        .toIso8601String();
  }

  static Map<String, dynamic> mealLogRecord({
    String? id,
    String foodName = 'Margherita Pizza',
    String? foodId = 'pizza',
    String mealType = 'lunch',
    double servingGrams = 150.0,
    double kcal = 399.0,
    double proteinGrams = 17.1,
    double carbsGrams = 49.95,
    double fatGrams = 14.7,
    String? loggedAt,
    String? healthConnectId,
    String? updatedAt,
    bool isSynced = false,
  }) {
    return <String, dynamic>{
      'id': ?id,
      'foodName': foodName,
      'foodId': foodId,
      'mealType': mealType,
      'servingGrams': servingGrams,
      'kcal': kcal,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'loggedAt': loggedAt ?? HealthRecordMetadata.nowUtcIso(),
      'healthConnectId': healthConnectId,
      'updatedAt': ?updatedAt,
      'isSynced': isSynced,
    };
  }

  static Map<String, dynamic> dailyGoalSetting({
    double dailyKcalGoal = 2000.0,
    String? updatedAt,
    bool isSynced = false,
  }) {
    return <String, dynamic>{
      'id': dailyGoalRecordId,
      'dailyKcalGoal': dailyKcalGoal,
      'updatedAt': updatedAt ?? HealthRecordMetadata.nowUtcIso(),
      'isSynced': isSynced,
    };
  }

  static Map<String, dynamic> healthConnectSetting({
    bool enabled = false,
    String? updatedAt,
    bool isSynced = false,
  }) {
    return <String, dynamic>{
      'id': healthConnectSettingsRecordId,
      'enabled': enabled,
      'updatedAt': updatedAt ?? HealthRecordMetadata.nowUtcIso(),
      'isSynced': isSynced,
    };
  }

  static void expectValidMetadata(Map<String, dynamic> record) {
    expect(record['id'], isA<String>());
    expect((record['id'] as String).isNotEmpty, isTrue);
    expect(record['updatedAt'], isA<String>());
    final parsedUpdatedAt = DateTime.tryParse(record['updatedAt'] as String);
    expect(parsedUpdatedAt, isNotNull);
    expect(parsedUpdatedAt!.isUtc, isTrue);
    expect(record['isSynced'], isA<bool>());
  }

  static void expectValidMealLogSchema(Map<String, dynamic> record) {
    expectValidMetadata(record);
    expect(record['foodName'], isA<String>());
    expect((record['foodName'] as String).isNotEmpty, isTrue);
    expect(record['mealType'], isIn(validMealTypes));
    expect((record['servingGrams'] as num).toDouble(), greaterThan(0));
    expect((record['kcal'] as num).toDouble(), greaterThanOrEqualTo(0));
    expect((record['proteinGrams'] as num).toDouble(), greaterThanOrEqualTo(0));
    expect((record['carbsGrams'] as num).toDouble(), greaterThanOrEqualTo(0));
    expect((record['fatGrams'] as num).toDouble(), greaterThanOrEqualTo(0));
    expect(DateTime.tryParse(record['loggedAt'] as String), isNotNull);
  }
}

/// Fixtures & schema validator matching `PROJECT.md § Interface Contracts #2`.
class NutritionDatasetFixtures {
  static List<Map<String, dynamic>> sampleCatalogList() {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'pizza',
        'name': 'Pizza',
        'category': 'pizza',
        'aliases': <String>['cheese pizza', 'pepperoni pizza', 'margherita'],
        'kcalPer100g': 266.0,
        'proteinPer100g': 11.4,
        'carbsPer100g': 33.3,
        'fatPer100g': 9.8,
        'defaultServingGrams': 150.0,
        'servingLabel': '1 slice (150g)',
      },
      <String, dynamic>{
        'id': 'apple',
        'name': 'Apple',
        'category': 'fruit',
        'aliases': <String>['red apple', 'granny smith'],
        'kcalPer100g': 52.0,
        'proteinPer100g': 0.3,
        'carbsPer100g': 13.8,
        'fatPer100g': 0.2,
        'defaultServingGrams': 182.0,
        'servingLabel': '1 medium (182g)',
      },
      <String, dynamic>{
        'id': 'chicken_salad',
        'name': 'Chicken Salad',
        'category': 'salad',
        'aliases': <String>['caesar salad', 'grilled chicken salad'],
        'kcalPer100g': 142.0,
        'proteinPer100g': 15.5,
        'carbsPer100g': 5.2,
        'fatPer100g': 6.4,
        'defaultServingGrams': 250.0,
        'servingLabel': '1 bowl (250g)',
      },
      <String, dynamic>{
        'id': 'black_coffee',
        'name': 'Black Coffee',
        'category': 'beverage',
        'aliases': <String>['espresso', 'americano'],
        'kcalPer100g': 2.0,
        'proteinPer100g': 0.0,
        'carbsPer100g': 0.0,
        'fatPer100g': 0.0,
        'defaultServingGrams': 240.0,
        'servingLabel': '1 cup (240g)',
      },
      <String, dynamic>{
        'id': 'oatmeal_fallback',
        'name': 'Oatmeal',
        'category': 'breakfast',
        'aliases': <String>['porridge'],
        'kcalPer100g': 68.0,
        'protein': 2.4,
        'carbs': 12.0,
        'fat': 1.4,
        'defaultServingGrams': 240.0,
        'servingLabel': '1 bowl (240g)',
      },
    ];
  }

  static String sampleCatalogJson() => jsonEncode(sampleCatalogList());

  static String malformedCatalogJson() => jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'broken_item',
          'name': 'Broken Item',
          'kcalPer100g': -50.0,
          'defaultServingGrams': 0.0,
        },
      ]);

  /// Validates a JSON nutrition dataset against `PROJECT.md § Interface Contracts #2`.
  static List<Map<String, dynamic>> validateCatalogJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw const FormatException('Nutrition dataset root must be a JSON array.');
    }
    if (decoded.isEmpty) {
      throw const FormatException('Nutrition dataset must not be empty.');
    }

    final seenIds = <String>{};
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < decoded.length; i++) {
      final rawItem = decoded[i];
      if (rawItem is! Map) {
        throw FormatException('Entry at index $i is not a JSON object.');
      }
      final item = Map<String, dynamic>.from(rawItem);
      final id = item['id'];
      final name = item['name'];
      if (id is! String || id.trim().isEmpty) {
        throw FormatException('Entry at index $i missing non-empty id.');
      }
      if (!seenIds.add(id)) {
        throw FormatException('Duplicate food id "$id" at index $i.');
      }
      if (name is! String || name.trim().isEmpty) {
        throw FormatException('Entry "$id" missing non-empty name.');
      }

      _requireNonNegativeFinite(item['kcalPer100g'], 'kcalPer100g', id);
      final serving = _requireNonNegativeFinite(
        item['defaultServingGrams'],
        'defaultServingGrams',
        id,
      );
      if (serving <= 0) {
        throw FormatException(
          'Entry "$id" defaultServingGrams must be > 0 (got $serving).',
        );
      }

      _requireNonNegativeFinite(
        item['proteinPer100g'] ?? item['protein'],
        'proteinPer100g/protein',
        id,
      );
      _requireNonNegativeFinite(
        item['carbsPer100g'] ?? item['carbs'],
        'carbsPer100g/carbs',
        id,
      );
      _requireNonNegativeFinite(
        item['fatPer100g'] ?? item['fat'],
        'fatPer100g/fat',
        id,
      );

      result.add(item);
    }
    return result;
  }

  static double _requireNonNegativeFinite(
    Object? raw,
    String field,
    String id,
  ) {
    if (raw is! num) {
      throw FormatException('Entry "$id" missing numeric field "$field".');
    }
    final value = raw.toDouble();
    if (!value.isFinite || value < 0) {
      throw FormatException(
        'Entry "$id" has invalid "$field" value: $value.',
      );
    }
    return value;
  }
}

/// Pure Dart synthetic PNG byte fixtures (no `package:image` required in `health_keepr`).
class ImageByteFixtures {
  static const List<int> pngSignature = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];

  /// Encodes a genuine RGB PNG image using stored DEFLATE blocks so Flutter's
  /// image codec (`dart:ui`) decodes it without relying on `package:image`.
  static Uint8List validPngBytes({
    int width = 8,
    int height = 8,
    int r = 210,
    int g = 115,
    int b = 55,
  }) {
    RangeError.checkValueInInterval(width, 1, 2048, 'width');
    RangeError.checkValueInInterval(height, 1, 2048, 'height');

    final rowLength = 1 + width * 3;
    final raw = Uint8List(rowLength * height);
    for (var y = 0; y < height; y++) {
      final rowOffset = y * rowLength;
      raw[rowOffset] = 0; // Filter type 0 (None)
      for (var x = 0; x < width; x++) {
        final px = rowOffset + 1 + x * 3;
        raw[px] = r & 0xFF;
        raw[px + 1] = g & 0xFF;
        raw[px + 2] = b & 0xFF;
      }
    }

    final zlibStream = _encodeStoredZlib(raw);
    final ihdr = ByteData(13)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8) // bit depth
      ..setUint8(9, 2) // color type 2 = truecolor RGB
      ..setUint8(10, 0) // compression
      ..setUint8(11, 0) // filter
      ..setUint8(12, 0); // interlace

    final out = BytesBuilder(copy: false)
      ..add(pngSignature)
      ..add(_pngChunk('IHDR', ihdr.buffer.asUint8List()))
      ..add(_pngChunk('IDAT', zlibStream))
      ..add(_pngChunk('IEND', Uint8List(0)));
    return out.toBytes();
  }

  static Uint8List emptyBytes() => Uint8List(0);

  static Uint8List truncatedHeaderBytes() =>
      Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47]);

  static Uint8List corruptPngBytes() => Uint8List.fromList(<int>[
        ...pngSignature,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0xFF,
        0xFF,
        0xFF,
      ]);

  static Uint8List _encodeStoredZlib(Uint8List raw) {
    final builder = BytesBuilder(copy: false)
      ..add(<int>[0x78, 0x01]); // CMF=0x78, FLG=0x01 (30721 % 31 == 0)

    var offset = 0;
    const maxBlockSize = 65535;
    do {
      final remaining = raw.length - offset;
      final blockLen = remaining > maxBlockSize ? maxBlockSize : remaining;
      final isLast = offset + blockLen >= raw.length;
      builder.addByte(isLast ? 0x01 : 0x00);
      builder.addByte(blockLen & 0xFF);
      builder.addByte((blockLen >> 8) & 0xFF);
      final nlen = (~blockLen) & 0xFFFF;
      builder.addByte(nlen & 0xFF);
      builder.addByte((nlen >> 8) & 0xFF);
      if (blockLen > 0) {
        builder.add(Uint8List.sublistView(raw, offset, offset + blockLen));
      }
      offset += blockLen;
    } while (offset < raw.length);

    final adler = _adler32(raw);
    final adlerBytes = ByteData(4)..setUint32(0, adler);
    builder.add(adlerBytes.buffer.asUint8List());
    return builder.toBytes();
  }

  static Uint8List _pngChunk(String type, Uint8List data) {
    assert(type.length == 4);
    final typeBytes = ascii.encode(type);
    final crcInput = BytesBuilder(copy: false)
      ..add(typeBytes)
      ..add(data);
    final crc = _crc32(crcInput.toBytes());

    final lenData = ByteData(4)..setUint32(0, data.length);
    final crcData = ByteData(4)..setUint32(0, crc);
    final chunk = BytesBuilder(copy: false)
      ..add(lenData.buffer.asUint8List())
      ..add(typeBytes)
      ..add(data)
      ..add(crcData.buffer.asUint8List());
    return chunk.toBytes();
  }

  static int _adler32(Uint8List data) {
    const mod = 65521;
    var s1 = 1;
    var s2 = 0;
    for (final byte in data) {
      s1 = (s1 + byte) % mod;
      s2 = (s2 + s1) % mod;
    }
    return ((s2 << 16) | s1) & 0xFFFFFFFF;
  }

  static int _crc32(Uint8List data) {
    var crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc >>= 1;
        }
      }
    }
    return (~crc) & 0xFFFFFFFF;
  }
}

enum MockHcMode {
  available,
  providerUpdateRequired,
  unavailable,
  permissionsDeclined,
  writeFailure,
  missingPlugin,
  unsupportedSdk,
}

/// MethodChannel driver for `housekeepr/health_connect` validating the
/// `writeNutrition` payload contract in `PROJECT.md § Interface Contracts #4`.
class MockHealthConnectChannelDriver {
  static const MethodChannel channel = MethodChannel('housekeepr/health_connect');

  MockHcMode mode = MockHcMode.available;
  Set<String> grantedPermissions = <String>{'write_nutrition'};
  PlatformException? openSettingsException;
  final List<MethodCall> calls = <MethodCall>[];
  final List<List<String>> requestedPermissions = <List<String>>[];
  final List<Map<String, dynamic>> writtenNutritionCalls =
      <Map<String, dynamic>>[];
  bool settingsOpened = false;

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    if (mode == MockHcMode.missingPlugin) {
      messenger.setMockMethodCallHandler(channel, null);
      return;
    }
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (mode == MockHcMode.unsupportedSdk) {
        switch (call.method) {
          case 'getSdkStatus':
            return 'unavailable';
          case 'hasPermissions':
            return false;
          default:
            throw PlatformException(
              code: 'UNSUPPORTED_SDK',
              message: 'Health Connect requires Android 8.0 (API 26) or higher.',
            );
        }
      }

      switch (call.method) {
        case 'getSdkStatus':
          return switch (mode) {
            MockHcMode.available ||
            MockHcMode.permissionsDeclined ||
            MockHcMode.writeFailure =>
              'available',
            MockHcMode.providerUpdateRequired => 'providerUpdateRequired',
            MockHcMode.unavailable ||
            MockHcMode.missingPlugin ||
            MockHcMode.unsupportedSdk =>
              'unavailable',
          };
        case 'openHealthConnectSettings':
          if (openSettingsException != null) {
            throw openSettingsException!;
          }
          settingsOpened = true;
          return true;
        case 'hasPermissions':
          if (mode == MockHcMode.unavailable ||
              mode == MockHcMode.providerUpdateRequired) {
            return false;
          }
          if (mode == MockHcMode.permissionsDeclined) {
            return false;
          }
          final requested = _extractPermissions(call.arguments);
          if (requested.isEmpty) {
            return false;
          }
          return requested.every(grantedPermissions.contains);
        case 'requestPermissions':
          final requested = _extractPermissions(call.arguments);
          requestedPermissions.add(requested);
          if (mode == MockHcMode.unavailable ||
              mode == MockHcMode.providerUpdateRequired) {
            throw PlatformException(
              code: 'HC_UNAVAILABLE',
              message: 'Health Connect is not available.',
            );
          }
          final granted =
              mode == MockHcMode.available || mode == MockHcMode.writeFailure;
          if (granted) {
            grantedPermissions.addAll(requested);
          }
          return <String, dynamic>{
            'granted': granted,
            'grantedPermissions': granted ? requested : <String>[],
          };
        case 'writeNutrition':
          if (mode == MockHcMode.unavailable ||
              mode == MockHcMode.providerUpdateRequired) {
            throw PlatformException(
              code: 'HC_UNAVAILABLE',
              message: 'Health Connect is not available.',
            );
          }
          if (mode == MockHcMode.permissionsDeclined) {
            throw PlatformException(
              code: 'SECURITY_EXCEPTION',
              message: 'WRITE_NUTRITION permission not granted.',
            );
          }
          if (mode == MockHcMode.writeFailure) {
            throw PlatformException(
              code: 'WRITE_NUTRITION_FAILED',
              message: 'Simulated NutritionRecord write failure.',
            );
          }
          if (!grantedPermissions.contains('write_nutrition')) {
            throw PlatformException(
              code: 'SECURITY_EXCEPTION',
              message: 'WRITE_NUTRITION permission not granted.',
            );
          }
          final rawArgs = call.arguments;
          if (rawArgs is! Map) {
            throw PlatformException(
              code: 'INVALID_ARGS',
              message: 'writeNutrition requires a Map payload.',
            );
          }
          final args = Map<String, dynamic>.from(rawArgs);
          validateWriteNutritionPayload(args);
          writtenNutritionCalls.add(args);
          return 'hc_nutrition_${args['id']}';
        default:
          throw PlatformException(
            code: 'NOT_IMPLEMENTED',
            message: 'Method ${call.method} not implemented in mock driver.',
          );
      }
    });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }

  static List<String> _extractPermissions(Object? arguments) {
    if (arguments is! Map) {
      return const <String>[];
    }
    final raw = arguments['permissions'];
    if (raw is! List) {
      return const <String>[];
    }
    return raw.map((e) => e.toString()).toList();
  }

  static void validateWriteNutritionPayload(Map<String, dynamic> args) {
    final id = args['id'];
    final name = args['name'];
    final mealType = args['mealType'];
    final timeIso = args['timeIso'];
    if (id is! String || id.isEmpty) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'Missing non-empty id.',
      );
    }
    if (name is! String || name.trim().isEmpty) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'Missing non-empty name.',
      );
    }
    if (mealType is! String ||
        !FoodTrackerRecordFixtures.validMealTypes.contains(mealType)) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'Invalid mealType "$mealType".',
      );
    }
    if (timeIso is! String || DateTime.tryParse(timeIso) == null) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'Invalid ISO-8601 timeIso "$timeIso".',
      );
    }
    for (final key in const <String>[
      'kcal',
      'proteinGrams',
      'carbsGrams',
      'fatGrams',
    ]) {
      final value = args[key];
      if (value is! double || !value.isFinite || value < 0) {
        throw PlatformException(
          code: 'INVALID_ARGS',
          message: 'Invalid double field "$key": $value.',
        );
      }
    }
  }
}

Future<T> runWithTargetPlatform<T>(
  TargetPlatform platform,
  Future<T> Function() action,
) async {
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = platform;
  try {
    return await action();
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}

/// Widget harness for pumping [HealthKeeprHubScreen] with an isolated store,
/// optional platform override, and deterministic surface size.
///
/// Note: Flutter's `TestWidgetsFlutterBinding._verifyInvariants` asserts that
/// `debugDefaultTargetPlatformOverride` is reset *before* `addTearDown` runs,
/// so [runWithHub] wraps the entire test action in `try/finally`.
class HubScreenTestHarness {
  static Future<T> runWithHub<T>(
    WidgetTester tester, {
    required Future<T> Function() action,
    HealthDataStore? store,
    List<HealthMiniApp>? modules,
    TargetPlatform? platform,
    Size? surfaceSize,
  }) async {
    Future<T> runPumpAndAction() async {
      await pumpHub(
        tester,
        store: store,
        modules: modules,
        surfaceSize: surfaceSize,
      );
      return await action();
    }

    if (platform != null) {
      return await runWithTargetPlatform(platform, runPumpAndAction);
    }
    return await runPumpAndAction();
  }

  static Future<void> pumpHub(
    WidgetTester tester, {
    HealthDataStore? store,
    List<HealthMiniApp>? modules,
    Size? surfaceSize,
  }) async {
    if (surfaceSize != null) {
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }

    await tester.pumpWidget(
      MaterialApp(
        home: HealthKeeprHubScreen(
          store: store,
          modules: modules,
        ),
      ),
    );
    await tester.pump();
  }
}

// =============================================================================
// E2 Typed Adapter Extension Notes (Activated in Milestone E2 after M1-M3 land)
// =============================================================================
// Once M1-M3 export the Food Tracker contracts in `package:health_keepr/health_keepr.dart`,
// Milestone E2 will add typed adapters referencing these E1 primitives:
// 1. `FakeFoodClassifier implements FoodClassifier`:
//    - Uses `ImageByteFixtures` / non-empty checks, records `warmUpCalled`,
//      `disposed`, `classifiedByteLengths`, and returns deterministic
//      `List<FoodPrediction>` without loading native Android `.tflite` FFI on Windows.
// 2. `FakeNutritionHealthConnectGateway implements NutritionHealthConnectGateway`:
//    - Delegates directly to `MockHealthConnectChannelDriver` or simulates
//      gateway outcomes (`available`, `unavailable`, `permissionsDeclined`,
//      `writeFailure`) cleanly for `FoodTrackerLauncher` / `FoodTrackerScreen`.
// 3. `pumpFoodTracker(...)`:
//    - Calls `FoodTrackerLauncher.launch(...)` / `HealthKeeprHubScreen(
//        store: store,
//        foodPlateCropper: ...,
//        foodClassifier: ...,
//        foodImagePicker: ...,
//        nutritionHealthConnectGateway: ...,
//      )` for Tiers 1-4 tests covering F1, F4-F9.
