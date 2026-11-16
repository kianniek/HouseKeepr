import 'package:flutter/material.dart';
// ignore: library_prefixes
import 'package:open_gym/open_gym.dart' deferred as openGym;

import '../contracts/health_data_store.dart';
import 'health_mini_app.dart';

/// Deferred launcher for the OpenGym on-demand module.
///
/// Only `health_keepr` imports `package:open_gym/open_gym.dart` via
/// `deferred as openGym`, keeping it out of the base HouseKeepr bundle until
/// the user explicitly launches it.
class OpenGymLauncher {
  OpenGymLauncher._();

  static const String moduleId = 'open_gym';
  static bool _isLoaded = false;

  /// Whether the `open_gym` deferred library has been loaded in this session.
  static bool get isLoaded => _isLoaded;

  /// Builds the [HealthMiniApp] descriptor for OpenGym.
  static HealthMiniApp descriptor() {
    return HealthMiniApp(
      id: moduleId,
      title: 'OpenGym',
      subtitle: 'Workouts, sets, timers & PR tracking',
      icon: Icons.fitness_center_rounded,
      isInstalled: _isLoaded,
      onLaunch: launch,
    );
  }

  /// Loads the deferred `open_gym` library if needed and pushes `OpenGymRoot`.
  static Future<void> launch(
    BuildContext context,
    HealthDataStore store,
  ) async {
    if (!_isLoaded) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            content: Row(
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Installing OpenGym...',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          );
        },
      );

      try {
        await openGym.loadLibrary();
        _isLoaded = true;
      } catch (error) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to install OpenGym: $error'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  launch(context, store);
                },
              ),
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => openGym.OpenGymRoot(store: store),
      ),
    );
  }
}
