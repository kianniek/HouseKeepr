import 'package:health_keepr/health_keepr.dart';

import '../data/exercise_catalog.dart';
import '../models/exercise.dart';
import '../models/workout_log.dart';
import '../models/workout_template.dart';

/// Persists OpenGym exercises, workout templates, and workout logs
/// strictly inside `health_keepr.db` under the `open_gym` namespace.
class OpenGymRepository {
  OpenGymRepository(this._store);

  static const String moduleId = 'open_gym';
  static const String _exercisesCollection = 'exercises';
  static const String _templatesCollection = 'templates';
  static const String _workoutsCollection = 'workouts';

  final HealthDataStore _store;

  /// Loads built-in exercises merged with user-created custom exercises.
  Future<List<Exercise>> loadExercises() async {
    final rawCustom =
        await _store.readCollection(moduleId, _exercisesCollection);
    final custom = rawCustom.map(Exercise.fromJson).toList();
    final merged = <String, Exercise>{
      for (final ex in ExerciseCatalog.builtInExercises) ex.id: ex,
      for (final ex in custom) ex.id: ex,
    };
    final list = merged.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> saveCustomExercise(Exercise exercise) async {
    await _store.upsertRecord(
      moduleId,
      _exercisesCollection,
      exercise.toJson(),
    );
  }

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
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> saveTemplate(WorkoutTemplate template) async {
    await _store.upsertRecord(
      moduleId,
      _templatesCollection,
      template.toJson(),
    );
  }

  Future<void> deleteTemplate(String id) async {
    await _store.deleteRecord(moduleId, _templatesCollection, id);
  }

  /// Loads completed workout logs sorted newest first.
  Future<List<WorkoutLog>> loadWorkouts() async {
    final raw = await _store.readCollection(moduleId, _workoutsCollection);
    final logs = raw.map(WorkoutLog.fromJson).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return logs;
  }

  Future<void> saveWorkout(WorkoutLog log) async {
    await _store.upsertRecord(
      moduleId,
      _workoutsCollection,
      log.toJson(),
    );
  }

  Future<void> deleteWorkout(String id) async {
    await _store.deleteRecord(moduleId, _workoutsCollection, id);
  }
}
