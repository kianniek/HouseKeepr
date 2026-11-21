import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:health_keepr/health_keepr.dart';

import 'src/state/open_gym_controller.dart';
import 'src/ui/active_workout_screen.dart';
import 'src/ui/open_gym_dashboard_screen.dart';

export 'src/audio/open_gym_sound_service.dart';
export 'src/audio/wav_synthesizer.dart';
export 'src/data/exercise_media_service.dart';
export 'src/models/active_workout_snapshot.dart';
export 'src/models/body_measurement.dart';
export 'src/models/exercise.dart';
export 'src/models/exercise_set.dart';
export 'src/models/health_connect_models.dart';
export 'src/models/programme.dart';
export 'src/models/progress_photo.dart';
export 'src/models/server_connection.dart';
export 'src/models/weigh_in.dart';
export 'src/models/workout_log.dart';
export 'src/models/workout_template.dart';
export 'src/state/analytics_service.dart';
export 'src/state/open_gym_controller.dart';
export 'src/state/open_gym_live_notification_service.dart';
export 'src/state/open_gym_repository.dart';
export 'src/state/open_gym_shortcut_service.dart';
export 'src/state/personal_record_service.dart';
export 'src/state/progression_service.dart';
export 'src/sync/health_connect_service.dart';
export 'src/sync/open_gym_server_client.dart';
export 'src/sync/open_gym_sync_service.dart';
export 'src/sync/webdav_client.dart';

/// Root entry widget for the deferred OpenGym mini-app.
///
/// Wraps a nested [Navigator] with [NavigatorPopHandler] so back navigation
/// supports Android Predictive Back gestures: internal screens pop cleanly
/// via nested routes, while at root depth the outer system back transition
/// can preview returning to HouseKeepr.
class OpenGymRoot extends StatefulWidget {
  const OpenGymRoot({
    super.key,
    required this.store,
    this.autoStartNextWorkout = false,
    this.openActiveWorkout = false,
    this.notificationScheduler,
  });

  final HealthDataStore store;
  final bool autoStartNextWorkout;
  final bool openActiveWorkout;
  final WorkoutNotificationScheduler? notificationScheduler;

  @override
  State<OpenGymRoot> createState() => _OpenGymRootState();
}

class _OpenGymRootState extends State<OpenGymRoot> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _nestedNavigatorKey =
      GlobalKey<NavigatorState>();
  final ValueNotifier<bool> _canPopNestedNotifier = ValueNotifier<bool>(false);
  late final _NestedRouteDepthObserver _routeDepthObserver;
  late final OpenGymController _controller;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routeDepthObserver = _NestedRouteDepthObserver(_onNestedDepthChanged);
    _controller = OpenGymController(
      store: widget.store,
      notificationScheduler: widget.notificationScheduler,
    )..initialize();
    OpenGymLauncher.registerActiveSession(_handleDeepLink);
  }

  void _onNestedDepthChanged(int depth) {
    if (_disposed) return;
    final canPopNested = depth > 1;
    if (_canPopNestedNotifier.value == canPopNested) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && _canPopNestedNotifier.value != canPopNested) {
          _canPopNestedNotifier.value = canPopNested;
        }
      });
    } else {
      _canPopNestedNotifier.value = canPopNested;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.syncPendingLiveNotificationActions());
      unawaited(_controller.refreshLiveUpdateStatus());
    }
  }

  void _handleDeepLink({
    required bool autoStartNextWorkout,
    bool openActiveWorkout = false,
  }) {
    if (!mounted) return;
    final nestedNav = _nestedNavigatorKey.currentState;
    if (nestedNav == null) return;

    // If an active workout exists and we're already on ActiveWorkoutScreen,
    // pop any transient sheets/dialogs above it; otherwise push ActiveWorkoutScreen.
    if (_controller.hasActiveWorkout) {
      if (_controller.isInActiveWorkoutScreen) {
        nestedNav.popUntil(
          (route) => route.settings.name == ActiveWorkoutScreen.routeName ||
              route.isFirst,
        );
        if (!_controller.isInActiveWorkoutScreen) {
          nestedNav.push<void>(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: ActiveWorkoutScreen.routeName),
              builder: (_) => ActiveWorkoutScreen(controller: _controller),
            ),
          );
        }
      } else {
        nestedNav.popUntil((route) => route.isFirst);
        nestedNav.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: ActiveWorkoutScreen.routeName),
            builder: (_) => ActiveWorkoutScreen(controller: _controller),
          ),
        );
      }
      return;
    }

    if (autoStartNextWorkout) {
      nestedNav.popUntil((route) => route.isFirst);
      final next = _controller.todaysScheduledTemplate();
      if (next != null) {
        _controller.startFromTemplate(next);
      } else {
        _controller.startEmptyWorkout();
      }
      nestedNav.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: ActiveWorkoutScreen.routeName),
          builder: (_) => ActiveWorkoutScreen(controller: _controller),
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colorScheme = Theme.of(context).colorScheme;
    _controller.updateShortcutColors(
      iconColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    OpenGymLauncher.registerActiveSession(null);
    _controller.dispose();
    _canPopNestedNotifier.dispose();
    super.dispose();
  }

  void _exitModule() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _canPopNestedNotifier,
      builder: (context, canPopNested, child) {
        return NavigatorPopHandler(
          enabled: canPopNested,
          onPopWithResult: (_) {
            final nestedNav = _nestedNavigatorKey.currentState;
            if (nestedNav != null && nestedNav.canPop()) {
              nestedNav.pop();
            }
          },
          child: child!,
        );
      },
      child: Navigator(
        key: _nestedNavigatorKey,
        observers: <NavigatorObserver>[_routeDepthObserver],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => OpenGymDashboardScreen(
            controller: _controller,
            onExitModule: _exitModule,
            autoStartNextWorkout: widget.autoStartNextWorkout,
            openActiveWorkout: widget.openActiveWorkout,
          ),
        ),
      ),
    );
  }
}

class _NestedRouteDepthObserver extends NavigatorObserver {
  _NestedRouteDepthObserver(this.onDepthChanged);

  final ValueChanged<int> onDepthChanged;
  int _depth = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _depth++;
    onDepthChanged(_depth);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) _depth--;
    onDepthChanged(_depth);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) _depth--;
    onDepthChanged(_depth);
  }
}
