import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';
import 'package:open_gym/open_gym.dart';

class _InMemoryHealthDataStore implements HealthDataStore {
  final Map<String, Map<String, Map<String, dynamic>>> _data =
      <String, Map<String, Map<String, dynamic>>>{};

  Map<String, Map<String, dynamic>> _col(String moduleId, String collection) =>
      _data.putIfAbsent('$moduleId::$collection', () => <String, Map<String, dynamic>>{});

  @override
  Future<void> clearModuleData(String moduleId) async {
    _data.removeWhere((key, _) => key.startsWith('$moduleId::'));
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteRecord(String moduleId, String collection, String id) async {
    _col(moduleId, collection).remove(id);
  }

  @override
  Future<List<Map<String, dynamic>>> readCollection(
    String moduleId,
    String collection,
  ) async {
    return _col(moduleId, collection).values.toList();
  }

  @override
  Future<Map<String, dynamic>?> readRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    return _col(moduleId, collection)[id];
  }

  @override
  Future<void> upsertRecord(
    String moduleId,
    String collection,
    Map<String, dynamic> record,
  ) async {
    final copy = Map<String, dynamic>.from(record);
    final id = (copy['id'] as String?) ?? HealthRecordMetadata.generateId();
    copy['id'] = id;
    copy['updatedAt'] ??= HealthRecordMetadata.nowUtcIso();
    copy['isSynced'] ??= false;
    _col(moduleId, collection)[id] = copy;
  }
}

class _FakeHealthConnectGateway implements HealthConnectGateway {
  HealthConnectSdkStatus status = HealthConnectSdkStatus.available;
  bool permissionsGranted = true;

  final List<Map<String, dynamic>> writtenExercises = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> writtenWeights = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> writtenBodyFats = <Map<String, dynamic>>[];
  HealthConnectRawData rawDataToReturn = const HealthConnectRawData();

  @override
  Future<HealthConnectSdkStatus> getSdkStatus() async => status;

  @override
  Future<bool> hasPermissions(List<String> permissions) async =>
      permissionsGranted;

  @override
  Future<void> openHealthConnectSettings() async {}

  @override
  Future<HealthConnectRawData> readRecords({
    required String startIso,
    required String endIso,
  }) async =>
      rawDataToReturn;

  @override
  Future<bool> requestPermissions(List<String> permissions) async =>
      permissionsGranted;

  @override
  Future<String?> writeBodyFat({
    required String id,
    required double percentage,
    required String timeIso,
  }) async {
    writtenBodyFats.add(<String, dynamic>{
      'id': id,
      'percentage': percentage,
      'timeIso': timeIso,
    });
    return 'hc_bf_$id';
  }

  @override
  Future<String?> writeExerciseSession({
    required String id,
    required String title,
    required String startIso,
    required String endIso,
    String? notes,
  }) async {
    writtenExercises.add(<String, dynamic>{
      'id': id,
      'title': title,
      'startIso': startIso,
      'endIso': endIso,
      'notes': notes,
    });
    return 'hc_ex_$id';
  }

  @override
  Future<String?> writeWeight({
    required String id,
    required double weightKg,
    required String timeIso,
  }) async {
    writtenWeights.add(<String, dynamic>{
      'id': id,
      'weightKg': weightKg,
      'timeIso': timeIso,
    });
    return 'hc_w_$id';
  }
}

