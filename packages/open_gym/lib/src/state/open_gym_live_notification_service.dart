import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Preview of an upcoming incomplete set sent to the native notification service.
class OpenGymLiveNextSet {
  const OpenGymLiveNextSet({
    required this.exerciseName,
    required this.setSummary,
  });

  final String exerciseName;
  final String setSummary;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'exerciseName': exerciseName,
        'setSummary': setSummary,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenGymLiveNextSet &&
          runtimeType == other.runtimeType &&
          exerciseName == other.exerciseName &&
          setSummary == other.setSummary;

  @override
  int get hashCode => Object.hash(exerciseName, setSummary);
}

/// Complete snapshot payload pushed to Android's Live Update ForegroundService.
class OpenGymLiveWorkoutPayload {
  const OpenGymLiveWorkoutPayload({
    required this.workoutTitle,
    required this.exerciseName,
    required this.setSummary,
    required this.completedSets,
    required this.totalSets,
    required this.workoutStartedAtMs,
    required this.elapsedSecondsAtUpdate,
    required this.isPaused,
    this.pausedAtMs = 0,
    this.restEndsAtMs = 0,
    this.restTotalSeconds = 0,
    required this.hasNextIncompleteSet,
    this.nextSetsQueue = const <OpenGymLiveNextSet>[],
    this.accentColor = 0xFFC65102,
  });

  final String workoutTitle;
  final String exerciseName;
  final String setSummary;
  final int completedSets;
  final int totalSets;
  final int workoutStartedAtMs;
  final int elapsedSecondsAtUpdate;
  final bool isPaused;
  final int pausedAtMs;
  final int restEndsAtMs;
  final int restTotalSeconds;
  final bool hasNextIncompleteSet;
  final List<OpenGymLiveNextSet> nextSetsQueue;
  final int accentColor;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'workoutTitle': workoutTitle,
        'exerciseName': exerciseName,
        'setSummary': setSummary,
        'completedSets': completedSets,
        'totalSets': totalSets,
        'workoutStartedAtMs': workoutStartedAtMs,
        'elapsedSecondsAtUpdate': elapsedSecondsAtUpdate,
        'isPaused': isPaused,
        'pausedAtMs': pausedAtMs,
        'restEndsAtMs': restEndsAtMs,
        'restTotalSeconds': restTotalSeconds,
        'hasNextIncompleteSet': hasNextIncompleteSet,
        'nextSetsQueue': nextSetsQueue.map((e) => e.toMap()).toList(),
        'accentColor': accentColor,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenGymLiveWorkoutPayload &&
          runtimeType == other.runtimeType &&
          workoutTitle == other.workoutTitle &&
          exerciseName == other.exerciseName &&
          setSummary == other.setSummary &&
          completedSets == other.completedSets &&
          totalSets == other.totalSets &&
          workoutStartedAtMs == other.workoutStartedAtMs &&
          isPaused == other.isPaused &&
          pausedAtMs == other.pausedAtMs &&
          restEndsAtMs == restEndsAtMs &&
          restTotalSeconds == restTotalSeconds &&
          hasNextIncompleteSet == other.hasNextIncompleteSet &&
          accentColor == other.accentColor &&
          listEquals(nextSetsQueue, other.nextSetsQueue);

  @override
  int get hashCode => Object.hash(
        workoutTitle,
        exerciseName,
        setSummary,
        completedSets,
        totalSets,
        workoutStartedAtMs,
        isPaused,
        pausedAtMs,
        restEndsAtMs,
        restTotalSeconds,
        hasNextIncompleteSet,
        accentColor,
        Object.hashAll(nextSetsQueue),
      );
}

enum OpenGymLiveActionType {
  skipRest,
  addRest,
  togglePause,
  completeNextSet,
}

class OpenGymLiveAction {
  const OpenGymLiveAction({
    required this.type,
    this.deltaSeconds = 0,
    this.timestampMs = 0,
  });

  final OpenGymLiveActionType type;
  final int deltaSeconds;
  final int timestampMs;

