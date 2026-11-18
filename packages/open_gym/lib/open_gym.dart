import 'package:flutter/material.dart';
import 'package:health_keepr/health_keepr.dart';

import 'src/state/open_gym_controller.dart';
import 'src/ui/open_gym_dashboard_screen.dart';

export 'src/audio/open_gym_sound_service.dart';
export 'src/audio/wav_synthesizer.dart';
export 'src/data/exercise_media_service.dart';
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
export 'src/state/open_gym_repository.dart';
export 'src/state/personal_record_service.dart';
export 'src/state/progression_service.dart';
export 'src/sync/health_connect_service.dart';
export 'src/sync/open_gym_server_client.dart';
export 'src/sync/open_gym_sync_service.dart';
export 'src/sync/webdav_client.dart';

/// Root entry widget for the deferred OpenGym mini-app.
///
/// Wraps a nested [Navigator] with [PopScope] so back navigation cleanly pops
/// internal OpenGym screens before returning to `HealthKeeprHubScreen`.
class OpenGymRoot extends StatefulWidget {
  const OpenGymRoot({
    super.key,
    required this.store,
  });

  final HealthDataStore store;

  @override
  State<OpenGymRoot> createState() => _OpenGymRootState();
}

class _OpenGymRootState extends State<OpenGymRoot> {
  final GlobalKey<NavigatorState> _nestedNavigatorKey =
      GlobalKey<NavigatorState>();
  late final OpenGymController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OpenGymController(store: widget.store)..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _exitModule() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nestedNav = _nestedNavigatorKey.currentState;
        if (nestedNav != null && nestedNav.canPop()) {
          nestedNav.pop();
        } else {
          _exitModule();
        }
      },
      child: Navigator(
        key: _nestedNavigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => OpenGymDashboardScreen(
            controller: _controller,
            onExitModule: _exitModule,
          ),
        ),
      ),
    );
  }
}
