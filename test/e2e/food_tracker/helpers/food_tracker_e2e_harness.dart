import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';
import 'package:housekeepr/ui/common/widgets/simple_cropper.dart';
import 'package:housekeepr/ui/features/tools/pages/tools_library_page.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

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

void _deleteDirWithSyncRetry(Directory dir) {
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

/// Installs a mock for `plugins.flutter.io/path_provider` pointing to [rootDir]
/// so navigating into `HealthKeeprHubScreen()` (which lazily constructs
/// `LocalHealthDataStore()`) works on Windows `flutter test` without plugins.
Directory installPathProviderMock([Directory? rootDir]) {
  final dir = rootDir ?? Directory.systemTemp.createTempSync('hk_root_pp_');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'getApplicationDocumentsDirectory':
      case 'getTemporaryDirectory':
      case 'getApplicationSupportDirectory':
      case 'getLibraryDirectory':
        return dir.path;
      default:
        return dir.path;
    }
  });

  addTearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    if (rootDir == null) {
      _deleteDirWithSyncRetry(dir);
    }
  });

  return dir;
}

class RecordedShortcutsChannel {
  final List<MethodCall> calls = <MethodCall>[];
}

/// Installs a mock for `housekeepr/shortcuts` used by [ToolsLibraryPage] on Android.
RecordedShortcutsChannel installShortcutsChannelMock({bool canPin = true}) {
  const channel = MethodChannel('housekeepr/shortcuts');
  final recorded = RecordedShortcutsChannel();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(channel, (call) async {
    recorded.calls.add(call);
    switch (call.method) {
      case 'canPinShortcuts':
        return canPin;
      case 'pinShortcut':
        return true;
      default:
        return null;
    }
  });

  addTearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  return recorded;
}

enum FakeHealthConnectMode {
  available,
  providerUpdateRequired,
  unavailable,
  permissionsDeclined,
  writeFailure,
  missingPlugin,
  unsupportedSdk,
}

/// MethodChannel fake for `housekeepr/health_connect` on the root app side.
class FakeHealthConnectChannel {
  static const MethodChannel channel = MethodChannel('housekeepr/health_connect');
  static const Set<String> validMealTypes = <String>{
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  };

  FakeHealthConnectMode mode = FakeHealthConnectMode.available;
  Set<String> grantedPermissions = <String>{'write_nutrition'};
  PlatformException? openSettingsException;
  final List<MethodCall> calls = <MethodCall>[];
  final List<Map<String, dynamic>> writtenNutritionPayloads =
      <Map<String, dynamic>>[];
  bool settingsOpened = false;