  static OpenGymLiveAction? fromMap(Map<dynamic, dynamic> map) {
    final rawAction = map['action'] as String?;
    final type = switch (rawAction) {
      'skip_rest' => OpenGymLiveActionType.skipRest,
      'add_rest' => OpenGymLiveActionType.addRest,
      'toggle_pause' => OpenGymLiveActionType.togglePause,
      'complete_next_set' => OpenGymLiveActionType.completeNextSet,
      _ => null,
    };
    if (type == null) return null;
    return OpenGymLiveAction(
      type: type,
      deltaSeconds: (map['deltaSeconds'] as num?)?.toInt() ?? 0,
      timestampMs: (map['timestampMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class OpenGymLiveUpdateStatus {
  const OpenGymLiveUpdateStatus({
    this.isSupported = false,
    this.canPostPromotedNotifications = false,
    this.notificationsEnabled = false,
  });

  final bool isSupported;
  final bool canPostPromotedNotifications;
  final bool notificationsEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenGymLiveUpdateStatus &&
          runtimeType == other.runtimeType &&
          isSupported == other.isSupported &&
          canPostPromotedNotifications == other.canPostPromotedNotifications &&
          notificationsEnabled == other.notificationsEnabled;

  @override
  int get hashCode => Object.hash(
        isSupported,
        canPostPromotedNotifications,
        notificationsEnabled,
      );
}

/// Bridges OpenGym workout state and notification button actions to Android's
/// native Live Update ForegroundService (`housekeepr/opengym_live`).
class OpenGymLiveNotificationService {
  OpenGymLiveNotificationService({
    MethodChannel? channel,
    EventChannel? eventChannel,
  })  : _channel = channel ?? const MethodChannel(_channelName),
        _eventChannel = eventChannel ?? const EventChannel(_eventChannelName);

  static const String _channelName = 'housekeepr/opengym_live';
  static const String _eventChannelName = 'housekeepr/opengym_live_events';

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  Stream<OpenGymLiveAction>? _actionsStream;
  bool _bridgeAvailable = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<OpenGymLiveAction> get actions {
    if (!_bridgeAvailable) {
      return const Stream<OpenGymLiveAction>.empty();
    }
    return _actionsStream ??= _createActionsStream();
  }

  Stream<OpenGymLiveAction> _createActionsStream() {
    try {
      return _eventChannel
          .receiveBroadcastStream()
          .handleError((Object error) {
            if (error is MissingPluginException || error is PlatformException) {
              return;
            }
            debugPrint('OpenGymLiveNotificationService stream error: $error');
          })
          .where((event) => event is Map)
          .map((event) => OpenGymLiveAction.fromMap(event as Map))
          .where((action) => action != null)
          .cast<OpenGymLiveAction>()
          .asBroadcastStream(onCancel: (sub) => sub.cancel());
    } on MissingPluginException {
      return const Stream<OpenGymLiveAction>.empty();
    } on FlutterError {
      return const Stream<OpenGymLiveAction>.empty();
    } catch (_) {
      return const Stream<OpenGymLiveAction>.empty();
    }
  }

  Future<void> updateWorkout(OpenGymLiveWorkoutPayload payload) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('updateLiveWorkout', payload.toMap());
    } on MissingPluginException {
      // Ignored on platforms/tests without the Android live notification bridge.
    } on PlatformException catch (e) {
      debugPrint('OpenGymLiveNotificationService: updateWorkout failed: $e');
    } on FlutterError {
      // Ignored when Flutter ServicesBinding is not initialized (e.g. unit tests).
    }
  }

  Future<void> stopWorkout() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('stopLiveWorkout');
    } on MissingPluginException {
      // Ignored on platforms/tests without the Android live notification bridge.
    } on PlatformException catch (e) {
      debugPrint('OpenGymLiveNotificationService: stopWorkout failed: $e');
    } on FlutterError {
      // Ignored when Flutter ServicesBinding is not initialized.
    }
  }

  Future<List<OpenGymLiveAction>> consumePendingActions() async {
    if (!_isAndroid) return const <OpenGymLiveAction>[];
    try {
      final raw = await _channel.invokeListMethod<dynamic>(
        'consumePendingActions',
      );
      if (raw == null || raw.isEmpty) return const <OpenGymLiveAction>[];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(OpenGymLiveAction.fromMap)
          .whereType<OpenGymLiveAction>()
          .toList();
    } on MissingPluginException {
      return const <OpenGymLiveAction>[];
    } on PlatformException catch (e) {
      debugPrint(
        'OpenGymLiveNotificationService: consumePendingActions failed: $e',
      );
      return const <OpenGymLiveAction>[];
    } on FlutterError {
      return const <OpenGymLiveAction>[];
    }
  }

  Future<OpenGymLiveUpdateStatus> getLiveUpdateStatus() async {
    if (!_isAndroid) {
      _bridgeAvailable = false;
      return const OpenGymLiveUpdateStatus();
    }
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>(
        'getLiveUpdateStatus',
      );
      if (map == null) {
        _bridgeAvailable = false;
        return const OpenGymLiveUpdateStatus();
      }
      _bridgeAvailable = true;
      return OpenGymLiveUpdateStatus(
        isSupported: (map['supported'] as bool?) ?? false,
        canPostPromotedNotifications:
            (map['canPostPromotedNotifications'] as bool?) ?? false,
        notificationsEnabled: (map['notificationsEnabled'] as bool?) ?? false,
      );
    } on MissingPluginException {
      _bridgeAvailable = false;
      return const OpenGymLiveUpdateStatus();
    } on PlatformException catch (e) {
      debugPrint(
        'OpenGymLiveNotificationService: getLiveUpdateStatus failed: $e',
      );
      _bridgeAvailable = false;
      return const OpenGymLiveUpdateStatus();
    } on FlutterError {
      _bridgeAvailable = false;
      return const OpenGymLiveUpdateStatus();
    }
  }

  Future<void> openLiveUpdateSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('openLiveUpdateSettings');
    } on MissingPluginException {
      // Ignored on unsupported platforms.
    } on PlatformException catch (e) {
      debugPrint(
        'OpenGymLiveNotificationService: openLiveUpdateSettings failed: $e',
      );
    } on FlutterError {
      // Ignored when Flutter ServicesBinding is not initialized.
    }
  }
}
