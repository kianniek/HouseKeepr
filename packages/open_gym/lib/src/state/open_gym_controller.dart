import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:health_keepr/health_keepr.dart';

import '../audio/open_gym_sound_service.dart';
import '../data/exercise_media_service.dart';
import '../models/active_workout_snapshot.dart';
import '../models/body_measurement.dart';
import '../models/exercise.dart';
import '../models/exercise_set.dart';
import '../models/health_connect_models.dart';
import '../models/programme.dart';
import '../models/progress_photo.dart';
import '../models/server_connection.dart';
import '../models/weigh_in.dart';
import '../models/workout_log.dart';
import '../models/workout_template.dart';
import '../sync/health_connect_service.dart';
import '../sync/open_gym_server_client.dart';
import '../sync/open_gym_sync_service.dart';
import '../sync/webdav_client.dart';
import 'analytics_service.dart';
import 'open_gym_live_notification_service.dart';
import 'open_gym_repository.dart';
import 'open_gym_shortcut_service.dart';
import 'personal_record_service.dart';
import 'progression_service.dart';

/// Snapshot for undoing a rotation loop stop removal.
class RotationSnapshot {
  const RotationSnapshot({
    required this.sequence,
    required this.completedIndices,
    required this.rotationIndex,
  });

  final List<String> sequence;
  final List<int> completedIndices;
  final int rotationIndex;
}

/// Snapshot for undoing a routine deletion (restores list index, schedule, and loop).
class RoutineDeleteSnapshot {
  const RoutineDeleteSnapshot({
    required this.template,
    required this.index,
    required this.weeklySchedule,
    required this.rotationSequence,
    required this.rotationCompletedIndices,
    required this.dayOverrides,
  });

  final WorkoutTemplate template;
  final int index;
  final Map<int, List<String>> weeklySchedule;
  final List<String> rotationSequence;
  final List<int> rotationCompletedIndices;
  final Map<String, String> dayOverrides;
}

/// Coordinates OpenGym state: active workout session, timers, templates,
/// progression engine, rotation/schedule, exercise library, body tracking, and sync.
class OpenGymController extends ChangeNotifier {
  OpenGymController({
    required HealthDataStore store,
    PersonalRecordService prService = const PersonalRecordService(),
    OpenGymAnalyticsService analyticsService = const OpenGymAnalyticsService(),
    ProgressionService progressionService = const ProgressionService(),
    OpenGymServerClient? serverClient,
    HealthConnectService? healthConnectService,
    OpenGymShortcutService? shortcutService,
    WorkoutNotificationScheduler? notificationScheduler,
    OpenGymLiveNotificationService? liveNotificationService,
    void Function(bool keepAwake)? onWakeLockChanged,
  })  : _repository = OpenGymRepository(store),
        _prService = prService,
        _analyticsService = analyticsService,
        _progressionService = progressionService,
        _serverClient = serverClient ?? OpenGymServerClient(),
        _syncService = OpenGymSyncService(
          store: store,
          client: serverClient,
        ),
        _healthConnect = healthConnectService ?? HealthConnectService(),
        _shortcutService = shortcutService ?? const OpenGymShortcutService(),
        _notificationScheduler = notificationScheduler,
        _liveNotificationService =
            liveNotificationService ?? OpenGymLiveNotificationService(),
        _mediaService = ExerciseMediaService(store: store),
        _soundService = OpenGymSoundService(),
        _onWakeLockChanged = onWakeLockChanged;

  static const String restStopId = 'rest';

  final OpenGymRepository _repository;
  final PersonalRecordService _prService;
  final OpenGymAnalyticsService _analyticsService;
  final ProgressionService _progressionService;
  final OpenGymServerClient _serverClient;
  final OpenGymSyncService _syncService;
  final HealthConnectService _healthConnect;
  final OpenGymShortcutService _shortcutService;
  final WorkoutNotificationScheduler? _notificationScheduler;
  final OpenGymLiveNotificationService _liveNotificationService;
  final ExerciseMediaService _mediaService;
  final OpenGymSoundService _soundService;
  final void Function(bool keepAwake)? _onWakeLockChanged;

  OpenGymLiveUpdateStatus _liveUpdateStatus = const OpenGymLiveUpdateStatus();
  StreamSubscription<OpenGymLiveAction>? _liveActionSub;
  OpenGymLiveWorkoutPayload? _lastSentLivePayload;

  bool _isLoading = true;
  bool _isSyncing = false;
  Color _shortcutIconColor = OpenGymShortcutService.defaultIconColor;
  Color _shortcutBackgroundColor =
      OpenGymShortcutService.defaultBackgroundColor;
  List<Exercise> _exercises = <Exercise>[];
  List<WorkoutTemplate> _templates = <WorkoutTemplate>[];
  List<WorkoutLog> _history = <WorkoutLog>[];
  List<WeighIn> _weighIns = <WeighIn>[];
  List<BodyMeasurement> _measurements = <BodyMeasurement>[];
  List<Programme> _programmes = <Programme>[];
  List<ProgressPhoto> _progressPhotos = <ProgressPhoto>[];
  OpenGymPreferences _preferences = OpenGymPreferences(
    updatedAt: HealthRecordMetadata.nowUtcIso(),
  );
  ServerConnectionConfig? _serverConnection;
  HealthConnectSettings _healthConnectSettings = const HealthConnectSettings();
  HealthConnectSdkStatus _healthConnectSdkStatus =
      HealthConnectSdkStatus.unavailable;
  bool _healthConnectSyncing = false;
  String? _healthConnectError;
  List<ExternalWorkoutSummary> _externalWorkouts = <ExternalWorkoutSummary>[];
  List<DailyHealthMetrics> _dailyHealthMetrics = <DailyHealthMetrics>[];

  WorkoutLog? _activeWorkout;
  int _elapsedSeconds = 0;
  bool _isPaused = false;
  Timer? _workoutTimer;
  DateTime? _workoutStartedAt;
  DateTime? _pausedAt;
  Duration _accumulatedPaused = Duration.zero;

  int _restRemainingSeconds = 0;
  int _restTotalSeconds = 0;
  int _restCompletedNonce = 0;
  Timer? _restTimer;
  DateTime? _restEndsAt;
  final Set<int> _countdownBeepedSeconds = <int>{};

  final Map<String, List<RecordKind>> _sessionPrs =
      <String, List<RecordKind>>{};
  int _selectedEntryIndex = 0;
  bool _isInActiveWorkoutScreen = false;

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  List<Exercise> get exercises => List<Exercise>.unmodifiable(_exercises);
  List<WorkoutTemplate> get templates =>
      List<WorkoutTemplate>.unmodifiable(_templates);
  List<WorkoutLog> get history => List<WorkoutLog>.unmodifiable(_history);
  List<WeighIn> get weighIns => List<WeighIn>.unmodifiable(_weighIns);
  List<BodyMeasurement> get measurements =>
      List<BodyMeasurement>.unmodifiable(_measurements);
  List<Programme> get programmes => List<Programme>.unmodifiable(_programmes);
  List<ProgressPhoto> get progressPhotos =>
      List<ProgressPhoto>.unmodifiable(_progressPhotos);
  OpenGymPreferences get preferences => _preferences;
  ServerConnectionConfig? get serverConnection => _serverConnection;
  HealthConnectSettings get healthConnectSettings => _healthConnectSettings;
  HealthConnectSdkStatus get healthConnectSdkStatus => _healthConnectSdkStatus;
  bool get healthConnectSyncing => _healthConnectSyncing;
  String? get healthConnectError => _healthConnectError;
  List<ExternalWorkoutSummary> get externalWorkouts =>
      List<ExternalWorkoutSummary>.unmodifiable(_externalWorkouts);
  List<DailyHealthMetrics> get dailyHealthMetrics =>
      List<DailyHealthMetrics>.unmodifiable(_dailyHealthMetrics);
  HealthConnectService get healthConnect => _healthConnect;
  OpenGymAnalyticsService get analytics => _analyticsService;
  ProgressionService get progressionService => _progressionService;
  OpenGymServerClient get serverClient => _serverClient;
  ExerciseMediaService get mediaService => _mediaService;
  OpenGymSoundService get soundService => _soundService;

  WorkoutLog? get activeWorkout => _activeWorkout;
  bool get hasActiveWorkout => _activeWorkout != null;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isPaused => _isPaused;
  bool get keepScreenAwakeActive =>
      hasActiveWorkout && !_isPaused && _preferences.keepScreenAwake;

  int get restRemainingSeconds => _restRemainingSeconds;
  int get restTotalSeconds => _restTotalSeconds;
  int get restCompletedNonce => _restCompletedNonce;
  bool get isResting => _restRemainingSeconds > 0;

  Map<String, List<RecordKind>> get sessionPrs =>
      Map<String, List<RecordKind>>.unmodifiable(_sessionPrs);
  int get selectedEntryIndex => _selectedEntryIndex;
  bool get isInActiveWorkoutScreen => _isInActiveWorkoutScreen;
  OpenGymLiveUpdateStatus get liveUpdateStatus => _liveUpdateStatus;

