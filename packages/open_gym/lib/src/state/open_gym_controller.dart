import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health_keepr/health_keepr.dart';

import '../models/exercise.dart';
import '../models/exercise_set.dart';
import '../models/workout_log.dart';
import '../models/workout_template.dart';
import 'open_gym_repository.dart';
import 'personal_record_service.dart';

/// Coordinates OpenGym state: active workout session, timers, templates,
/// exercise library, and workout history.
class OpenGymController extends ChangeNotifier {
  OpenGymController({
    required HealthDataStore store,
    PersonalRecordService prService = const PersonalRecordService(),
  })  : _repository = OpenGymRepository(store),
        _prService = prService;

  final OpenGymRepository _repository;
  final PersonalRecordService _prService;

  bool _isLoading = true;
  List<Exercise> _exercises = <Exercise>[];
  List<WorkoutTemplate> _templates = <WorkoutTemplate>[];
  List<WorkoutLog> _history = <WorkoutLog>[];

  WorkoutLog? _activeWorkout;
  int _elapsedSeconds = 0;
  bool _isPaused = false;
  Timer? _workoutTimer;

  int _restRemainingSeconds = 0;
  int _restTotalSeconds = 0;
  Timer? _restTimer;

  /// Latest PRs earned in the current active session, keyed by set ID.
  final Map<String, List<RecordKind>> _sessionPrs =
      <String, List<RecordKind>>{};

  bool get isLoading => _isLoading;
  List<Exercise> get exercises => List<Exercise>.unmodifiable(_exercises);
  List<WorkoutTemplate> get templates =>
      List<WorkoutTemplate>.unmodifiable(_templates);
  List<WorkoutLog> get history => List<WorkoutLog>.unmodifiable(_history);

  WorkoutLog? get activeWorkout => _activeWorkout;
  bool get hasActiveWorkout => _activeWorkout != null;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isPaused => _isPaused;

  int get restRemainingSeconds => _restRemainingSeconds;
  int get restTotalSeconds => _restTotalSeconds;
  bool get isResting => _restRemainingSeconds > 0;

  Map<String, List<RecordKind>> get sessionPrs =>
      Map<String, List<RecordKind>>.unmodifiable(_sessionPrs);

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      _exercises = await _repository.loadExercises();
      _templates = await _repository.loadTemplates();
      _history = await _repository.loadWorkouts();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Active Workout Session ───────────────────────────────────────────────

  void startEmptyWorkout({String title = 'Quick Workout'}) {
    _startSession(WorkoutLog.create(title: title));
  }

  void startFromTemplate(WorkoutTemplate template) {
    final entries = template.entries.map((te) {
      final sets = List<ExerciseSet>.generate(
        te.targetSets,
        (_) => ExerciseSet.create(
          weight: te.defaultWeight,
          reps: te.targetReps,
        ),
      );
      return WorkoutEntry(
        exerciseId: te.exerciseId,
        exerciseName: te.exerciseName,
        bodyPart: te.bodyPart,
        equipment: te.equipment,
        sets: sets,
        restSeconds: te.restSeconds,
      );
    }).toList();

    _startSession(
      WorkoutLog.create(
        templateId: template.id,
        title: template.name,
        entries: entries,
      ),
    );
  }

  void _startSession(WorkoutLog log) {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _activeWorkout = log;
    _elapsedSeconds = 0;
    _isPaused = false;
    _restRemainingSeconds = 0;
    _restTotalSeconds = 0;
    _sessionPrs.clear();
    _startWorkoutTicker();
    notifyListeners();
  }

