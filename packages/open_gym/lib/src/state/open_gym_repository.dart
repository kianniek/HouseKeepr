import 'package:health_keepr/health_keepr.dart';

import '../data/exercise_catalog.dart';
import '../models/body_measurement.dart';
import '../models/exercise.dart';
import '../models/health_connect_models.dart';
import '../models/programme.dart';
import '../models/progress_photo.dart';
import '../models/server_connection.dart';
import '../models/weigh_in.dart';
import '../models/workout_log.dart';
import '../models/workout_template.dart';

/// Persists all OpenGym data locally in `health_keepr.db` under `open_gym`.
class OpenGymRepository {
  OpenGymRepository(this._store);

  static const String moduleId = 'open_gym';
  static const String _exercisesCollection = 'exercises';
  static const String _templatesCollection = 'templates';
  static const String _workoutsCollection = 'workouts';
  static const String _weighInsCollection = 'weigh_ins';
  static const String _measurementsCollection = 'measurements';
  static const String _programmesCollection = 'programmes';
  static const String _progressPhotosCollection = 'progress_photos';
  static const String _externalWorkoutsCollection = 'external_workouts';
  static const String _dailyHealthMetricsCollection = 'daily_health_metrics';
  static const String _settingsCollection = 'settings';

  final HealthDataStore _store;

