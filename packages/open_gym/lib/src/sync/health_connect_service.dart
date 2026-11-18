import 'package:flutter/services.dart';
import 'package:health_keepr/health_keepr.dart';

import '../models/body_measurement.dart';
import '../models/health_connect_models.dart';
import '../models/weigh_in.dart';
import '../models/workout_log.dart';

/// Raw records returned from the platform Health Connect bridge.
class HealthConnectRawData {
  const HealthConnectRawData({
    this.exercises = const <Map<String, dynamic>>[],
    this.weights = const <Map<String, dynamic>>[],
    this.bodyFats = const <Map<String, dynamic>>[],
    this.activeCalories = const <Map<String, dynamic>>[],
    this.totalCalories = const <Map<String, dynamic>>[],
    this.heartRateSamples = const <Map<String, dynamic>>[],
  });

  factory HealthConnectRawData.fromMap(Map<dynamic, dynamic> map) {
    List<Map<String, dynamic>> castList(dynamic raw) {
      if (raw is! List) return const <Map<String, dynamic>>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return HealthConnectRawData(
      exercises: castList(map['exercises']),
      weights: castList(map['weights']),
      bodyFats: castList(map['bodyFats']),
      activeCalories: castList(map['activeCalories']),
      totalCalories: castList(map['totalCalories']),
      heartRateSamples: castList(map['heartRateSamples']),
    );
  }

  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> weights;
  final List<Map<String, dynamic>> bodyFats;
  final List<Map<String, dynamic>> activeCalories;
  final List<Map<String, dynamic>> totalCalories;
  final List<Map<String, dynamic>> heartRateSamples;
}

/// Platform abstraction for Android Health Connect operations.
abstract class HealthConnectGateway {
  Future<HealthConnectSdkStatus> getSdkStatus();
  Future<void> openHealthConnectSettings();
  Future<bool> hasPermissions(List<String> permissions);
  Future<bool> requestPermissions(List<String> permissions);
  Future<String?> writeExerciseSession({
    required String id,
    required String title,
    required String startIso,
    required String endIso,
    String? notes,
  });
  Future<String?> writeWeight({
    required String id,
    required double weightKg,
    required String timeIso,
  });
  Future<String?> writeBodyFat({
    required String id,
    required double percentage,
    required String timeIso,
  });
  Future<HealthConnectRawData> readRecords({
    required String startIso,
    required String endIso,
  });
}

/// Default [HealthConnectGateway] backed by the `housekeepr/health_connect` channel.
class MethodChannelHealthConnectGateway implements HealthConnectGateway {
  MethodChannelHealthConnectGateway({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('housekeepr/health_connect');

  final MethodChannel _channel;

  @override
  Future<HealthConnectSdkStatus> getSdkStatus() async {
    try {
      final raw = await _channel.invokeMethod<String>('getSdkStatus');
      return switch (raw) {
        'available' => HealthConnectSdkStatus.available,
        'providerUpdateRequired' => HealthConnectSdkStatus.providerUpdateRequired,
        _ => HealthConnectSdkStatus.unavailable,
      };
    } on MissingPluginException {
      return HealthConnectSdkStatus.unavailable;
    } on PlatformException {
      return HealthConnectSdkStatus.unavailable;
    }
  }

  @override
  Future<void> openHealthConnectSettings() async {
    try {
      await _channel.invokeMethod<bool>('openHealthConnectSettings');
    } on MissingPluginException {
      // No-op on non-Android platforms.
    }
  }

  @override
  Future<bool> hasPermissions(List<String> permissions) async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'hasPermissions',
        <String, dynamic>{'permissions': permissions},
      );
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions(List<String> permissions) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'requestPermissions',
        <String, dynamic>{'permissions': permissions},
      );
      return (res?['granted'] as bool?) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String?> writeExerciseSession({
    required String id,
    required String title,
    required String startIso,
    required String endIso,
    String? notes,
  }) async {
    return _channel.invokeMethod<String>(
      'writeExerciseSession',
      <String, dynamic>{
        'id': id,
        'title': title,
        'startIso': startIso,
        'endIso': endIso,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  @override
  Future<String?> writeWeight({
    required String id,
    required double weightKg,
    required String timeIso,
  }) async {
    return _channel.invokeMethod<String>(
      'writeWeight',
      <String, dynamic>{
        'id': id,
        'weightKg': weightKg,
        'timeIso': timeIso,
      },
    );
  }

  @override
  Future<String?> writeBodyFat({
    required String id,
    required double percentage,
    required String timeIso,
  }) async {
    return _channel.invokeMethod<String>(
      'writeBodyFat',
      <String, dynamic>{
        'id': id,
        'percentage': percentage,
        'timeIso': timeIso,
      },
    );
  }

  @override
  Future<HealthConnectRawData> readRecords({
    required String startIso,
    required String endIso,
  }) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'readRecords',
      <String, dynamic>{
        'startIso': startIso,
        'endIso': endIso,
      },
    );
    if (map == null) return const HealthConnectRawData();
    return HealthConnectRawData.fromMap(map);
  }
}

/// High-level Health Connect sync & mapping service for OpenGym.
class HealthConnectService {
  HealthConnectService({
    HealthConnectGateway? gateway,
  }) : _gateway = gateway ?? MethodChannelHealthConnectGateway();