  void setSelectedEntryIndex(int index) {
    final entries = _activeWorkout?.entries ?? const <WorkoutEntry>[];
    final clamped = entries.isEmpty ? 0 : index.clamp(0, entries.length - 1);
    if (_selectedEntryIndex == clamped) return;
    _selectedEntryIndex = clamped;
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

  void setInActiveWorkoutScreen(bool value) {
    if (_isInActiveWorkoutScreen == value) return;
    _isInActiveWorkoutScreen = value;
    _persistActiveSession();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _reloadAllFromStore();
      _liveUpdateStatus =
          await _liveNotificationService.getLiveUpdateStatus();
      _liveActionSub ??=
          _liveNotificationService.actions.listen(_applyLiveAction);
      await syncPendingLiveNotificationActions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadAllFromStore() async {
    _exercises = await _repository.loadExercises();
    _templates = await _repository.loadTemplates();
    _history = await _repository.loadWorkouts();
    _weighIns = await _repository.loadWeighIns();
    _measurements = await _repository.loadMeasurements();
    _programmes = await _repository.loadProgrammes();
    _progressPhotos = await _repository.loadProgressPhotos();
    _preferences = await _repository.loadPreferences();
    _serverConnection = await _repository.loadServerConnection();
    _healthConnectSettings = await _repository.loadHealthConnectSettings();
    _externalWorkouts = await _repository.loadExternalWorkouts();
    _dailyHealthMetrics = await _repository.loadDailyHealthMetrics();
    _healthConnectSdkStatus = await _healthConnect.checkAvailability();

    // Seed initial rotation sequence and default Mon/Wed/Fri weekly schedule if empty.
    var prefsUpdated = _preferences;
    var dirty = false;
    if (prefsUpdated.rotationSequence.isEmpty && _templates.isNotEmpty) {
      prefsUpdated = prefsUpdated.copyWith(
        rotationSequence: _templates.take(3).map((t) => t.id).toList(),
      );
      dirty = true;
    }
    if (prefsUpdated.weeklySchedule.isEmpty && _templates.length >= 3) {
      prefsUpdated = prefsUpdated.copyWith(
        weeklySchedule: <int, List<String>>{
          1: <String>[_templates[0].id],
          3: <String>[_templates[1].id],
          5: <String>[_templates[2].id],
        },
      );
      dirty = true;
    }
    if (dirty) {
      _preferences = prefsUpdated;
      await _repository.savePreferences(prefsUpdated);
    }
    final activeSnapshot = await _repository.loadActiveSession();
    _restoreActiveSession(activeSnapshot);
    _syncNextWorkoutShortcut();
  }

  void updateShortcutColors({
    required Color iconColor,
    required Color backgroundColor,
  }) {
    if (_shortcutIconColor == iconColor &&
        _shortcutBackgroundColor == backgroundColor) {
      return;
    }
    _shortcutIconColor = iconColor;
    _shortcutBackgroundColor = backgroundColor;
    if (!_isLoading) {
      _syncNextWorkoutShortcut();
      if (_activeWorkout != null) {
        _syncLiveNotification();
      }
    }
  }

  void _syncNextWorkoutShortcut() {
    unawaited(
      _shortcutService.updateNextWorkoutShortcut(
        todaysScheduledTemplate(),
        iconColor: _shortcutIconColor,
        backgroundColor: _shortcutBackgroundColor,
      ),
    );
  }

  // ── Progression Helpers ──────────────────────────────────────────────────

  /// Computes live prescription & insight copy for an active workout entry.
  ExercisePrescription prescribeForActiveEntry(WorkoutEntry entry) {
    final activeTemplate = _activeWorkout?.templateId != null
        ? _templates
            .where((t) => t.id == _activeWorkout!.templateId)
            .firstOrNull
        : null;
    final templateEntry = activeTemplate?.entries
        .where((te) => te.exerciseId == entry.exerciseId)
        .firstOrNull;
    final workCount = entry.sets.where((s) => !s.isWarmup).length;
    final targetReps = templateEntry?.targetReps ??
        (entry.sets.isNotEmpty ? entry.sets.first.reps : 8);

    final synthetic = templateEntry ??
        WorkoutTemplateEntry(
          exerciseId: entry.exerciseId,
          exerciseName: entry.exerciseName,
          bodyPart: entry.bodyPart,
          equipment: entry.equipment,
          mode: entry.mode,
          targetSets: workCount > 0 ? workCount : 3,
          targetReps: targetReps > 0 ? targetReps : 8,
          defaultWeight: entry.sets.isNotEmpty ? entry.sets.first.weight : 0,
          restSeconds: entry.restSeconds,
          progressionPolicy: entry.progressionMode,
        );

    return _progressionService.prescribe(
      entry: synthetic,
      history: _history,
      routinePolicy: activeTemplate?.progressionPolicy ?? entry.progressionMode,
      routineIsDeload: activeTemplate?.isDeload ?? false,
      unit: _preferences.weightUnit,
      oneRmFormula: _preferences.oneRmFormula,
    );
  }

  ExerciseRecordBaseline recordBaselineFor(String exerciseId, {String? name}) {
    return _prService.baselineFor(
      exerciseId,
      _history,
      exerciseName: name,
      formula: _preferences.oneRmFormula,
    );
  }

  // ── Active Workout Session ───────────────────────────────────────────────

  void startEmptyWorkout({String title = 'Quick Workout'}) {
    _startSession(WorkoutLog.create(title: title));
  }

  void startFromTemplate(WorkoutTemplate template) {
    final entries = template.entries.map((te) {
      final rx = _progressionService.prescribe(
        entry: te,
        history: _history,
        routinePolicy: template.progressionPolicy,
        routineIsDeload: template.isDeload,
        unit: _preferences.weightUnit,
        oneRmFormula: _preferences.oneRmFormula,
      );
      final sets = List<ExerciseSet>.generate(
        rx.sets,
        (_) => ExerciseSet.create(
          weight: rx.weight,
          reps: rx.reps,
        ),
      );
      return WorkoutEntry(
        exerciseId: te.exerciseId,
        exerciseName: te.exerciseName,
        bodyPart: te.bodyPart,
        equipment: te.equipment,
        mode: te.mode,
        sets: sets,
        restSeconds: rx.restSeconds,
        notes: te.note,
        supersetId: te.supersetId,
        progressionMode: rx.policyKey,
      );
    }).toList();

    _startSession(
      WorkoutLog.create(
        templateId: template.id,
        title: template.name,
        entries: entries,
        countForProgression: !template.isDeload,
      ),
    );
  }

  void _restoreActiveSession(ActiveWorkoutSnapshot? snapshot) {
    if (snapshot == null) return;
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _activeWorkout = snapshot.workout;
    _workoutStartedAt =
        DateTime.tryParse(snapshot.workoutStartedAt)?.toLocal() ??
            DateTime.now();
    _pausedAt = snapshot.pausedAt != null
        ? DateTime.tryParse(snapshot.pausedAt!)?.toLocal()
        : null;
    _accumulatedPaused = Duration(milliseconds: snapshot.accumulatedPausedMs);
    _isPaused = snapshot.isPaused;

    final referenceNow = _isPaused ? (_pausedAt ?? DateTime.now()) : DateTime.now();
    final elapsed = referenceNow.difference(_workoutStartedAt!).inSeconds -
        _accumulatedPaused.inSeconds;
    _elapsedSeconds = elapsed < 0 ? 0 : elapsed;

    _sessionPrs
      ..clear()
      ..addAll(snapshot.sessionPrs);
    final entries = snapshot.workout.entries;
    _selectedEntryIndex = entries.isEmpty
        ? 0
        : snapshot.selectedEntryIndex.clamp(0, entries.length - 1);
    _isInActiveWorkoutScreen = snapshot.isInActiveWorkoutScreen;

    _countdownBeepedSeconds.clear();
    _restRemainingSeconds = 0;
    _restTotalSeconds = 0;
    _restEndsAt = null;
    if (snapshot.restEndsAt != null) {
      final parsedEnd = DateTime.tryParse(snapshot.restEndsAt!)?.toLocal();
      if (parsedEnd != null) {
        final remainingMs = parsedEnd.difference(referenceNow).inMilliseconds;
        if (remainingMs > 0) {
          _restEndsAt = parsedEnd;
          _restRemainingSeconds = (remainingMs / 1000.0).ceil();
          _restTotalSeconds = snapshot.restTotalSeconds > 0
              ? snapshot.restTotalSeconds
              : _restRemainingSeconds;
          if (!_isPaused) {
            _startRestTicker();
          }
        }
      }
    }

    _startWorkoutTicker();
    _notifyWakeLock();
    _syncLiveNotification();
  }

  void _persistActiveSession() {
    final current = _activeWorkout;
    if (current == null) return;
    final snapshot = ActiveWorkoutSnapshot(
      workout: current,
      workoutStartedAt:
          (_workoutStartedAt ?? DateTime.now()).toUtc().toIso8601String(),
      pausedAt: _pausedAt?.toUtc().toIso8601String(),
      accumulatedPausedMs: _accumulatedPaused.inMilliseconds,
      isPaused: _isPaused,
      restEndsAt: _restEndsAt?.toUtc().toIso8601String(),
      restTotalSeconds: _restTotalSeconds,
      sessionPrs: Map<String, List<RecordKind>>.from(_sessionPrs),
      selectedEntryIndex: _selectedEntryIndex,
      isInActiveWorkoutScreen: _isInActiveWorkoutScreen,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
    );
    unawaited(_repository.saveActiveSession(snapshot));
  }

  void _scheduleRestNotification() {
    final endsAt = _restEndsAt;
    final scheduler = _notificationScheduler;
    if (endsAt == null || scheduler == null || _isPaused) return;
    unawaited(
      scheduler.scheduleRestEnd(
        endsAt: endsAt,
        soundProfileId: _preferences.restSound,
        soundEnabled: _preferences.soundEnabled,
        hapticsEnabled: _preferences.hapticsEnabled,
        workoutTitle: _activeWorkout?.title ?? 'OpenGym',
      ),
    );
  }

  void _cancelRestNotification() {
    final scheduler = _notificationScheduler;
    if (scheduler == null) return;
    unawaited(scheduler.cancelRestEnd());
  }

  void _startSession(WorkoutLog log) {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _cancelRestNotification();
    _activeWorkout = log;
    _elapsedSeconds = 0;
    _isPaused = false;
    _workoutStartedAt = DateTime.now();
    _pausedAt = null;
    _accumulatedPaused = Duration.zero;
    _restRemainingSeconds = 0;
    _restTotalSeconds = 0;
    _restEndsAt = null;
    _countdownBeepedSeconds.clear();
    _sessionPrs.clear();
    _selectedEntryIndex = 0;
    _isInActiveWorkoutScreen = false;
    _startWorkoutTicker();
    _notifyWakeLock();
    _persistActiveSession();
    _lastSentLivePayload = null;
    _syncLiveNotification();
    notifyListeners();
  }

  void _notifyWakeLock() {
    _onWakeLockChanged?.call(keepScreenAwakeActive);
  }

  void _startWorkoutTicker() {
    _workoutTimer?.cancel();
    _workoutTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_isPaused && _activeWorkout != null && _workoutStartedAt != null) {
        final nextElapsed = DateTime.now()
            .difference(_workoutStartedAt!)
            .inSeconds -
            _accumulatedPaused.inSeconds;
        final clamped = nextElapsed < 0 ? 0 : nextElapsed;
        if (clamped != _elapsedSeconds) {
          _elapsedSeconds = clamped;
          notifyListeners();
        }
      }
    });
  }

  void togglePause() {
    if (_activeWorkout == null) return;
    _isPaused = !_isPaused;
    final now = DateTime.now();
    if (_isPaused) {
      _pausedAt = now;
      _cancelRestNotification();
    } else {
      if (_pausedAt != null) {
        final pauseSpan = now.difference(_pausedAt!);
        _accumulatedPaused += pauseSpan;
        if (_restEndsAt != null) {
          _restEndsAt = _restEndsAt!.add(pauseSpan);
        }
        _pausedAt = null;
      }
      if (_restEndsAt != null) {
        _scheduleRestNotification();
      }
    }
    _notifyWakeLock();
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

  void renameActiveWorkout(String title) {
    final current = _activeWorkout;
    if (current == null || title.trim().isEmpty) return;
    _activeWorkout = current.copyWith(title: title.trim());
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

  void setSessionNote(String? notes) {
    final current = _activeWorkout;
    if (current == null) return;
    final trimmed = notes?.trim();
    _activeWorkout = current.copyWith(
      notes: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
    _persistActiveSession();
    notifyListeners();
  }

  void setCountForProgression(bool count) {
    final current = _activeWorkout;
    if (current == null) return;
    _activeWorkout = current.copyWith(countForProgression: count);
    _persistActiveSession();
    notifyListeners();
  }

  void addRoutineToActiveWorkout(WorkoutTemplate template) {
    final current = _activeWorkout;
    if (current == null) return;
    final existingIds = current.entries.map((e) => e.exerciseId).toSet();
    final newEntries = <WorkoutEntry>[];
    for (final te in template.entries) {
      if (existingIds.contains(te.exerciseId)) continue;
      final rx = _progressionService.prescribe(
        entry: te,
        history: _history,
        routinePolicy: template.progressionPolicy,
        routineIsDeload: template.isDeload,
        unit: _preferences.weightUnit,
        oneRmFormula: _preferences.oneRmFormula,
      );
      final sets = List<ExerciseSet>.generate(
        rx.sets,
        (_) => ExerciseSet.create(
          weight: rx.weight,
          reps: rx.reps,
        ),
      );
      newEntries.add(
        WorkoutEntry(
          exerciseId: te.exerciseId,
          exerciseName: te.exerciseName,
          bodyPart: te.bodyPart,
          equipment: te.equipment,
          mode: te.mode,
          sets: sets,
          restSeconds: rx.restSeconds,
          notes: te.note,
          supersetId: te.supersetId,
          progressionMode: rx.policyKey,
        ),
      );
    }
    if (newEntries.isEmpty) return;
    _activeWorkout = current.copyWith(
      entries: <WorkoutEntry>[...current.entries, ...newEntries],
    );
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

  void addExerciseToActiveWorkout(Exercise exercise) {
    final current = _activeWorkout;
    if (current == null) return;
    final defaultMode = exercise.bodyPart == 'cardio'
        ? ExerciseMode.cardio
        : ExerciseMode.reps;
    final entry = WorkoutEntry(
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      bodyPart: exercise.bodyPart,
      equipment: exercise.equipment,
      mode: defaultMode,
      restSeconds: _preferences.defaultRestSeconds,
      sets: <ExerciseSet>[ExerciseSet.create(weight: 0, reps: 10)],
    );
    _activeWorkout = current.copyWith(
      entries: <WorkoutEntry>[...current.entries, entry],
    );
    _persistActiveSession();
    _syncLiveNotification();
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
    if (updated.isEmpty) {
      _selectedEntryIndex = 0;
    } else if (_selectedEntryIndex >= updated.length) {
      _selectedEntryIndex = updated.length - 1;
    }
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

  void _updateEntry(
    int entryIndex,
    WorkoutEntry Function(WorkoutEntry entry) transform,
  ) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex < 0 ||
        entryIndex >= current.entries.length) {
      return;
    }
    final updatedEntries = List<WorkoutEntry>.from(current.entries);
    updatedEntries[entryIndex] = transform(updatedEntries[entryIndex]);
    _activeWorkout = current.copyWith(entries: updatedEntries);
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

  void setEntryMode(int entryIndex, ExerciseMode mode) =>
      _updateEntry(entryIndex, (e) => e.copyWith(mode: mode));

  void setEntryNote(int entryIndex, String? note) {
    final trimmed = note?.trim();
    _updateEntry(
      entryIndex,
      (e) => (trimmed == null || trimmed.isEmpty)
          ? e.copyWith(clearNotes: true)
          : e.copyWith(notes: trimmed),
    );
  }

  void swapExerciseInActiveWorkout(int entryIndex, Exercise replacement) {
    final mode = replacement.bodyPart == 'cardio'
        ? ExerciseMode.cardio
        : ExerciseMode.reps;
    _updateEntry(
      entryIndex,
      (e) => e.copyWith(
        exerciseId: replacement.id,
        exerciseName: replacement.name,
        bodyPart: replacement.bodyPart,
        equipment: replacement.equipment,
        mode: mode,
      ),
    );
  }

  void addWarmupSet(int entryIndex) {
    _updateEntry(entryIndex, (e) {
      final first = e.sets.isNotEmpty ? e.sets.first : null;
      final warmup = ExerciseSet.create(
        weight: first?.weight ?? 0,
        reps: first?.reps ?? 8,
        isWarmup: true,
      );
      return e.copyWith(sets: <ExerciseSet>[warmup, ...e.sets]);
    });
  }

  void setEntryRestSeconds(int entryIndex, int seconds) =>
      _updateEntry(entryIndex, (e) => e.copyWith(restSeconds: seconds));

  void setEntryProgressionMode(int entryIndex, String mode) =>
      _updateEntry(entryIndex, (e) => e.copyWith(progressionMode: mode));

  void setEntryCountForProgression(int entryIndex, bool count) =>
      _updateEntry(entryIndex, (e) => e.copyWith(countForProgression: count));

  void toggleSupersetWithNext(int entryIndex) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex < 0 ||
        entryIndex >= current.entries.length - 1) {
      return;
    }
    final updated = List<WorkoutEntry>.from(current.entries);
    final first = updated[entryIndex];
    final second = updated[entryIndex + 1];
    final linked = first.supersetId != null &&
        first.supersetId == second.supersetId;
    if (linked) {
      updated[entryIndex] = first.copyWith(clearSuperset: true);
      updated[entryIndex + 1] = second.copyWith(clearSuperset: true);
    } else {
      final id = HealthRecordMetadata.generateId();
      updated[entryIndex] = first.copyWith(supersetId: id);
      updated[entryIndex + 1] = second.copyWith(supersetId: id);
    }
    _activeWorkout = current.copyWith(entries: updated);
    _persistActiveSession();
    notifyListeners();
  }

  void moveEntryUp(int entryIndex) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex <= 0 ||
        entryIndex >= current.entries.length) {
      return;
    }
    final updated = List<WorkoutEntry>.from(current.entries);
    final item = updated.removeAt(entryIndex);
    updated.insert(entryIndex - 1, item);
    _activeWorkout = current.copyWith(entries: updated);
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

  void moveEntryDown(int entryIndex) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex < 0 ||
        entryIndex >= current.entries.length - 1) {
      return;
    }
    final updated = List<WorkoutEntry>.from(current.entries);
    final item = updated.removeAt(entryIndex);
    updated.insert(entryIndex + 1, item);
    _activeWorkout = current.copyWith(entries: updated);
    _persistActiveSession();
    _syncLiveNotification();
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
      durationSeconds: last?.durationSeconds,
      distanceMeters: last?.distanceMeters,
    );
    final updatedEntries = List<WorkoutEntry>.from(current.entries);
    updatedEntries[entryIndex] =
        entry.copyWith(sets: <ExerciseSet>[...entry.sets, newSet]);
    _activeWorkout = current.copyWith(entries: updatedEntries);
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

  void duplicateSet(int entryIndex, int setIndex) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex < 0 ||
        entryIndex >= current.entries.length) {
      return;
    }
    final entry = current.entries[entryIndex];
    if (setIndex < 0 || setIndex >= entry.sets.length) return;
    final source = entry.sets[setIndex];
    final copy = ExerciseSet.create(
      weight: source.weight,
      reps: source.reps,
      durationSeconds: source.durationSeconds,
      distanceMeters: source.distanceMeters,
      speed: source.speed,
      incline: source.incline,
      setType: source.setType,
      drops: source.drops,
      clusters: source.clusters,
      isWarmup: source.isWarmup,
      isFailure: source.isFailure,
      rpe: source.rpe,
      rir: source.rir,
    );
    final updatedSets = List<ExerciseSet>.from(entry.sets)
      ..insert(setIndex + 1, copy);
    final updatedEntries = List<WorkoutEntry>.from(current.entries);
    updatedEntries[entryIndex] = entry.copyWith(sets: updatedSets);
    _activeWorkout = current.copyWith(entries: updatedEntries);
    _persistActiveSession();
    _syncLiveNotification();
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
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

  void updateSet(
    int entryIndex,
    int setIndex, {
    double? weight,
    int? reps,
    int? durationSeconds,
    double? distanceMeters,
    SetType? setType,
    List<SetDrop>? drops,
    List<SetCluster>? clusters,
    bool? isWarmup,
    bool? isFailure,
    double? rpe,
    int? rir,
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
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      setType: setType,
      drops: drops,
      clusters: clusters,
      isWarmup: isWarmup,
      isFailure: isFailure,
      rpe: rpe,
      rir: rir,
    );
    final updatedEntries = List<WorkoutEntry>.from(current.entries);
    updatedEntries[entryIndex] = entry.copyWith(sets: updatedSets);
    _activeWorkout = current.copyWith(entries: updatedEntries);
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

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
    if (!target.isCompleted) {
      return _completeSetAt(
        entryIndex,
        setIndex,
        startRestTimer: true,
        playFeedback: true,
        advanceSelectedEntry: false,
      );
    }

    final updatedSet = target.copyWith(isCompleted: false);
    final updatedSets = List<ExerciseSet>.from(entry.sets);
    updatedSets[setIndex] = updatedSet;

    final updatedEntries = List<WorkoutEntry>.from(current.entries);
    updatedEntries[entryIndex] = entry.copyWith(sets: updatedSets);
    _activeWorkout = current.copyWith(entries: updatedEntries);
    _sessionPrs.remove(updatedSet.id);

    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
    return const <RecordKind>[];
  }

  /// Marks the next incomplete set completed (starting from the currently
  /// selected entry). Notification actions call this with
  /// [startRestTimer] set to `false`.
  List<RecordKind> completeNextSet({bool startRestTimer = true}) {
    final nextLoc = _findNextIncompleteSet();
    if (nextLoc == null) {
      _syncLiveNotification();
      return const <RecordKind>[];
    }
    return _completeSetAt(
      nextLoc.$1,
      nextLoc.$2,
      startRestTimer: startRestTimer,
      playFeedback: true,
      advanceSelectedEntry: true,
    );
  }

  List<RecordKind> _completeSetAt(
    int entryIndex,
    int setIndex, {
    required bool startRestTimer,
    required bool playFeedback,
    required bool advanceSelectedEntry,
  }) {
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
    final updatedSet = target.copyWith(isCompleted: true);

    final updatedSets = List<ExerciseSet>.from(entry.sets);
    updatedSets[setIndex] = updatedSet;

    final updatedEntries = List<WorkoutEntry>.from(current.entries);
    updatedEntries[entryIndex] = entry.copyWith(sets: updatedSets);
    _activeWorkout = current.copyWith(entries: updatedEntries);

    if (playFeedback) {
      _soundService.playSetTick(
        soundEnabled: _preferences.soundEnabled,
        hapticsEnabled: _preferences.hapticsEnabled,
      );
    }

    List<RecordKind> earnedPrs = const <RecordKind>[];
    if (current.countForProgression && entry.countForProgression) {
      final baseline = _prService.baselineFor(
        entry.exerciseId,
        _history,
        exerciseName: entry.exerciseName,
        formula: _preferences.oneRmFormula,
      );
      earnedPrs = _prService.evaluateSet(
        updatedSet,
        baseline,
        formula: _preferences.oneRmFormula,
      );
      if (earnedPrs.isNotEmpty) {
        _sessionPrs[updatedSet.id] = earnedPrs;
        if (playFeedback && _preferences.prSoundEnabled) {
          _soundService.playPrChime(soundEnabled: _preferences.soundEnabled);
        }
      }
    }

    if (advanceSelectedEntry) {
      final upcoming = _findNextIncompleteSet(preferredEntryIndex: entryIndex);
      if (upcoming != null) {
        _selectedEntryIndex = upcoming.$1;
      }
    }

    if (startRestTimer && entry.restSeconds > 0) {
      startRest(entry.restSeconds);
    } else {
      _persistActiveSession();
      _syncLiveNotification();
      notifyListeners();
    }
    return earnedPrs;
  }

  (int, int)? _findNextIncompleteSet({int? preferredEntryIndex}) {
    final current = _activeWorkout;
    if (current == null || current.entries.isEmpty) return null;
    final entries = current.entries;
    final startIdx =
        (preferredEntryIndex ?? _selectedEntryIndex).clamp(0, entries.length - 1);
    for (var offset = 0; offset < entries.length; offset++) {
      final eIdx = (startIdx + offset) % entries.length;
      final sets = entries[eIdx].sets;
      for (var sIdx = 0; sIdx < sets.length; sIdx++) {
        if (!sets[sIdx].isCompleted) {
          return (eIdx, sIdx);
        }
      }
    }
    return null;
  }

  // ── Wall-Clock Anchored Rest Countdown Timer ─────────────────────────────

  void startRest(int seconds) {
    if (seconds <= 0) return;
    _restTimer?.cancel();
    _restTotalSeconds = seconds;
    _restRemainingSeconds = seconds;
    _restEndsAt = DateTime.now().add(Duration(seconds: seconds));
    _countdownBeepedSeconds.clear();
    _startRestTicker();
    _scheduleRestNotification();
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

  void _startRestTicker() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_isPaused || _restEndsAt == null) return;
      final remainingMs = _restEndsAt!.difference(DateTime.now()).inMilliseconds;
      final next = (remainingMs / 1000.0).ceil();
      if (next <= 0) {
        _restRemainingSeconds = 0;
        _restTotalSeconds = 0;
        _restEndsAt = null;
        _restCompletedNonce++;
        timer.cancel();
        _cancelRestNotification();
        _soundService.playRestEndChime(
          kind: _preferences.restSound,
          soundEnabled: _preferences.soundEnabled,
          hapticsEnabled: _preferences.hapticsEnabled,
        );
        _persistActiveSession();
        _syncLiveNotification();
        notifyListeners();
      } else if (next != _restRemainingSeconds) {
        _restRemainingSeconds = next;
        if (next <= 3 &&
            next >= 1 &&
            !_countdownBeepedSeconds.contains(next)) {
          _countdownBeepedSeconds.add(next);
          _soundService.playCountdownTick(
            soundEnabled: _preferences.soundEnabled,
          );
        }
        notifyListeners();
      }
    });
  }

  void addRest(int deltaSeconds) {
    if (!isResting) return;
    final next = _restRemainingSeconds + deltaSeconds;
    if (next <= 0) {
      skipRest();
    } else {
      _restRemainingSeconds = next;
      if (_restEndsAt != null) {
        _restEndsAt = _restEndsAt!.add(Duration(seconds: deltaSeconds));
      } else {
        _restEndsAt = DateTime.now().add(Duration(seconds: next));
      }
      if (next > _restTotalSeconds) _restTotalSeconds = next;
      _scheduleRestNotification();
      _persistActiveSession();
      _syncLiveNotification();
      notifyListeners();
    }
  }

  void skipRest() {
    _restTimer?.cancel();
    _restRemainingSeconds = 0;
    _restTotalSeconds = 0;
    _restEndsAt = null;
    _countdownBeepedSeconds.clear();
    _cancelRestNotification();
    _persistActiveSession();
    _syncLiveNotification();
    notifyListeners();
  }

  Future<WorkoutLog?> finishWorkout() async {
    final current = _activeWorkout;
    if (current == null) return null;

    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _cancelRestNotification();
    _stopLiveNotification();
    await _repository.clearActiveSession();

    final completed = current.copyWith(
      finishedAt: HealthRecordMetadata.nowUtcIso(),
      durationSeconds: _elapsedSeconds,
    );

    await _repository.saveWorkout(completed);
    _soundService.playWorkoutFinish(
      soundEnabled: _preferences.soundEnabled,
      hapticsEnabled: _preferences.hapticsEnabled,
    );
    _history = <WorkoutLog>[completed, ..._history];

    await _advanceRotationAfterWorkout(completed);
    _syncNextWorkoutShortcut();

    _activeWorkout = null;
    _elapsedSeconds = 0;
    _isPaused = false;
    _workoutStartedAt = null;
    _pausedAt = null;
    _accumulatedPaused = Duration.zero;
    _restRemainingSeconds = 0;
    _restTotalSeconds = 0;
    _restEndsAt = null;
    _sessionPrs.clear();
    _selectedEntryIndex = 0;
    _isInActiveWorkoutScreen = false;
    _notifyWakeLock();
    notifyListeners();

    if (_healthConnectSettings.enabled && _healthConnectSettings.writeWorkouts) {
      unawaited(_pushWorkoutToHealthConnect(completed));
    }

    return completed;
  }

  Future<void> _advanceRotationAfterWorkout(WorkoutLog completed) async {
    final seq = _preferences.rotationSequence;
    var updatedPrefs = _preferences;

    if (seq.isNotEmpty) {
      final completedSet = Set<int>.from(updatedPrefs.rotationCompletedIndices);
      int? matchedIndex;
      if (completed.templateId != null) {
        for (var i = 0; i < seq.length; i++) {
          if (seq[i] == completed.templateId && !completedSet.contains(i)) {
            matchedIndex = i;
            break;
          }
        }
      }
      if (matchedIndex != null) {
        completedSet.add(matchedIndex);
        // Check if every routine stop in the loop is now done -> start new round.
        final allRoutineIndices = <int>[
          for (var i = 0; i < seq.length; i++)
            if (seq[i] != restStopId) i,
        ];
        final allDone = allRoutineIndices.isNotEmpty &&
            allRoutineIndices.every(completedSet.contains);
        updatedPrefs = updatedPrefs.copyWith(
          rotationCompletedIndices:
              allDone ? const <int>[] : (completedSet.toList()..sort()),
        );
      }
    }

    if (_templates.isNotEmpty) {
      final nextIdx = (updatedPrefs.rotationIndex + 1) % _templates.length;
      updatedPrefs = updatedPrefs.copyWith(rotationIndex: nextIdx);
    }

    if (updatedPrefs != _preferences) {
      await savePreferences(updatedPrefs);
    }
  }

  void discardWorkout() {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _cancelRestNotification();
    _stopLiveNotification();
    unawaited(_repository.clearActiveSession());
    _activeWorkout = null;
    _elapsedSeconds = 0;
    _isPaused = false;
    _workoutStartedAt = null;
    _pausedAt = null;
    _accumulatedPaused = Duration.zero;
    _restRemainingSeconds = 0;
    _restTotalSeconds = 0;
    _restEndsAt = null;
    _sessionPrs.clear();
    _selectedEntryIndex = 0;
    _isInActiveWorkoutScreen = false;
    _notifyWakeLock();
    notifyListeners();
  }

  // ── Rotation Loop & Fixed Week Schedule ──────────────────────────────────

  List<String> get rotationSequence => _preferences.rotationSequence;

  /// Index in [rotationSequence] that is "Up next", or `null` if loop has no routines.
  int? get nextRotationStopIndex {
    final seq = _preferences.rotationSequence;
    if (seq.isEmpty) return null;
    final done = _preferences.rotationCompletedIndices.toSet();
    for (var i = 0; i < seq.length; i++) {
      if (seq[i] != restStopId && !done.contains(i)) {
        return i;
      }
    }
    for (var i = 0; i < seq.length; i++) {
      if (seq[i] != restStopId) return i;
    }
    return null;
  }

  int get completedInCurrentRound {
    final seq = _preferences.rotationSequence;
    return _preferences.rotationCompletedIndices
        .where((i) => i >= 0 && i < seq.length && seq[i] != restStopId)
        .length;
  }

  int get totalRoutinesInLoop =>
      _preferences.rotationSequence.where((id) => id != restStopId).length;

  Future<void> addStopToRotation(String templateIdOrRest) async {
    final nextSeq = <String>[..._preferences.rotationSequence, templateIdOrRest];
    await savePreferences(_preferences.copyWith(rotationSequence: nextSeq));
  }

  Future<RotationSnapshot> removeStopFromRotation(int index) async {
    final seq = List<String>.from(_preferences.rotationSequence);
    final completed = List<int>.from(_preferences.rotationCompletedIndices);
    final snap = RotationSnapshot(
      sequence: List<String>.from(seq),
      completedIndices: List<int>.from(completed),
      rotationIndex: _preferences.rotationIndex,
    );
    if (index < 0 || index >= seq.length) return snap;

    seq.removeAt(index);
    final shiftedCompleted = completed
        .where((i) => i != index)
        .map((i) => i > index ? i - 1 : i)
        .toList();

    await savePreferences(
      _preferences.copyWith(
        rotationSequence: seq,
        rotationCompletedIndices: shiftedCompleted,
      ),
    );
    return snap;
  }

  Future<void> restoreRotationSnapshot(RotationSnapshot snapshot) async {
    await savePreferences(
      _preferences.copyWith(
        rotationSequence: snapshot.sequence,
        rotationCompletedIndices: snapshot.completedIndices,
        rotationIndex: snapshot.rotationIndex,
      ),
    );
  }

  Future<void> reorderRotation(
    int oldIndex,
    int newIndex, {
    bool preAdjusted = false,
  }) async {
    final seq = List<String>.from(_preferences.rotationSequence);
    if (oldIndex < 0 || oldIndex >= seq.length) return;
    if (!preAdjusted && newIndex > oldIndex) newIndex--;
    newIndex = newIndex.clamp(0, seq.length - 1);
    final moved = seq.removeAt(oldIndex);
    seq.insert(newIndex, moved);
    await savePreferences(_preferences.copyWith(rotationSequence: seq));
  }

  Future<void> resetRotation() async {
    await savePreferences(
      _preferences.copyWith(
        rotationIndex: 0,
        rotationCompletedIndices: const <int>[],
      ),
    );
  }

  List<WorkoutTemplate> routinesForWeekday(int weekday) {
    final ids = _preferences.weeklySchedule[weekday] ?? const <String>[];
    final byId = <String, WorkoutTemplate>{
      for (final t in _templates) t.id: t,
    };
    return ids.map((id) => byId[id]).whereType<WorkoutTemplate>().toList();
  }

  List<int> assignedWeekdaysForTemplate(String templateId) {
    final days = <int>[];
    for (var d = 1; d <= 7; d++) {
      final list = _preferences.weeklySchedule[d] ?? const <String>[];
      if (list.contains(templateId)) days.add(d);
    }
    return days;
  }

  Future<void> setWeekdaySchedule(
    int weekday,
    List<String> templateIds, {
    bool? trainSeparately,
  }) async {
    final nextSchedule =
        Map<int, List<String>>.from(_preferences.weeklySchedule);
    if (templateIds.isEmpty) {
      nextSchedule.remove(weekday);
    } else {
      nextSchedule[weekday] = List<String>.from(templateIds);
    }

    final nextApart =
        Map<int, bool>.from(_preferences.weeklyTrainSeparately);
    if (trainSeparately != null) {
      nextApart[weekday] = trainSeparately;
    }

    await savePreferences(
      _preferences.copyWith(
        weeklySchedule: nextSchedule,
        weeklyTrainSeparately: nextApart,
      ),
    );
  }

  Future<void> setDayOverride(String dateIso, String? templateIdOrRest) async {
    final next = Map<String, String>.from(_preferences.dayOverrides);
    if (templateIdOrRest == null || templateIdOrRest.isEmpty) {
      next.remove(dateIso);
    } else {
      next[dateIso] = templateIdOrRest;
    }
    await savePreferences(_preferences.copyWith(dayOverrides: next));
  }

  // ── Routines, Programmes, Exercises, History ─────────────────────────────

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
    _syncNextWorkoutShortcut();
    notifyListeners();
  }

  Future<WorkoutTemplate> createNewRoutine({String name = 'New routine'}) async {
    final template = WorkoutTemplate.create(
      name: name,
      iconKey: 'overhead_press',
      progressionPolicy: 'linear',
      routineType: 'regular',
      sortOrder: _templates.length,
      entries: const <WorkoutTemplateEntry>[],
    );
    await saveTemplate(template);
    return template;
  }

  Future<WorkoutTemplate> duplicateTemplate(
    String templateId, {
    bool insertBelowOriginal = true,
  }) async {
    final sourceIdx = _templates.indexWhere((t) => t.id == templateId);
    final source = sourceIdx >= 0
        ? _templates[sourceIdx]
        : _templates.first;
    final copy = WorkoutTemplate.create(
      name: '${source.name} (Copy)',
      goal: source.goal,
      split: source.split,
      description: source.description,
      folder: source.folder,
      isFavorite: false,
      iconKey: source.iconKey,
      progressionPolicy: source.progressionPolicy,
      routineType: source.routineType,
      isDeload: source.isDeload,
      circuitConfig: source.circuitConfig != null
          ? Map<String, dynamic>.from(source.circuitConfig!)
          : null,
      entries: List<WorkoutTemplateEntry>.from(source.entries),
    );

    final list = List<WorkoutTemplate>.from(_templates);
    if (insertBelowOriginal && sourceIdx >= 0) {
      list.insert(sourceIdx + 1, copy);
    } else {
      list.add(copy);
    }
    for (var i = 0; i < list.length; i++) {
      final updated = list[i].copyWith(sortOrder: i);
      list[i] = updated;
      await _repository.saveTemplate(updated);
    }
    _templates = list;
    notifyListeners();
    return list.firstWhere((t) => t.id == copy.id);
  }

  Future<void> reorderTemplates(
    int oldIndex,
    int newIndex, {
    bool preAdjusted = false,
  }) async {
    final list = List<WorkoutTemplate>.from(_templates);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (!preAdjusted && newIndex > oldIndex) newIndex--;
    newIndex = newIndex.clamp(0, list.length - 1);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (var i = 0; i < list.length; i++) {
      final updated = list[i].copyWith(sortOrder: i);
      list[i] = updated;
      await _repository.saveTemplate(updated);
    }
    _templates = list;
    notifyListeners();
  }

  Future<RoutineDeleteSnapshot?> deleteTemplateWithSnapshot(
    String templateId,
  ) async {
    final idx = _templates.indexWhere((t) => t.id == templateId);
    if (idx < 0) return null;
    final target = _templates[idx];

    final snapshot = RoutineDeleteSnapshot(
      template: target,
      index: idx,
      weeklySchedule: _preferences.weeklySchedule.map(
        (k, v) => MapEntry<int, List<String>>(k, List<String>.from(v)),
      ),
      rotationSequence: List<String>.from(_preferences.rotationSequence),
      rotationCompletedIndices:
          List<int>.from(_preferences.rotationCompletedIndices),
      dayOverrides: Map<String, String>.from(_preferences.dayOverrides),
    );

    await _repository.deleteTemplate(templateId);
    _templates = _templates.where((t) => t.id != templateId).toList();

    final nextWeekly = <int, List<String>>{};
    for (final entry in _preferences.weeklySchedule.entries) {
      final filtered = entry.value.where((id) => id != templateId).toList();
      if (filtered.isNotEmpty) nextWeekly[entry.key] = filtered;
    }

    final oldSeq = _preferences.rotationSequence;
    final nextSeq = <String>[];
    final nextCompleted = <int>[];
    final doneSet = _preferences.rotationCompletedIndices.toSet();
    for (var i = 0; i < oldSeq.length; i++) {
      if (oldSeq[i] == templateId) continue;
      if (doneSet.contains(i)) nextCompleted.add(nextSeq.length);
      nextSeq.add(oldSeq[i]);
    }

    final nextOverrides = Map<String, String>.from(_preferences.dayOverrides)
      ..removeWhere((_, v) => v == templateId);

    await savePreferences(
      _preferences.copyWith(
        weeklySchedule: nextWeekly,
        rotationSequence: nextSeq,
        rotationCompletedIndices: nextCompleted,
        dayOverrides: nextOverrides,
      ),
    );
    return snapshot;
  }

  Future<void> restoreTemplateSnapshot(RoutineDeleteSnapshot snapshot) async {
    final list = List<WorkoutTemplate>.from(_templates);
    final insertIdx = snapshot.index.clamp(0, list.length);
    list.insert(insertIdx, snapshot.template);
    for (var i = 0; i < list.length; i++) {
      final updated = list[i].copyWith(sortOrder: i);
      list[i] = updated;
      await _repository.saveTemplate(updated);
    }
    _templates = list;

    await savePreferences(
      _preferences.copyWith(
        weeklySchedule: snapshot.weeklySchedule,
        rotationSequence: snapshot.rotationSequence,
        rotationCompletedIndices: snapshot.rotationCompletedIndices,
        dayOverrides: snapshot.dayOverrides,
      ),
    );
  }

  Future<void> deleteTemplate(String id) async {
    await deleteTemplateWithSnapshot(id);
  }

  Future<bool> toggleTemplateFavorite(String templateId) async {
    final t = _templates.where((x) => x.id == templateId).firstOrNull;
    if (t == null) return false;
    final nextVal = !t.isFavorite;
    await saveTemplate(t.copyWith(isFavorite: nextVal));
    return nextVal;
  }

  Future<void> toggleExerciseFavorite(String exerciseId) async {
    final favs = List<String>.from(_preferences.favoriteExerciseIds);
    if (favs.contains(exerciseId)) {
      favs.remove(exerciseId);
    } else {
      favs.add(exerciseId);
    }
    await savePreferences(_preferences.copyWith(favoriteExerciseIds: favs));
  }

  bool isFolderOpen(String folderName) {
    final key = folderName.trim().toLowerCase();
    if (_preferences.folderOpenState.containsKey(key)) {
      return _preferences.folderOpenState[key]!;
    }
    return key != 'archive';
  }

  Future<void> setFolderOpen(String folderName, bool open) async {
    final key = folderName.trim().toLowerCase();
    final next = Map<String, bool>.from(_preferences.folderOpenState);
    next[key] = open;
    await savePreferences(_preferences.copyWith(folderOpenState: next));
  }

  Future<WorkoutTemplate> createRoutineFromWorkoutLog(WorkoutLog log) async {
    final entries = log.entries.map((e) {
      final work = e.sets.where((s) => !s.isWarmup).toList();
      final setsCount = work.isNotEmpty ? work.length : e.sets.length;
      final first = work.isNotEmpty
          ? work.first
          : (e.sets.isNotEmpty ? e.sets.first : null);
      return WorkoutTemplateEntry(
        exerciseId: e.exerciseId,
        exerciseName: e.exerciseName,
        bodyPart: e.bodyPart,
        equipment: e.equipment,
        mode: e.mode,
        targetSets: setsCount > 0 ? setsCount : 3,
        targetReps: first != null && first.reps > 0 ? first.reps : 10,
        defaultWeight: first?.weight ?? 0,
        restSeconds: e.restSeconds,
        supersetId: e.supersetId,
        progressionPolicy: e.progressionMode,
      );
    }).toList();

    final created = WorkoutTemplate.create(
      name: log.title,
      sortOrder: _templates.length,
      entries: entries,
    );
    await saveTemplate(created);
    return created;
  }

  Future<void> loadStarterPlan(
    List<WorkoutTemplate> planTemplates, {
    Map<int, List<String>>? weekdayMap,
  }) async {
    for (var i = 0; i < planTemplates.length; i++) {
      final t = planTemplates[i].copyWith(sortOrder: _templates.length + i);
      await saveTemplate(t);
    }
    await savePreferences(
      _preferences.copyWith(
        rotationSequence: planTemplates.map((t) => t.id).toList(),
        rotationCompletedIndices: const <int>[],
        weeklySchedule: weekdayMap ?? _preferences.weeklySchedule,
      ),
    );
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

  Future<void> saveWeighIn(WeighIn weighIn) async {
    await _repository.saveWeighIn(weighIn);
    _weighIns = await _repository.loadWeighIns();
    notifyListeners();
    if (_healthConnectSettings.enabled &&
        _healthConnectSettings.syncBodyMetrics &&
        weighIn.source != 'health_connect') {
      unawaited(_pushWeighInToHealthConnect(weighIn));
    }
  }

  Future<void> deleteWeighIn(String id) async {
    await _repository.deleteWeighIn(id);
    _weighIns = _weighIns.where((w) => w.id != id).toList();
    notifyListeners();
  }

  Future<void> saveMeasurement(BodyMeasurement measurement) async {
    await _repository.saveMeasurement(measurement);
    _measurements = await _repository.loadMeasurements();
    notifyListeners();
    if (_healthConnectSettings.enabled &&
        _healthConnectSettings.syncBodyMetrics &&
        measurement.bodyFatPct != null &&
        measurement.source != 'health_connect') {
      unawaited(_pushBodyFatToHealthConnect(measurement));
    }
  }

  Future<void> deleteMeasurement(String id) async {
    await _repository.deleteMeasurement(id);
    _measurements = _measurements.where((m) => m.id != id).toList();
    notifyListeners();
  }

  Future<void> saveProgramme(Programme programme) async {
    await _repository.saveProgramme(programme);
    _programmes = await _repository.loadProgrammes();
    _syncNextWorkoutShortcut();
    notifyListeners();
  }

  Future<void> activateProgramme(String programmeId) async {
    for (final p in _programmes) {
      final shouldBeActive = p.id == programmeId;
      if (p.isActive != shouldBeActive) {
        await _repository.saveProgramme(p.copyWith(isActive: shouldBeActive));
      }
    }
    _programmes = await _repository.loadProgrammes();
    _syncNextWorkoutShortcut();
    notifyListeners();
  }

  /// Returns today's scheduled [WorkoutTemplate] from day overrides, fixed-week
  /// schedule / active [Programme], or the next template in the rotation loop.
  WorkoutTemplate? todaysScheduledTemplate([DateTime? now]) {
    final targetDate = now ?? DateTime.now();
    final dateIso =
        '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    final overrideId = _preferences.dayOverrides[dateIso];
    if (overrideId != null) {
      if (overrideId == restStopId) return null;
      final match = _templates.where((t) => t.id == overrideId).firstOrNull;
      if (match != null) return match;
    }

    if (_preferences.trainingMode == 'fixed_week') {
      final active = _programmes.where((p) => p.isActive).firstOrNull;
      if (active != null) {
        final templateId = active.weekdayToTemplateId[targetDate.weekday];
        if (templateId != null) {
          final match = _templates.where((t) => t.id == templateId).firstOrNull;
          if (match != null) return match;
        }
      }
      final dayRoutines = routinesForWeekday(targetDate.weekday);
      return dayRoutines.isNotEmpty ? dayRoutines.first : null;
    }

    final stopIdx = nextRotationStopIndex;
    if (stopIdx != null && stopIdx < _preferences.rotationSequence.length) {
      final stopId = _preferences.rotationSequence[stopIdx];
      final match = _templates.where((t) => t.id == stopId).firstOrNull;
      if (match != null) return match;
    }
    if (_templates.isEmpty) return null;
    final idx = _preferences.rotationIndex % _templates.length;
    return _templates[idx];
  }

  Future<void> saveProgressPhoto(ProgressPhoto photo) async {
    await _repository.saveProgressPhoto(photo);
    _progressPhotos = await _repository.loadProgressPhotos();
    notifyListeners();
  }

  Future<void> deleteProgressPhoto(String id) async {
    await _repository.deleteProgressPhoto(id);
    _progressPhotos = _progressPhotos.where((p) => p.id != id).toList();
    notifyListeners();
  }

  void addDropToSet(int entryIndex, int setIndex, SetDrop drop) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex < 0 ||
        entryIndex >= current.entries.length) {
      return;
    }
    final entry = current.entries[entryIndex];
    if (setIndex < 0 || setIndex >= entry.sets.length) return;
    final target = entry.sets[setIndex];
    updateSet(
      entryIndex,
      setIndex,
      setType: SetType.dropset,
      drops: <SetDrop>[...target.drops, drop],
    );
  }

  void addClusterToSet(int entryIndex, int setIndex, SetCluster cluster) {
    final current = _activeWorkout;
    if (current == null ||
        entryIndex < 0 ||
        entryIndex >= current.entries.length) {
      return;
    }
    final entry = current.entries[entryIndex];
    if (setIndex < 0 || setIndex >= entry.sets.length) return;
    final target = entry.sets[setIndex];
    updateSet(
      entryIndex,
      setIndex,
      setType: SetType.cluster,
      clusters: <SetCluster>[...target.clusters, cluster],
    );
  }

  Future<void> deleteProgramme(String id) async {
    await _repository.deleteProgramme(id);
    _programmes = _programmes.where((p) => p.id != id).toList();
    notifyListeners();
  }

  Future<void> savePreferences(OpenGymPreferences prefs) async {
    await _repository.savePreferences(prefs);
    _preferences = prefs;
    _notifyWakeLock();
    _syncNextWorkoutShortcut();
    if (_activeWorkout != null) {
      _syncLiveNotification();
    }
    notifyListeners();
  }

  // ── Optional Server Connection & Backup ──────────────────────────────────

  Future<void> connectServerWithCode({
    required String serverUrl,
    required String code,
    String? cfAccessClientId,
    String? cfAccessClientSecret,
  }) async {
    final normalized = OpenGymServerClient.normalizeServerUrl(serverUrl);
    if (normalized == null) {
      throw const OpenGymServerException('Invalid server URL');
    }
    final token = await _serverClient.pairWithCode(
      normalized,
      code,
      cfAccessClientId: cfAccessClientId,
      cfAccessClientSecret: cfAccessClientSecret,
    );
    final config = ServerConnectionConfig(
      serverUrl: normalized,
      authToken: token,
      cfAccessClientId: cfAccessClientId,
      cfAccessClientSecret: cfAccessClientSecret,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
    );
    await _repository.saveServerConnection(config);
    _serverConnection = config;
    notifyListeners();
  }

  Future<void> connectServerWithPassword({
    required String serverUrl,
    required String username,
    required String password,
    String? cfAccessClientId,
    String? cfAccessClientSecret,
  }) async {
    final normalized = OpenGymServerClient.normalizeServerUrl(serverUrl);
    if (normalized == null) {
      throw const OpenGymServerException('Invalid server URL');
    }
    final token = await _serverClient.loginWithPassword(
      normalized,
      username: username,
      password: password,
      cfAccessClientId: cfAccessClientId,
      cfAccessClientSecret: cfAccessClientSecret,
    );
    final config = ServerConnectionConfig(
      serverUrl: normalized,
      authToken: token,
      cfAccessClientId: cfAccessClientId,
      cfAccessClientSecret: cfAccessClientSecret,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
    );
    await _repository.saveServerConnection(config);
    _serverConnection = config;
    notifyListeners();
  }

  Future<void> disconnectServer() async {
    await _repository.clearServerConnection();
    _serverConnection = null;
    notifyListeners();
  }

  Future<SyncResult> syncNow() async {
    final config = _serverConnection;
    if (config == null || !config.isConnected) {
      throw const OpenGymServerException('No server connected');
    }
    _isSyncing = true;
    notifyListeners();
    try {
      final result = await _syncService.syncWithServer(config);
      final updated = config.copyWith(lastSyncedAt: result.syncedAt);
      await _repository.saveServerConnection(updated);
      _serverConnection = updated;
      await _reloadAllFromStore();
      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<String> exportBackupJson() => _syncService.exportBackupJson();

  Future<int> importBackupJson(String rawJson) async {
    final count = await _syncService.importBackupJson(rawJson);
    await _reloadAllFromStore();
    notifyListeners();
    return count;
  }

  Future<List<WorkoutTemplate>> fetchCommunityRoutines() async {
    final config = _serverConnection;
    if (config == null || !config.isConnected) {
      throw const OpenGymServerException('Connect to a server first');
    }
    final raw = await _serverClient.fetchCommunityRoutines(config);
    return raw.map(WorkoutTemplate.fromJson).toList();
  }

  Future<void> backupToWebDav({
    required String fileUrl,
    required String username,
    required String password,
    WebDavClient? client,
  }) async {
    final json = await exportBackupJson();
    await (client ?? WebDavClient()).uploadBackup(
      fileUrl: fileUrl,
      username: username,
      password: password,
      jsonPayload: json,
    );
  }

  Future<int> restoreFromWebDav({
    required String fileUrl,
    required String username,
    required String password,
    WebDavClient? client,
  }) async {
    final json = await (client ?? WebDavClient()).downloadBackup(
      fileUrl: fileUrl,
      username: username,
      password: password,
    );
    return importBackupJson(json);
  }

  List<ExerciseRecordBaseline> get allPersonalRecords =>
      _prService.allRecords(_history, formula: _preferences.oneRmFormula);

  double get totalLifetimeVolume =>
      _history.fold<double>(0, (sum, log) => sum + log.totalVolume);

  ({int currentWeeks, int longestWeeks}) get weeklyStreak =>
      _analyticsService.weeklyStreak(_history);

  Map<String, int> get weeklySetsByBodyPart =>
      _analyticsService.weeklySetsByBodyPart(_history);

  // ── Android Health Connect ───────────────────────────────────────────────

  Future<void> saveHealthConnectSettings(HealthConnectSettings settings) async {
    _healthConnectSettings = settings;
    await _repository.saveHealthConnectSettings(settings);
    notifyListeners();
  }

  Future<bool> connectHealthConnect() async {
    _healthConnectError = null;
    _healthConnectSdkStatus = await _healthConnect.checkAvailability();
    if (_healthConnectSdkStatus != HealthConnectSdkStatus.available) {
      notifyListeners();
      return false;
    }
    final perms = _healthConnect.permissionsFor(_healthConnectSettings);
    final granted = await _healthConnect.requestPermissions(perms);
    if (granted) {
      await saveHealthConnectSettings(
        _healthConnectSettings.copyWith(enabled: true),
      );
    } else {
      _healthConnectError = 'Health Connect permissions were not granted.';
      notifyListeners();
    }
    return granted;
  }

  Future<HealthConnectSyncResult?> syncHealthConnect({int days = 30}) async {
    if (_healthConnectSyncing) return null;
    _healthConnectSyncing = true;
    _healthConnectError = null;
    notifyListeners();

    try {
      _healthConnectSdkStatus = await _healthConnect.checkAvailability();
      if (_healthConnectSdkStatus != HealthConnectSdkStatus.available) {
        return null;
      }

      final now = DateTime.now().toUtc();
      final start = now.subtract(Duration(days: days));
      final raw = await _healthConnect.readRecentData(start: start, end: now);

      int importedWeighIns = 0;
      int importedBodyFats = 0;

      if (_healthConnectSettings.syncBodyMetrics) {
        final existingHcIds = _weighIns
            .map((w) => w.healthConnectId)
            .whereType<String>()
            .toSet();
        final existingDates = _weighIns.map((w) => w.date).toSet();

        for (final w in raw.weights) {
          final hcId = w['id'] as String?;
          final kg = (w['weightKg'] as num?)?.toDouble();
          final timeIso = w['timeIso'] as String?;
          if (kg == null || kg <= 0 || timeIso == null) continue;
          if (hcId != null && existingHcIds.contains(hcId)) continue;
          final dateStr = _localDateString(timeIso);
          if (dateStr == null || existingDates.contains(dateStr)) continue;

          final entry = WeighIn.create(
            date: dateStr,
            weightKg: double.parse(kg.toStringAsFixed(1)),
            source: 'health_connect',
            healthConnectId: hcId,
          );
          await _repository.saveWeighIn(entry);
          if (hcId != null) existingHcIds.add(hcId);
          existingDates.add(dateStr);
          importedWeighIns++;
        }

        final existingBfHcIds = _measurements
            .map((m) => m.healthConnectId)
            .whereType<String>()
            .toSet();
        final existingBfDates = _measurements
            .where((m) => m.bodyFatPct != null)
            .map((m) => m.date)
            .toSet();

        for (final bf in raw.bodyFats) {
          final hcId = bf['id'] as String?;
          final pct = (bf['percentage'] as num?)?.toDouble();
          final timeIso = bf['timeIso'] as String?;
          if (pct == null || pct <= 0 || timeIso == null) continue;
          if (hcId != null && existingBfHcIds.contains(hcId)) continue;
          final dateStr = _localDateString(timeIso);
          if (dateStr == null || existingBfDates.contains(dateStr)) continue;

          final entry = BodyMeasurement.create(
            date: dateStr,
            bodyFatPct: double.parse(pct.toStringAsFixed(1)),
            source: 'health_connect',
            healthConnectId: hcId,
          );
          await _repository.saveMeasurement(entry);
          if (hcId != null) existingBfHcIds.add(hcId);
          existingBfDates.add(dateStr);
          importedBodyFats++;
        }

        if (importedWeighIns > 0) {
          _weighIns = await _repository.loadWeighIns();
        }
        if (importedBodyFats > 0) {
          _measurements = await _repository.loadMeasurements();
        }
      }

      int externalCount = 0;
      int enrichedCount = 0;

      if (_healthConnectSettings.readExternalActivity) {
        final externals = _healthConnect.buildExternalWorkouts(raw);
        for (final ext in externals) {
          await _repository.saveExternalWorkout(ext);
          externalCount++;
        }
        _externalWorkouts = await _repository.loadExternalWorkouts();

        final dailies = _healthConnect.buildDailyMetrics(raw);
        for (final day in dailies) {
          await _repository.saveDailyHealthMetrics(day);
        }
        _dailyHealthMetrics = await _repository.loadDailyHealthMetrics();

        for (final log in _history) {
          final s = DateTime.tryParse(log.startedAt);
          final e = log.finishedAt != null
              ? DateTime.tryParse(log.finishedAt!)
              : null;
          if (s == null || e == null) continue;
          final metrics = _healthConnect.computeWindowMetrics(raw, s, e);
          if (metrics.caloriesKcal != null || metrics.avgHeartRateBpm != null) {
            final updated = log.copyWith(
              caloriesKcal: metrics.caloriesKcal ?? log.caloriesKcal,
              avgHeartRateBpm: metrics.avgHeartRateBpm ?? log.avgHeartRateBpm,
              maxHeartRateBpm: metrics.maxHeartRateBpm ?? log.maxHeartRateBpm,
            );
            await _repository.saveWorkout(updated);
            enrichedCount++;
          }
        }
        if (enrichedCount > 0) {
          _history = await _repository.loadWorkouts();
        }
      }

      final syncedAt = HealthRecordMetadata.nowUtcIso();
      await saveHealthConnectSettings(
        _healthConnectSettings.copyWith(lastSyncedAt: syncedAt),
      );
      return HealthConnectSyncResult(
        importedWeighIns: importedWeighIns,
        importedBodyFats: importedBodyFats,
        externalWorkouts: externalCount,
        enrichedWorkouts: enrichedCount,
        syncedAt: syncedAt,
      );
    } catch (e) {
      _healthConnectError = e.toString();
      return null;
    } finally {
      _healthConnectSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _pushWorkoutToHealthConnect(WorkoutLog log) async {
    try {
      final hcId = await _healthConnect.writeWorkout(log);
      if (hcId != null && hcId.isNotEmpty) {
        final updated = log.copyWith(healthConnectId: hcId);
        await _repository.saveWorkout(updated);
        _history = _history
            .map((w) => w.id == updated.id ? updated : w)
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _healthConnectError = 'Workout write failed: $e';
      notifyListeners();
    }
  }

  Future<void> _pushWeighInToHealthConnect(WeighIn weighIn) async {
    try {
      final hcId = await _healthConnect.writeWeighIn(weighIn);
      if (hcId != null && hcId.isNotEmpty) {
        final updated = WeighIn(
          id: weighIn.id,
          date: weighIn.date,
          weightKg: weighIn.weightKg,
          note: weighIn.note,
          source: weighIn.source,
          healthConnectId: hcId,
          updatedAt: HealthRecordMetadata.nowUtcIso(),
          isSynced: weighIn.isSynced,
        );
        await _repository.saveWeighIn(updated);
        _weighIns = await _repository.loadWeighIns();
        notifyListeners();
      }
    } catch (e) {
      _healthConnectError = 'Weight write failed: $e';
      notifyListeners();
    }
  }

  Future<void> _pushBodyFatToHealthConnect(BodyMeasurement measurement) async {
    try {
      final hcId = await _healthConnect.writeBodyFat(measurement);
      if (hcId != null && hcId.isNotEmpty) {
        final updated = BodyMeasurement(
          id: measurement.id,
          date: measurement.date,
          bodyFatPct: measurement.bodyFatPct,
          chestCm: measurement.chestCm,
          waistCm: measurement.waistCm,
          hipsCm: measurement.hipsCm,
          armsCm: measurement.armsCm,
          thighsCm: measurement.thighsCm,
          calvesCm: measurement.calvesCm,
          bpSys: measurement.bpSys,
          bpDia: measurement.bpDia,
          pulse: measurement.pulse,
          note: measurement.note,
          source: measurement.source,
          healthConnectId: hcId,
          updatedAt: HealthRecordMetadata.nowUtcIso(),
          isSynced: measurement.isSynced,
        );
        await _repository.saveMeasurement(updated);
        _measurements = await _repository.loadMeasurements();
        notifyListeners();
      }
    } catch (e) {
      _healthConnectError = 'Body fat write failed: $e';
      notifyListeners();
    }
  }

  String? _localDateString(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return null;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // ── Android Live Update Notification Sync ────────────────────────────────

  Future<void> refreshLiveUpdateStatus() async {
    final next = await _liveNotificationService.getLiveUpdateStatus();
    if (next != _liveUpdateStatus) {
      _liveUpdateStatus = next;
      notifyListeners();
    }
  }

  Future<void> openLiveUpdateSettings() =>
      _liveNotificationService.openLiveUpdateSettings();

  Future<void> syncPendingLiveNotificationActions() async {
    final pending = await _liveNotificationService.consumePendingActions();
    if (pending.isEmpty) return;
    for (final action in pending) {
      _applyLiveAction(action);
    }
    if (_activeWorkout != null) {
      _lastSentLivePayload = null;
      _syncLiveNotification();
    }
  }

  void _applyLiveAction(OpenGymLiveAction action) {
    if (_activeWorkout == null) {
      _stopLiveNotification();
      return;
    }
    _lastSentLivePayload = null;
    switch (action.type) {
      case OpenGymLiveActionType.skipRest:
        if (isResting) {
          skipRest();
        } else {
          _syncLiveNotification();
        }
        break;
      case OpenGymLiveActionType.addRest:
        if (isResting) {
          addRest(action.deltaSeconds > 0 ? action.deltaSeconds : 30);
        } else {
          _syncLiveNotification();
        }
        break;
      case OpenGymLiveActionType.togglePause:
        togglePause();
        break;
      case OpenGymLiveActionType.completeNextSet:
        completeNextSet(startRestTimer: false);
        break;
    }
  }

  OpenGymLiveWorkoutPayload? _buildLiveWorkoutPayload() {
    final current = _activeWorkout;
    if (current == null) return null;

    final entries = current.entries;
    final unit = _preferences.weightUnit;
    final queuePairs = <(int, int)>[];
    if (entries.isNotEmpty) {
      final startIdx = _selectedEntryIndex.clamp(0, entries.length - 1);
      for (var offset = 0; offset < entries.length; offset++) {
        final eIdx = (startIdx + offset) % entries.length;
        final sets = entries[eIdx].sets;
        for (var sIdx = 0; sIdx < sets.length; sIdx++) {
          if (!sets[sIdx].isCompleted) {
            queuePairs.add((eIdx, sIdx));
          }
        }
      }
    }

    final nextQueue = queuePairs
        .take(10)
        .map(
          (pair) => OpenGymLiveNextSet(
            exerciseName: entries[pair.$1].exerciseName,
            setSummary: _formatSetSummary(entries[pair.$1], pair.$2, unit),
          ),
        )
        .toList();

    final String exerciseName;
    final String setSummary;
    if (nextQueue.isNotEmpty) {
      exerciseName = nextQueue.first.exerciseName;
      setSummary = nextQueue.first.setSummary;
    } else if (entries.isNotEmpty) {
      final selected =
          entries[_selectedEntryIndex.clamp(0, entries.length - 1)];
      exerciseName = selected.exerciseName;
      setSummary = current.totalSetsCount > 0
          ? 'All sets complete'
          : 'No sets added yet';
    } else {
      exerciseName = '';
      setSummary = 'No exercises added yet';
    }

    final effectiveStartMs = (_workoutStartedAt ?? DateTime.now())
            .millisecondsSinceEpoch +
        _accumulatedPaused.inMilliseconds;
    final restActive = !_isPaused &&
        _restEndsAt != null &&
        _restRemainingSeconds > 0;

    return OpenGymLiveWorkoutPayload(
      workoutTitle: current.title,
      exerciseName: exerciseName,
      setSummary: setSummary,
      completedSets: current.completedSetsCount,
      totalSets: current.totalSetsCount,
      workoutStartedAtMs: effectiveStartMs,
      elapsedSecondsAtUpdate: _elapsedSeconds,
      isPaused: _isPaused,
      pausedAtMs: _isPaused ? (_pausedAt?.millisecondsSinceEpoch ?? 0) : 0,
      restEndsAtMs: restActive ? _restEndsAt!.millisecondsSinceEpoch : 0,
      restTotalSeconds: restActive ? _restTotalSeconds : 0,
      hasNextIncompleteSet: queuePairs.isNotEmpty,
      nextSetsQueue: nextQueue,
      accentColor: _shortcutIconColor.toARGB32(),
    );
  }

  String _formatSetSummary(WorkoutEntry entry, int setIndex, String unit) {
    final set = entry.sets[setIndex];
    final prefix =
        set.isWarmup ? 'Warm-up' : 'Set ${setIndex + 1}/${entry.sets.length}';
    switch (entry.mode) {
      case ExerciseMode.reps:
        if (set.weight > 0 && set.reps > 0) {
          final w = set.weight;
          final weightStr = w == w.roundToDouble()
              ? w.toStringAsFixed(0)
              : w.toStringAsFixed(1);
          return '$prefix • $weightStr $unit × ${set.reps}';
        }
        if (set.reps > 0) {
          return '$prefix • ${set.reps} reps';
        }
        return prefix;
      case ExerciseMode.time:
        final dur = set.durationSeconds ?? 0;
        return dur > 0 ? '$prefix • ${dur}s' : prefix;
      case ExerciseMode.distance:
        final dist = set.distanceMeters ?? 0;
        return dist > 0 ? '$prefix • ${dist.toStringAsFixed(0)}m' : prefix;
      case ExerciseMode.cardio:
        final dur = set.durationSeconds ?? 0;
        return dur > 0 ? '$prefix • ${(dur / 60).round()} min' : prefix;
    }
  }

  void _syncLiveNotification() {
    final payload = _buildLiveWorkoutPayload();
    if (payload == null) return;
    if (payload == _lastSentLivePayload) return;
    _lastSentLivePayload = payload;
    unawaited(_liveNotificationService.updateWorkout(payload));
  }

  void _stopLiveNotification() {
    _lastSentLivePayload = null;
    unawaited(_liveNotificationService.stopWorkout());
  }

  @override
  void dispose() {
    unawaited(_liveActionSub?.cancel());
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _soundService.dispose();
    super.dispose();
  }
}
