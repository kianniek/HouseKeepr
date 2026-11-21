import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: library_prefixes
import 'package:open_gym/open_gym.dart' deferred as openGym;

import '../contracts/health_data_store.dart';
import '../contracts/workout_notification_scheduler.dart';
import 'health_mini_app.dart';

/// Progress payload emitted by the Android deferred-component manager.
@visibleForTesting
class DeferredInstallProgress {
  const DeferredInstallProgress({
    required this.moduleName,
    required this.status,
    this.bytesDownloaded = 0,
    this.totalBytesToDownload = 0,
    this.errorCode,
    this.message,
  });

  factory DeferredInstallProgress.fromMap(Map<dynamic, dynamic> map) {
    return DeferredInstallProgress(
      moduleName: (map['moduleName'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'unknown',
      bytesDownloaded: (map['bytesDownloaded'] as num?)?.toInt() ?? 0,
      totalBytesToDownload: (map['totalBytesToDownload'] as num?)?.toInt() ?? 0,
      errorCode: (map['errorCode'] as num?)?.toInt(),
      message: map['message'] as String?,
    );
  }

  final String moduleName;
  final String status;
  final int bytesDownloaded;
  final int totalBytesToDownload;
  final int? errorCode;
  final String? message;

  double? get fraction {
    if (status != 'downloading' || totalBytesToDownload <= 0) return null;
    return (bytesDownloaded / totalBytesToDownload).clamp(0.0, 1.0);
  }

  String get statusLabel {
    switch (status) {
      case 'requesting':
        return 'Requesting OpenGym from Google Play...';
      case 'pending':
        return 'Waiting in Google Play queue...';
      case 'requiresUserConfirmation':
        return 'Waiting for Google Play confirmation...';
      case 'downloading':
        return 'Downloading OpenGym...';
      case 'downloaded':
        return 'Download complete. Preparing install...';
      case 'installing':
        return 'Installing OpenGym module...';
      case 'installed':
        return 'Installed! Opening OpenGym...';
      case 'canceling':
        return 'Cancelling installation...';
      case 'cancelled':
        return 'Installation cancelled.';
      case 'failed':
        return message ?? 'Installation failed.';
      default:
        return 'Connecting to Google Play...';
    }
  }

  String? get formattedTransfer {
    if (status != 'downloading') return null;
    if (totalBytesToDownload > 0) {
      final pct = ((fraction ?? 0) * 100).round();
      return '${_formatBytes(bytesDownloaded)} / ${_formatBytes(totalBytesToDownload)} ($pct%)';
    }
    if (bytesDownloaded > 0) {
      return '${_formatBytes(bytesDownloaded)} downloaded';
    }
    return null;
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Deferred launcher for the OpenGym on-demand module.
///
/// Only `health_keepr` imports `package:open_gym/open_gym.dart` via
/// `deferred as openGym`, keeping it out of the base HouseKeepr bundle until
/// the user explicitly launches it.
class OpenGymLauncher {
  OpenGymLauncher._();

  static const String moduleId = 'open_gym';
  static const String androidModuleName = 'openGym';

  static const EventChannel _progressChannel = EventChannel(
    'housekeepr/deferred_component_progress',
  );
  static const MethodChannel _actionsChannel = MethodChannel(
    'housekeepr/deferred_component_actions',
  );

  static bool _isLoaded = false;
  static void Function({
    required bool autoStartNextWorkout,
    bool openActiveWorkout,
  })? _activeDeepLinkHandler;
  static WorkoutNotificationScheduler? _defaultNotificationScheduler;

  /// Whether the `open_gym` deferred library has been loaded in this session.
  static bool get isLoaded => _isLoaded;

  /// Whether an `OpenGymRoot` instance is currently mounted.
  static bool get isOpen => _activeDeepLinkHandler != null;

  /// Registers the active `OpenGymRoot` deep-link handler while mounted.
  static void registerActiveSession(
    void Function({
      required bool autoStartNextWorkout,
      bool openActiveWorkout,
    })? handler,
  ) {
    _activeDeepLinkHandler = handler;
  }

  /// Registers a host-provided [WorkoutNotificationScheduler] used whenever
  /// `OpenGymLauncher.launch` is called without an explicit scheduler.
  static void registerDefaultNotificationScheduler(
    WorkoutNotificationScheduler? scheduler,
  ) {
    _defaultNotificationScheduler = scheduler;
  }

  /// Builds the [HealthMiniApp] descriptor for OpenGym.
  static HealthMiniApp descriptor() {
    return HealthMiniApp(
      id: moduleId,
      title: 'OpenGym',
      subtitle: 'Workouts, sets, timers & PR tracking',
      iconAsset: 'assets/icons/open_gym.svg',
      iconAssetPackage: 'health_keepr',
      isInstalled: _isLoaded,
      onLaunch: launch,
    );
  }

  static Stream<DeferredInstallProgress> _nativeProgressStream() {
    try {
      return _progressChannel
          .receiveBroadcastStream()
          .where((event) => event is Map)
          .map((event) => DeferredInstallProgress.fromMap(event as Map))
          .where((progress) => progress.moduleName == androidModuleName);
    } on MissingPluginException {
      return const Stream<DeferredInstallProgress>.empty();
    }
  }

  static Future<void> _requestCancel() async {
    try {
      await _actionsChannel.invokeMethod<bool>('cancelInstall', {
        'moduleName': androidModuleName,
      });
    } on MissingPluginException {
      // Ignored on platforms without the Android deferred component bridge.
    } on PlatformException {
      // Best-effort cancellation.
    }
  }

  /// Loads the deferred `open_gym` library if needed and pushes `OpenGymRoot`.
  ///
  /// If an `OpenGymRoot` is already mounted, routes the request to the active
  /// session instead of pushing a duplicate instance.
  static Future<void> launch(
    BuildContext context,
    HealthDataStore store, {
    bool autoStartNextWorkout = false,
    bool openActiveWorkout = false,
    WorkoutNotificationScheduler? notificationScheduler,
    @visibleForTesting Future<void> Function()? libraryLoader,
    @visibleForTesting Stream<DeferredInstallProgress>? progressStream,
    @visibleForTesting Future<void> Function()? onCancelInstall,
  }) async {
    final activeHandler = _activeDeepLinkHandler;
    if (activeHandler != null) {
      activeHandler(
        autoStartNextWorkout: autoStartNextWorkout,
        openActiveWorkout: openActiveWorkout,
      );
      return;
    }
    if (!_isLoaded) {
      var cancelled = false;
      var dialogOpen = true;

      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => OpenGymInstallDialog(
            progressStream: progressStream ?? _nativeProgressStream(),
            onCancel: () async {
              cancelled = true;
              dialogOpen = false;
              Navigator.of(dialogContext).pop();
              await (onCancelInstall ?? _requestCancel)();
            },
          ),
        ).whenComplete(() {
          dialogOpen = false;
        }),
      );

      try {
        debugPrint('OpenGymLauncher: calling openGym.loadLibrary()');
        await (libraryLoader ?? () => openGym.loadLibrary())();
        debugPrint(
          'OpenGymLauncher: openGym.loadLibrary() completed (cancelled=$cancelled)',
        );
        if (cancelled) return;
        _isLoaded = true;
      } catch (error, stackTrace) {
        debugPrint(
          'OpenGymLauncher: openGym.loadLibrary() failed: $error\n$stackTrace',
        );
        if (cancelled) return;
        if (context.mounted) {
          if (dialogOpen) {
            Navigator.of(context, rootNavigator: true).pop();
            dialogOpen = false;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to install OpenGym: $error'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  launch(
                    context,
                    store,
                    autoStartNextWorkout: autoStartNextWorkout,
                    openActiveWorkout: openActiveWorkout,
                  );
                },
              ),
            ),
          );
        }
        return;
      }