  final HealthConnectGateway _gateway;

  static const List<String> allPermissions = <String>[
    'read_exercise',
    'write_exercise',
    'read_weight',
    'write_weight',
    'read_body_fat',
    'write_body_fat',
    'read_active_calories',
    'read_total_calories',
    'read_heart_rate',
  ];

  List<String> permissionsFor(HealthConnectSettings settings) {
    final perms = <String>[];
    if (settings.writeWorkouts) {
      perms.add('write_exercise');
    }
    if (settings.syncBodyMetrics) {
      perms.addAll(const <String>[
        'read_weight',
        'write_weight',
        'read_body_fat',
        'write_body_fat',
      ]);
    }
    if (settings.readExternalActivity) {
      perms.addAll(const <String>[
        'read_exercise',
        'read_active_calories',
        'read_total_calories',
        'read_heart_rate',
      ]);
    }
    return perms;
  }

  Future<HealthConnectSdkStatus> checkAvailability() => _gateway.getSdkStatus();

  Future<void> openSettings() => _gateway.openHealthConnectSettings();

  Future<bool> hasPermissions(List<String> permissions) =>
      _gateway.hasPermissions(permissions);

  Future<bool> requestPermissions(List<String> permissions) =>
      _gateway.requestPermissions(permissions);

  Future<String?> writeWorkout(WorkoutLog log) async {
    final endIso = log.finishedAt ?? HealthRecordMetadata.nowUtcIso();
    return _gateway.writeExerciseSession(
      id: log.id,
      title: log.title,
      startIso: log.startedAt,
      endIso: endIso,
      notes: log.notes,
    );
  }

  Future<String?> writeWeighIn(WeighIn weighIn) async {
    final parsedDate = DateTime.tryParse('${weighIn.date}T12:00:00Z') ??
        DateTime.now().toUtc();
    return _gateway.writeWeight(
      id: weighIn.id,
      weightKg: weighIn.weightKg,
      timeIso: parsedDate.toUtc().toIso8601String(),
    );
  }

  Future<String?> writeBodyFat(BodyMeasurement measurement) async {
    final pct = measurement.bodyFatPct;
    if (pct == null) return null;
    final parsedDate = DateTime.tryParse('${measurement.date}T12:00:00Z') ??
        DateTime.now().toUtc();
    return _gateway.writeBodyFat(
      id: measurement.id,
      percentage: pct,
      timeIso: parsedDate.toUtc().toIso8601String(),
    );
  }

  Future<HealthConnectRawData> readRecentData({
    DateTime? start,
    DateTime? end,
  }) {
    final now = (end ?? DateTime.now()).toUtc();
    final from = (start ?? now.subtract(const Duration(days: 30))).toUtc();
    return _gateway.readRecords(
      startIso: from.toIso8601String(),
      endIso: now.toIso8601String(),
    );
  }