  /// Loads the full bundled exercise catalogue merged with custom exercises.
  Future<List<Exercise>> loadExercises() async {
    final bundled = await ExerciseCatalog.loadBundledExercises();
    final rawCustom =
        await _store.readCollection(moduleId, _exercisesCollection);
    final custom = rawCustom.map(Exercise.fromJson).toList();
    final merged = <String, Exercise>{
      for (final ex in bundled) ex.id: ex,
      for (final ex in custom) ex.id: ex,
    };
    final list = merged.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> saveCustomExercise(Exercise exercise) => _store.upsertRecord(
        moduleId,
        _exercisesCollection,
        exercise.toJson(),
      );

  /// Loads saved workout templates, seeding starter routines on first use.
  Future<List<WorkoutTemplate>> loadTemplates() async {
    final raw = await _store.readCollection(moduleId, _templatesCollection);
    if (raw.isEmpty) {
      final starters = ExerciseCatalog.starterTemplates();
      for (final template in starters) {
        await _store.upsertRecord(
          moduleId,
          _templatesCollection,
          template.toJson(),
        );
      }
      return starters;
    }
    return raw.map(WorkoutTemplate.fromJson).toList()
      ..sort((a, b) {
        final orderCmp = a.sortOrder.compareTo(b.sortOrder);
        if (orderCmp != 0) return orderCmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  Future<void> saveTemplate(WorkoutTemplate template) => _store.upsertRecord(
        moduleId,
        _templatesCollection,
        template.toJson(),
      );

  Future<void> deleteTemplate(String id) =>
      _store.deleteRecord(moduleId, _templatesCollection, id);

  /// Loads completed workout logs sorted newest first.
  Future<List<WorkoutLog>> loadWorkouts() async {
    final raw = await _store.readCollection(moduleId, _workoutsCollection);
    final logs = raw.map(WorkoutLog.fromJson).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return logs;
  }

  Future<void> saveWorkout(WorkoutLog log) => _store.upsertRecord(
        moduleId,
        _workoutsCollection,
        log.toJson(),
      );

  Future<void> deleteWorkout(String id) =>
      _store.deleteRecord(moduleId, _workoutsCollection, id);

  Future<List<WeighIn>> loadWeighIns() async {
    final raw = await _store.readCollection(moduleId, _weighInsCollection);
    return raw.map(WeighIn.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveWeighIn(WeighIn weighIn) => _store.upsertRecord(
        moduleId,
        _weighInsCollection,
        weighIn.toJson(),
      );

  Future<void> deleteWeighIn(String id) =>
      _store.deleteRecord(moduleId, _weighInsCollection, id);

  Future<List<BodyMeasurement>> loadMeasurements() async {
    final raw = await _store.readCollection(moduleId, _measurementsCollection);
    return raw.map(BodyMeasurement.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveMeasurement(BodyMeasurement measurement) =>
      _store.upsertRecord(
        moduleId,
        _measurementsCollection,
        measurement.toJson(),
      );

  Future<void> deleteMeasurement(String id) =>
      _store.deleteRecord(moduleId, _measurementsCollection, id);

  Future<List<Programme>> loadProgrammes() async {
    final raw = await _store.readCollection(moduleId, _programmesCollection);
    return raw.map(Programme.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> saveProgramme(Programme programme) => _store.upsertRecord(
        moduleId,
        _programmesCollection,
        programme.toJson(),
      );

  Future<void> deleteProgramme(String id) =>
      _store.deleteRecord(moduleId, _programmesCollection, id);

  Future<OpenGymPreferences> loadPreferences() async {
    final raw = await _store.readRecord(
      moduleId,
      _settingsCollection,
      'default_preferences',
    );
    if (raw == null) {
      return OpenGymPreferences(updatedAt: HealthRecordMetadata.nowUtcIso());
    }
    return OpenGymPreferences.fromJson(raw);
  }

  Future<void> savePreferences(OpenGymPreferences prefs) => _store.upsertRecord(
        moduleId,
        _settingsCollection,
        prefs.toJson(),
      );

  Future<ServerConnectionConfig?> loadServerConnection() async {
    final raw = await _store.readRecord(
      moduleId,
      _settingsCollection,
      'default_server_connection',
    );
    if (raw == null) return null;
    final config = ServerConnectionConfig.fromJson(raw);
    return config.serverUrl.isEmpty ? null : config;
  }

  Future<void> saveServerConnection(ServerConnectionConfig config) =>
      _store.upsertRecord(
        moduleId,
        _settingsCollection,
        config.toJson(),
      );

  Future<void> clearServerConnection() => _store.deleteRecord(
        moduleId,
        _settingsCollection,
        'default_server_connection',
      );

  Future<List<ProgressPhoto>> loadProgressPhotos() async {
    final raw = await _store.readCollection(moduleId, _progressPhotosCollection);
    return raw.map(ProgressPhoto.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveProgressPhoto(ProgressPhoto photo) => _store.upsertRecord(
        moduleId,
        _progressPhotosCollection,
        photo.toJson(),
      );

  Future<void> deleteProgressPhoto(String id) =>
      _store.deleteRecord(moduleId, _progressPhotosCollection, id);

  Future<HealthConnectSettings> loadHealthConnectSettings() async {
    final raw = await _store.readRecord(
      moduleId,
      _settingsCollection,
      'health_connect_settings',
    );
    if (raw == null) return const HealthConnectSettings();
    return HealthConnectSettings.fromJson(raw);
  }

  Future<void> saveHealthConnectSettings(HealthConnectSettings settings) =>
      _store.upsertRecord(
        moduleId,
        _settingsCollection,
        <String, dynamic>{
          'id': 'health_connect_settings',
          ...settings.toJson(),
        },
      );

  Future<List<ExternalWorkoutSummary>> loadExternalWorkouts() async {
    final raw =
        await _store.readCollection(moduleId, _externalWorkoutsCollection);
    return raw.map(ExternalWorkoutSummary.fromJson).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<void> saveExternalWorkout(ExternalWorkoutSummary workout) =>
      _store.upsertRecord(
        moduleId,
        _externalWorkoutsCollection,
        workout.toJson(),
      );

  Future<List<DailyHealthMetrics>> loadDailyHealthMetrics() async {
    final raw =
        await _store.readCollection(moduleId, _dailyHealthMetricsCollection);
    return raw.map(DailyHealthMetrics.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveDailyHealthMetrics(DailyHealthMetrics metrics) =>
      _store.upsertRecord(
        moduleId,
        _dailyHealthMetricsCollection,
        metrics.toJson(),
      );
}