      if (context.mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
    }

    debugPrint(
      'OpenGymLauncher: mounted=${context.mounted}, pushing OpenGymRoot',
    );
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => openGym.OpenGymRoot(
          store: store,
          autoStartNextWorkout: autoStartNextWorkout,
          openActiveWorkout: openActiveWorkout,
          notificationScheduler:
              notificationScheduler ?? _defaultNotificationScheduler,
        ),
      ),
    );
  }
}

/// Dialog showing live installation status, download progress, elapsed time,
/// and a cancel action while OpenGym is being installed on demand.
@visibleForTesting
class OpenGymInstallDialog extends StatefulWidget {
  const OpenGymInstallDialog({
    super.key,
    required this.progressStream,
    required this.onCancel,
    this.stallThreshold = const Duration(seconds: 15),
  });

  final Stream<DeferredInstallProgress> progressStream;
  final VoidCallback onCancel;
  final Duration stallThreshold;

  @override
  State<OpenGymInstallDialog> createState() => _OpenGymInstallDialogState();
}

class _OpenGymInstallDialogState extends State<OpenGymInstallDialog> {
  DeferredInstallProgress _progress = const DeferredInstallProgress(
    moduleName: OpenGymLauncher.androidModuleName,
    status: 'connecting',
  );
  StreamSubscription<DeferredInstallProgress>? _subscription;
  Timer? _ticker;
  int _elapsedSeconds = 0;
  int _secondsSinceLastProgress = 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.progressStream.listen(
      (update) {
        if (!mounted) return;
        final progressed =
            update.status != _progress.status ||
            update.bytesDownloaded != _progress.bytesDownloaded;
        setState(() {
          _progress = update;
          if (progressed) {
            _secondsSinceLastProgress = 0;
          }
        });
      },
      onError: (_) {
        // Ignore stream errors; loadLibrary() surfaces actual install errors.
      },
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        _secondsSinceLastProgress++;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  String _formatElapsed(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fraction = _progress.fraction;
    final transferText = _progress.formattedTransfer;
    final isStalled =
        _secondsSinceLastProgress >= widget.stallThreshold.inSeconds &&
        _progress.status != 'installed' &&
        _progress.status != 'cancelled' &&
        _progress.status != 'failed';

    return AlertDialog(
      title: const Text('Installing OpenGym'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_progress.statusLabel, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                transferText ?? _statusDetail(_progress.status),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _formatElapsed(_elapsedSeconds),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (isStalled) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Taking longer than usual. Google Play may be waiting for '
                'Wi-Fi, updating in the background, or this build was not '
                'installed from Google Play.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
      ],
    );
  }

  String _statusDetail(String status) {
    switch (status) {
      case 'requesting':
        return 'Starting session...';
      case 'pending':
        return 'Queued';
      case 'requiresUserConfirmation':
        return 'Needs confirmation';
      case 'downloaded':
        return 'Verifying...';
      case 'installing':
        return 'Installing...';
      case 'installed':
        return 'Ready';
      default:
        return 'Starting...';
    }
  }
}