  void _startWorkoutTicker() {
    _workoutTimer?.cancel();
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused && _activeWorkout != null) {
        _elapsedSeconds++;
        notifyListeners();
      }
    });
  }

  void togglePause() {
    if (_activeWorkout == null) return;
    _isPaused = !_isPaused;
    notifyListeners();
  }

  void renameActiveWorkout(String title) {
    final current = _activeWorkout;
    if (current == null || title.trim().isEmpty) return;
    _activeWorkout = current.copyWith(title: title.trim());
    notifyListeners();
  }

  void addExerciseToActiveWorkout(Exercise exercise) {
    final current = _activeWorkout;
    if (current == null) return;
    final entry = WorkoutEntry(
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      bodyPart: exercise.bodyPart,
      equipment: exercise.equipment,
      sets: <ExerciseSet>[ExerciseSet.create(weight: 0, reps: 10)],
    );
    _activeWorkout = current.copyWith(
      entries: <WorkoutEntry>[...current.entries, entry],
    );
    notifyListeners();
  }

  void removeExerciseFromActiveWorkout(int entryIndex) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex < 0 ||
        entryIndex >= current.entries.length) {
      return;
    }
    final updated = List<WorkoutEntry>.from(current.entries)
      ..removeAt(entryIndex);
    _activeWorkout = current.copyWith(entries: updated);
    notifyListeners();
  }

  void addSet(int entryIndex) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex < 0 ||
        entryIndex >= current.entries.length) {
      return;
    }
    final entry = current.entries[entryIndex];
    final last = entry.sets.isNotEmpty ? entry.sets.last : null;
    final newSet = ExerciseSet.create(
      weight: last?.weight ?? 0,
      reps: last?.reps ?? 10,
    );
    final updatedEntries = List<WorkoutEntry>.from(current.entries);
    updatedEntries[entryIndex] =
        entry.copyWith(sets: <ExerciseSet>[...entry.sets, newSet]);
    _activeWorkout = current.copyWith(entries: updatedEntries);
    notifyListeners();
  }

  void removeSet(int entryIndex, int setIndex) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex < 0 ||
        entryIndex >= current.entries.length) {
      return;
    }
    final entry = current.entries[entryIndex];
    if (setIndex < 0 || setIndex >= entry.sets.length) return;
    final updatedSets = List<ExerciseSet>.from(entry.sets)..removeAt(setIndex);
    final updatedEntries = List<WorkoutEntry>.from(current.entries);
    updatedEntries[entryIndex] = entry.copyWith(sets: updatedSets);
    _activeWorkout = current.copyWith(entries: updatedEntries);
    notifyListeners();
  }

  void updateSet(
    int entryIndex,
    int setIndex, {
    double? weight,
    int? reps,
    bool? isWarmup,
    bool? isFailure,
  }) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex < 0 ||
        entryIndex >= current.entries.length) {
      return;
    }
    final entry = current.entries[entryIndex];
    if (setIndex < 0 || setIndex >= entry.sets.length) return;
    final updatedSets = List<ExerciseSet>.from(entry.sets);
    updatedSets[setIndex] = updatedSets[setIndex].copyWith(
      weight: weight,
      reps: reps,
      isWarmup: isWarmup,
      isFailure: isFailure,
    );
    final updatedEntries = List<WorkoutEntry>.from(current.entries);
    updatedEntries[entryIndex] = entry.copyWith(sets: updatedSets);
    _activeWorkout = current.copyWith(entries: updatedEntries);
    notifyListeners();
  }

  /// Toggles set completion, starts the rest timer when completed, and
  /// returns any newly earned [RecordKind]s for immediate UI feedback.
  List<RecordKind> toggleSetCompleted(int entryIndex, int setIndex) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex < 0 ||
        entryIndex >= current.entries.length) {
      return const <RecordKind>[];
    }
    final entry = current.entries[entryIndex];
    if (setIndex < 0 || setIndex >= entry.sets.length) {
      return const <RecordKind>[];
    }

    final target = entry.sets[setIndex];
    final nowCompleted = !target.isCompleted;
    final updatedSet = target.copyWith(isCompleted: nowCompleted);

    final updatedSets = List<ExerciseSet>.from(entry.sets);
    updatedSets[setIndex] = updatedSet;

    final updatedEntries = List<WorkoutEntry>.from(current.entries);
    updatedEntries[entryIndex] = entry.copyWith(sets: updatedSets);
    _activeWorkout = current.copyWith(entries: updatedEntries);

    List<RecordKind> earnedPrs = const <RecordKind>[];
    if (nowCompleted) {
      startRest(entry.restSeconds);
      final baseline = _prService.baselineFor(
        entry.exerciseId,
        _history,
        exerciseName: entry.exerciseName,
      );
      earnedPrs = _prService.evaluateSet(updatedSet, baseline);
      if (earnedPrs.isNotEmpty) {
        _sessionPrs[updatedSet.id] = earnedPrs;
      }
    } else {
      _sessionPrs.remove(updatedSet.id);
    }

    notifyListeners();
    return earnedPrs;
  }

  // ── Rest Countdown Timer ─────────────────────────────────────────────────

  void startRest(int seconds) {
    if (seconds <= 0) return;
    _restTimer?.cancel();
    _restTotalSeconds = seconds;
    _restRemainingSeconds = seconds;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restRemainingSeconds <= 1) {
        _restRemainingSeconds = 0;
        timer.cancel();
      } else {
        _restRemainingSeconds--;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void addRest(int deltaSeconds) {
    if (!isResting) return;
    final next = _restRemainingSeconds + deltaSeconds;
    if (next <= 0) {
      skipRest();
    } else {
      _restRemainingSeconds = next;
      if (next > _restTotalSeconds) _restTotalSeconds = next;
      notifyListeners();
    }
  }

  void skipRest() {
    _restTimer?.cancel();
    _restRemainingSeconds = 0;
    _restTotalSeconds = 0;
    notifyListeners();
  }

  Future<WorkoutLog?> finishWorkout() async {
    final current = _activeWorkout;
    if (current == null) return null;

    _workoutTimer?.cancel();
    _restTimer?.cancel();

    final completed = current.copyWith(
      finishedAt: HealthRecordMetadata.nowUtcIso(),
      durationSeconds: _elapsedSeconds,
    );

    await _repository.saveWorkout(completed);
    _history = <WorkoutLog>[completed, ..._history];
    _activeWorkout = null;
    _elapsedSeconds = 0;
    _isPaused = false;
    _restRemainingSeconds = 0;
    _restTotalSeconds = 0;
    _sessionPrs.clear();
    notifyListeners();
    return completed;
  }

  void discardWorkout() {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _activeWorkout = null;
    _elapsedSeconds = 0;
    _isPaused = false;
    _restRemainingSeconds = 0;
    _restTotalSeconds = 0;
    _sessionPrs.clear();
    notifyListeners();
  }

  // ── Routines & Exercises CRUD ────────────────────────────────────────────

  Future<void> saveTemplate(WorkoutTemplate template) async {
    await _repository.saveTemplate(template);
    final idx = _templates.indexWhere((t) => t.id == template.id);
    if (idx >= 0) {
      final copy = List<WorkoutTemplate>.from(_templates);
      copy[idx] = template;
      _templates = copy;
    } else {
      _templates = <WorkoutTemplate>[..._templates, template];
    }
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    await _repository.deleteTemplate(id);
    _templates = _templates.where((t) => t.id != id).toList();
    notifyListeners();
  }

  Future<void> addCustomExercise(Exercise exercise) async {
    await _repository.saveCustomExercise(exercise);
    _exercises = <Exercise>[..._exercises, exercise]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
  }

  Future<void> deleteWorkoutLog(String id) async {
    await _repository.deleteWorkout(id);
    _history = _history.where((w) => w.id != id).toList();
    notifyListeners();
  }

  List<ExerciseRecordBaseline> get allPersonalRecords =>
      _prService.allRecords(_history);

  double get totalLifetimeVolume =>
      _history.fold<double>(0, (sum, log) => sum + log.totalVolume);

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }
}