void main() {
  late _InMemoryHealthDataStore store;
  late _FakeHealthConnectGateway gateway;
  late OpenGymController controller;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    store = _InMemoryHealthDataStore();
    gateway = _FakeHealthConnectGateway();
    controller = OpenGymController(
      store: store,
      healthConnectService: HealthConnectService(gateway: gateway),
    );
    await controller.initialize();
  });

  tearDown(() {
    controller.dispose();
  });

  test('finishWorkout writes ExerciseSessionRecord when Health Connect is enabled',
      () async {
    final granted = await controller.connectHealthConnect();
    expect(granted, isTrue);
    expect(controller.healthConnectSettings.enabled, isTrue);

    controller.startEmptyWorkout(title: 'Push Day');
    final finished = await controller.finishWorkout();
    expect(finished, isNotNull);

    // Wait for unawaited Health Connect write to complete.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(gateway.writtenExercises, hasLength(1));
    expect(gateway.writtenExercises.first['title'], 'Push Day');
    expect(controller.history.first.healthConnectId, 'hc_ex_${finished!.id}');
  });

  test('saveWeighIn and saveMeasurement write WeightRecord and BodyFatRecord',
      () async {
    await controller.connectHealthConnect();

    final weighIn = WeighIn.create(date: '2026-11-17', weightKg: 81.4);
    await controller.saveWeighIn(weighIn);

    final measurement = BodyMeasurement.create(
      date: '2026-11-17',
      bodyFatPct: 14.8,
    );
    await controller.saveMeasurement(measurement);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(gateway.writtenWeights, hasLength(1));
    expect(gateway.writtenWeights.first['weightKg'], 81.4);
    expect(gateway.writtenBodyFats, hasLength(1));
    expect(gateway.writtenBodyFats.first['percentage'], 14.8);
  });

  test('syncHealthConnect imports weight, body fat, external workouts, calories & HR',
      () async {
    await controller.connectHealthConnect();

    gateway.rawDataToReturn = const HealthConnectRawData(
      weights: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'ext_w_1',
          'weightKg': 79.5,
          'timeIso': '2026-11-16T08:00:00Z',
        },
      ],
      bodyFats: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'ext_bf_1',
          'percentage': 15.2,
          'timeIso': '2026-11-16T08:00:00Z',
        },
      ],
      exercises: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'own_ex_1',
          'title': 'OpenGym Session',
          'exerciseType': 70,
          'startIso': '2026-11-16T10:00:00Z',
          'endIso': '2026-11-16T11:00:00Z',
          'sourcePackage': 'com.kianhamidi.housekeepr',
          'isExternal': false,
        },
        <String, dynamic>{
          'id': 'ext_run_1',
          'title': 'Morning Run',
          'exerciseType': 56,
          'startIso': '2026-11-16T07:00:00Z',
          'endIso': '2026-11-16T07:35:00Z',
          'sourcePackage': 'com.strava',
          'isExternal': true,
        },
      ],
      activeCalories: <Map<String, dynamic>>[
        <String, dynamic>{
          'kcal': 380.0,
          'startIso': '2026-11-16T07:00:00Z',
          'endIso': '2026-11-16T07:35:00Z',
        },
      ],
      heartRateSamples: <Map<String, dynamic>>[
        <String, dynamic>{
          'bpm': 142,
          'timeIso': '2026-11-16T07:10:00Z',
        },
        <String, dynamic>{
          'bpm': 164,
          'timeIso': '2026-11-16T07:25:00Z',
        },
      ],
    );

    final result = await controller.syncHealthConnect();
    expect(result, isNotNull);
    expect(result!.importedWeighIns, 1);
    expect(result.importedBodyFats, 1);
    expect(result.externalWorkouts, 1);

    expect(controller.weighIns, hasLength(1));
    expect(controller.weighIns.first.weightKg, 79.5);
    expect(controller.weighIns.first.source, 'health_connect');

    expect(controller.measurements, hasLength(1));
    expect(controller.measurements.first.bodyFatPct, 15.2);

    expect(controller.externalWorkouts, hasLength(1));
    expect(controller.externalWorkouts.first.title, 'Morning Run');
    expect(controller.externalWorkouts.first.caloriesKcal, 380.0);
    expect(controller.externalWorkouts.first.avgHeartRateBpm, 153);
    expect(controller.externalWorkouts.first.maxHeartRateBpm, 164);

    expect(controller.dailyHealthMetrics, hasLength(1));
    expect(controller.dailyHealthMetrics.first.activeCaloriesKcal, 380.0);
    expect(controller.dailyHealthMetrics.first.avgHeartRateBpm, 153);

    // Re-syncing should not duplicate weigh-ins or body fat entries.
    final second = await controller.syncHealthConnect();
    expect(second!.importedWeighIns, 0);
    expect(second.importedBodyFats, 0);
    expect(controller.weighIns, hasLength(1));
  });
}