  void install({bool registerTearDown = true}) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    if (mode == FakeHealthConnectMode.missingPlugin) {
      messenger.setMockMethodCallHandler(channel, null);
    } else {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (mode == FakeHealthConnectMode.unsupportedSdk) {
          switch (call.method) {
            case 'getSdkStatus':
              return 'unavailable';
            case 'hasPermissions':
              return false;
            default:
              throw PlatformException(
                code: 'UNSUPPORTED_SDK',
                message: 'Health Connect requires Android 8.0 (API 26).',
              );
          }
        }

        switch (call.method) {
          case 'getSdkStatus':
            return switch (mode) {
              FakeHealthConnectMode.available ||
              FakeHealthConnectMode.permissionsDeclined ||
              FakeHealthConnectMode.writeFailure =>
                'available',
              FakeHealthConnectMode.providerUpdateRequired =>
                'providerUpdateRequired',
              FakeHealthConnectMode.unavailable ||
              FakeHealthConnectMode.missingPlugin ||
              FakeHealthConnectMode.unsupportedSdk =>
                'unavailable',
            };
          case 'openHealthConnectSettings':
            if (openSettingsException != null) {
              throw openSettingsException!;
            }
            settingsOpened = true;
            return true;
          case 'hasPermissions':
            if (mode == FakeHealthConnectMode.unavailable ||
                mode == FakeHealthConnectMode.providerUpdateRequired ||
                mode == FakeHealthConnectMode.permissionsDeclined) {
              return false;
            }
            final requested = _extractPermissions(call.arguments);
            if (requested.isEmpty) {
              return false;
            }
            return requested.every(grantedPermissions.contains);
          case 'requestPermissions':
            final requested = _extractPermissions(call.arguments);
            if (mode == FakeHealthConnectMode.unavailable ||
                mode == FakeHealthConnectMode.providerUpdateRequired) {
              throw PlatformException(
                code: 'HC_UNAVAILABLE',
                message: 'Health Connect is not available.',
              );
            }
            final granted = mode == FakeHealthConnectMode.available ||
                mode == FakeHealthConnectMode.writeFailure;
            if (granted) {
              grantedPermissions.addAll(requested);
            }
            return <String, dynamic>{
              'granted': granted,
              'grantedPermissions': granted ? requested : <String>[],
            };
          case 'writeNutrition':
            if (mode == FakeHealthConnectMode.unavailable ||
                mode == FakeHealthConnectMode.providerUpdateRequired) {
              throw PlatformException(
                code: 'HC_UNAVAILABLE',
                message: 'Health Connect is not available.',
              );
            }
            if (mode == FakeHealthConnectMode.permissionsDeclined) {
              throw PlatformException(
                code: 'SECURITY_EXCEPTION',
                message: 'WRITE_NUTRITION permission declined.',
              );
            }
            if (mode == FakeHealthConnectMode.writeFailure) {
              throw PlatformException(
                code: 'WRITE_NUTRITION_FAILED',
                message: 'Simulated write error.',
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
            final payload = Map<String, dynamic>.from(rawArgs);
            _validateNutritionPayload(payload);
            writtenNutritionPayloads.add(payload);
            return 'hc_nutrition_${payload['id']}';
          default:
            return null;
        }
      });
    }

    if (registerTearDown) {
      addTearDown(uninstall);
    }
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

  static void _validateNutritionPayload(Map<String, dynamic> args) {
    final id = args['id'];
    final name = args['name'];
    final mealType = args['mealType'];
    final timeIso = args['timeIso'];
    if (id is! String || id.isEmpty) {
      throw PlatformException(code: 'INVALID_ARGS', message: 'Invalid id');
    }
    if (name is! String || name.trim().isEmpty) {
      throw PlatformException(code: 'INVALID_ARGS', message: 'Invalid name');
    }
    if (mealType is! String || !validMealTypes.contains(mealType)) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'Invalid mealType: $mealType',
      );
    }
    if (timeIso is! String || DateTime.tryParse(timeIso) == null) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'Invalid timeIso: $timeIso',
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
          message: 'Invalid $key (expected finite non-negative double): $value',
        );
      }
    }
  }
}

/// Generates a real PNG file simulating a plate of food on disk using `package:image`
/// and registers cleanup with `addTearDown`.
File createTempPlatePng({int width = 128, int height = 128}) {
  final dir = Directory.systemTemp.createTempSync('hk_plate_png_');
  final file = File('${dir.path}${Platform.pathSeparator}plate.png');

  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(242, 236, 224));
  img.fillCircle(
    image,
    x: width ~/ 2,
    y: height ~/ 2,
    radius: (width < height ? width : height) ~/ 3,
    color: img.ColorRgb8(214, 92, 48),
  );
  img.fillCircle(
    image,
    x: width ~/ 2 - width ~/ 10,
    y: height ~/ 2 - height ~/ 12,
    radius: (width < height ? width : height) ~/ 8,
    color: img.ColorRgb8(76, 158, 70),
  );

  file.writeAsBytesSync(img.encodePng(image), flush: true);

  addTearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _deleteDirWithSyncRetry(dir);
  });

  return file;
}

