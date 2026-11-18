import 'package:flutter/material.dart';

import '../models/health_connect_models.dart';
import '../state/open_gym_controller.dart';

/// Settings screen for Android Health Connect permissions, toggles, and sync.
class HealthConnectSettingsScreen extends StatelessWidget {
  const HealthConnectSettingsScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  String _statusLabel(
    HealthConnectSdkStatus status,
    HealthConnectSettings settings,
  ) {
    switch (status) {
      case HealthConnectSdkStatus.unavailable:
        return 'Unavailable on this device';
      case HealthConnectSdkStatus.providerUpdateRequired:
        return 'Health Connect app update or install required';
      case HealthConnectSdkStatus.available:
        return settings.enabled ? 'Connected' : 'Available (not connected)';
    }
  }

  Future<void> _onConnectTap(BuildContext context) async {
    final status = controller.healthConnectSdkStatus;
    if (status == HealthConnectSdkStatus.providerUpdateRequired) {
      await controller.healthConnect.openSettings();
      return;
    }
    final granted = await controller.connectHealthConnect();
    if (!context.mounted) return;
    if (granted) {
      final result = await controller.syncHealthConnect();
      if (!context.mounted) return;
      final summary = result == null
          ? 'Health Connect connected.'
          : 'Connected & synced: ${result.importedWeighIns} weigh-ins, '
              '${result.externalWorkouts} external workouts.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(summary)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.healthConnectError ??
                'Unable to connect to Health Connect.',
          ),
        ),
      );
    }
  }

  Future<void> _onSyncNowTap(BuildContext context) async {
    final result = await controller.syncHealthConnect();
    if (!context.mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.healthConnectError ?? 'Health Connect sync skipped.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Synced ${result.importedWeighIns} weigh-ins, '
          '${result.importedBodyFats} body fat entries, '
          '${result.externalWorkouts} external workouts.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final status = controller.healthConnectSdkStatus;
        final settings = controller.healthConnectSettings;
        final syncing = controller.healthConnectSyncing;

        return Scaffold(
          appBar: AppBar(title: const Text('Health Connect')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        settings.enabled &&
                                status == HealthConnectSdkStatus.available
                            ? Icons.favorite_rounded
                            : Icons.health_and_safety_outlined,
                        size: 32,
                        color: settings.enabled
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _statusLabel(status, settings),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              settings.lastSyncedAt != null
                                  ? 'Last synced: ${settings.lastSyncedAt}'
                                  : 'Data stays on-device between OpenGym and Android Health Connect.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: status == HealthConnectSdkStatus.unavailable ||
                              syncing
                          ? null
                          : () => _onConnectTap(context),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: Text(
                        status == HealthConnectSdkStatus.providerUpdateRequired
                            ? 'Install / Update'
                            : settings.enabled
                                ? 'Permissions'
                                : 'Connect',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: settings.enabled &&
                              status == HealthConnectSdkStatus.available &&
                              !syncing
                          ? () => _onSyncNowTap(context)
                          : null,
                      icon: syncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(syncing ? 'Syncing...' : 'Sync Now'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable Health Connect Sync'),
                subtitle: const Text(
                  'Master toggle for reading and writing Health Connect records',
                ),
                value: settings.enabled,
                onChanged: status == HealthConnectSdkStatus.available
                    ? (v) => controller.saveHealthConnectSettings(
                          settings.copyWith(enabled: v),
                        )
                    : null,
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Write Finished Workouts'),
                subtitle: const Text(
                  'Export completed OpenGym sessions as ExerciseSessionRecord',
                ),
                value: settings.writeWorkouts,
                onChanged: settings.enabled
                    ? (v) => controller.saveHealthConnectSettings(
                          settings.copyWith(writeWorkouts: v),
                        )
                    : null,
              ),
              SwitchListTile(
                title: const Text('Sync Weight & Body Fat'),
                subtitle: const Text(
                  'Read & write WeightRecord and BodyFatRecord',
                ),
                value: settings.syncBodyMetrics,
                onChanged: settings.enabled
                    ? (v) => controller.saveHealthConnectSettings(
                          settings.copyWith(syncBodyMetrics: v),
                        )
                    : null,
              ),
              SwitchListTile(
                title: const Text('Read External Workouts, Calories & HR'),
                subtitle: const Text(
                  'Import other apps\' workouts, active calories, and heart rate into Stats',
                ),
                value: settings.readExternalActivity,
                onChanged: settings.enabled
                    ? (v) => controller.saveHealthConnectSettings(
                          settings.copyWith(readExternalActivity: v),
                        )
                    : null,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Open Android Health Connect Settings'),
                subtitle: const Text('Manage app permissions in Android'),
                onTap: status == HealthConnectSdkStatus.unavailable
                    ? null
                    : () => controller.healthConnect.openSettings(),
              ),
            ],
          ),
        );
      },
    );
  }
}