  /// Aggregates active/total calories and heart rate samples per calendar day.
  List<DailyHealthMetrics> buildDailyMetrics(HealthConnectRawData raw) {
    final activeByDay = <String, double>{};
    final totalByDay = <String, double>{};
    final hrByDay = <String, List<int>>{};

    String? dayKey(String? iso) {
      if (iso == null || iso.length < 10) return null;
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) return iso.substring(0, 10);
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    for (final item in raw.activeCalories) {
      final key = dayKey(item['startIso'] as String?);
      final kcal = (item['kcal'] as num?)?.toDouble() ?? 0;
      if (key != null && kcal > 0) {
        activeByDay[key] = (activeByDay[key] ?? 0) + kcal;
      }
    }

    for (final item in raw.totalCalories) {
      final key = dayKey(item['startIso'] as String?);
      final kcal = (item['kcal'] as num?)?.toDouble() ?? 0;
      if (key != null && kcal > 0) {
        totalByDay[key] = (totalByDay[key] ?? 0) + kcal;
      }
    }

    for (final sample in raw.heartRateSamples) {
      final key = dayKey(sample['timeIso'] as String?);
      final bpm = (sample['bpm'] as num?)?.toInt();
      if (key != null && bpm != null && bpm > 0) {
        hrByDay.putIfAbsent(key, () => <int>[]).add(bpm);
      }
    }

    final allDays = <String>{
      ...activeByDay.keys,
      ...totalByDay.keys,
      ...hrByDay.keys,
    };

    final nowIso = HealthRecordMetadata.nowUtcIso();
    final results = <DailyHealthMetrics>[];
    for (final day in allDays) {
      final hrs = hrByDay[day];
      int? avgHr;
      int? minHr;
      int? maxHr;
      if (hrs != null && hrs.isNotEmpty) {
        hrs.sort();
        minHr = hrs.first;
        maxHr = hrs.last;
        avgHr = (hrs.reduce((a, b) => a + b) / hrs.length).round();
      }
      results.add(
        DailyHealthMetrics(
          id: day,
          date: day,
          activeCaloriesKcal: activeByDay[day] ?? 0,
          totalCaloriesKcal: totalByDay[day] ?? 0,
          avgHeartRateBpm: avgHr,
          minHeartRateBpm: minHr,
          maxHeartRateBpm: maxHr,
          updatedAt: nowIso,
        ),
      );
    }
    results.sort((a, b) => b.date.compareTo(a.date));
    return results;
  }

  /// Extracts external workout summaries (excluding HouseKeepr's own sessions)
  /// and enriches them with overlapping calories & heart rate samples.
  List<ExternalWorkoutSummary> buildExternalWorkouts(HealthConnectRawData raw) {
    final nowIso = HealthRecordMetadata.nowUtcIso();
    final list = <ExternalWorkoutSummary>[];

    for (final ex in raw.exercises) {
      final isExternal = (ex['isExternal'] as bool?) ?? true;
      if (!isExternal) continue;

      final startIso = ex['startIso'] as String?;
      final endIso = ex['endIso'] as String?;
      if (startIso == null || endIso == null) continue;
      final start = DateTime.tryParse(startIso);
      final end = DateTime.tryParse(endIso);
      if (start == null || end == null) continue;

      final metrics = computeWindowMetrics(raw, start, end);
      list.add(
        ExternalWorkoutSummary(
          id: (ex['id'] as String?) ?? HealthRecordMetadata.generateId(),
          title: (ex['title'] as String?) ?? 'External Workout',
          exerciseType: (ex['exerciseType'] as num?)?.toInt() ?? 0,
          startedAt: startIso,
          finishedAt: endIso,
          durationSeconds: end.difference(start).inSeconds.clamp(0, 86400),
          sourcePackage: (ex['sourcePackage'] as String?) ?? 'health_connect',
          caloriesKcal: metrics.caloriesKcal,
          avgHeartRateBpm: metrics.avgHeartRateBpm,
          maxHeartRateBpm: metrics.maxHeartRateBpm,
          updatedAt: nowIso,
        ),
      );
    }

    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  /// Computes calories and heart rate stats overlapping `[start, end]`.
  ({double? caloriesKcal, int? avgHeartRateBpm, int? maxHeartRateBpm})
      computeWindowMetrics(
    HealthConnectRawData raw,
    DateTime start,
    DateTime end,
  ) {
    double kcalSum = 0;
    for (final item in raw.activeCalories) {
      final s = DateTime.tryParse((item['startIso'] as String?) ?? '');
      final e = DateTime.tryParse((item['endIso'] as String?) ?? '');
      if (s == null || e == null) continue;
      if (!e.isBefore(start) && !s.isAfter(end)) {
        kcalSum += (item['kcal'] as num?)?.toDouble() ?? 0;
      }
    }

    final hrs = <int>[];
    for (final sample in raw.heartRateSamples) {
      final t = DateTime.tryParse((sample['timeIso'] as String?) ?? '');
      final bpm = (sample['bpm'] as num?)?.toInt();
      if (t == null || bpm == null || bpm <= 0) continue;
      if (!t.isBefore(start) && !t.isAfter(end)) {
        hrs.add(bpm);
      }
    }

    int? avgHr;
    int? maxHr;
    if (hrs.isNotEmpty) {
      hrs.sort();
      maxHr = hrs.last;
      avgHr = (hrs.reduce((a, b) => a + b) / hrs.length).round();
    }

    return (
      caloriesKcal: kcalSum > 0 ? kcalSum : null,
      avgHeartRateBpm: avgHr,
      maxHeartRateBpm: maxHr,
    );
  }
}