Future<void> _waitForCropperImageDecode(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final hasLoaded = tester
        .widgetList<RawImage>(find.byType(RawImage))
        .any((raw) => raw.image != null);
    if (hasLoaded) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

/// Pushes [SimpleCropper], lets `Image.file` decode inside `tester.runAsync`,
/// optionally taps rotation buttons, confirms with the check FAB, and awaits
/// `RenderRepaintBoundary.toImage()` + PNG serialization.
Future<Uint8List?> pumpSimpleCropperAndConfirm(
  WidgetTester tester, {
  required String imagePath,
  int rotateRightTaps = 0,
  int rotateLeftTaps = 0,
}) async {
  Uint8List? croppedResult;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                croppedResult = await Navigator.of(context).push<Uint8List>(
                  MaterialPageRoute<Uint8List>(
                    builder: (_) => SimpleCropper(imagePath: imagePath),
                  ),
                );
              },
              child: const Text('Open Cropper'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.text('Open Cropper'));
  await tester.pumpAndSettle();

  // Wait for FileImage decode using bounded polling instead of fixed delay.
  await _waitForCropperImageDecode(tester);

  for (var i = 0; i < rotateRightTaps; i++) {
    await tester.tap(find.byIcon(Icons.rotate_right));
    await tester.pump();
  }
  for (var i = 0; i < rotateLeftTaps; i++) {
    await tester.tap(find.byIcon(Icons.rotate_left));
    await tester.pump();
  }

  await tester.tap(find.byIcon(Icons.check));
  await tester.pump();
  await tester.runAsync(() async {
    final deadline = Stopwatch()..start();
    while (croppedResult == null &&
        deadline.elapsed < const Duration(seconds: 3)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pumpAndSettle();

  // Release FileImage handles so temp PNG cleanup succeeds on Windows.
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  return croppedResult;
}

/// Pushes [SimpleCropper], lets `Image.file` decode, cancels via the AppBar
/// Back button, unmounts cleanly, and returns `null`.
Future<Uint8List?> pumpSimpleCropperAndCancel(
  WidgetTester tester, {
  required String imagePath,
}) async {
  var popped = false;
  Uint8List? croppedResult;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                croppedResult = await Navigator.of(context).push<Uint8List>(
                  MaterialPageRoute<Uint8List>(
                    builder: (_) => SimpleCropper(imagePath: imagePath),
                  ),
                );
                popped = true;
              },
              child: const Text('Open Cropper'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.text('Open Cropper'));
  await tester.pumpAndSettle();

  await _waitForCropperImageDecode(tester);

  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  expect(popped, isTrue);

  // Release FileImage handles so temp PNG cleanup succeeds on Windows.
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  return croppedResult;
}

/// Pumps [ToolsLibraryPage] with mocked preferences.
///
/// Callers needing platform overrides should wrap the call in
/// [runWithTargetPlatform] so `debugDefaultTargetPlatformOverride` is restored
/// before `TestWidgetsFlutterBinding._verifyInvariants` runs.
Future<void> pumpToolsLibraryPage(
  WidgetTester tester, {
  Map<String, Object> initialPrefs = const <String, Object>{},
  String? householdId,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);

  await tester.pumpWidget(
    MaterialApp(home: ToolsLibraryPage(householdId: householdId)),
  );
  await tester.pump();
}

/// Unmounts [ToolsLibraryPage] and flushes `Marquee`'s 3-second `startAfter` timers.
Future<void> disposeToolsLibraryPage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
}

/// Pure Dart in-memory [HealthDataStore] matching `LocalHealthDataStore` semantics.
class InMemoryHealthDataStore implements HealthDataStore {
  final Map<String, Map<String, Map<String, Map<String, dynamic>>>> _data =
      <String, Map<String, Map<String, Map<String, dynamic>>>>{};

  bool isClosed = false;

  Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);
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
    return record == null ? null : _cloneMap(record);
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

    final collections = _data.putIfAbsent(
      moduleId,
      () => <String, Map<String, Map<String, dynamic>>>{},
    );
    final records = collections.putIfAbsent(
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
}
