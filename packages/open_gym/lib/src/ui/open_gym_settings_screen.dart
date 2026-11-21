import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/open_gym_sound_service.dart';
import '../models/health_connect_models.dart';
import '../state/open_gym_controller.dart';
import '../state/personal_record_service.dart';
import 'health_connect_settings_screen.dart';
import 'server_connect_screen.dart';

/// Settings screen for OpenGym units, 1RM formula, rest timer, backups,
/// and optional self-hosted server connection.
class OpenGymSettingsScreen extends StatelessWidget {
  const OpenGymSettingsScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  Future<void> _exportBackup(BuildContext context) async {
    final json = await controller.exportBackupJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup JSON copied to clipboard.')),
      );
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final textCtrl = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore JSON Backup'),
        content: TextField(
          controller: textCtrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Paste exported OpenGym backup JSON here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(textCtrl.text),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final count = await controller.importBackupJson(raw);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored $count records.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final prefs = controller.preferences;
        final conn = controller.serverConnection;

        return Scaffold(
          appBar: AppBar(title: const Text('OpenGym Settings')),
          body: ListView(
            children: <Widget>[
              SwitchListTile(
                title: const Text('Use Pounds (lb)'),
                subtitle: Text('Currently displaying weights in ${prefs.weightUnit}'),
                value: prefs.usePounds,
                onChanged: (v) =>
                    controller.savePreferences(prefs.copyWith(usePounds: v)),
              ),
              ListTile(
                title: const Text('1RM Estimation Formula'),
                subtitle: Text(OneRmEstimator.displayName(prefs.oneRmFormula)),
                trailing: DropdownButton<String>(
                  value: prefs.oneRmFormula,
                  items: OneRmEstimator.formulaKeys
                      .map(
                        (k) => DropdownMenuItem<String>(
                          value: k,
                          child: Text(OneRmEstimator.displayName(k)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      controller.savePreferences(
                        prefs.copyWith(oneRmFormula: v),
                      );
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('Default Rest Timer'),
                subtitle: Text('${prefs.defaultRestSeconds} seconds'),
                trailing: DropdownButton<int>(
                  value: <int>[60, 90, 120, 150, 180]
                          .contains(prefs.defaultRestSeconds)
                      ? prefs.defaultRestSeconds
                      : 90,
                  items: const <int>[60, 90, 120, 150, 180]
                      .map(
                        (s) => DropdownMenuItem<int>(
                          value: s,
                          child: Text('${s}s'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      controller.savePreferences(
                        prefs.copyWith(defaultRestSeconds: v),
                      );
                    }
                  },
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Sounds'),
                subtitle: const Text('Set ticks, 3-2-1 countdown, and rest chimes'),
                value: prefs.soundEnabled,
                onChanged: (v) =>
                    controller.savePreferences(prefs.copyWith(soundEnabled: v)),
              ),
              SwitchListTile(
                title: const Text('PR Celebration Sound'),
                subtitle: const Text('Play rising chime when a record is beaten'),
                value: prefs.prSoundEnabled,
                onChanged: prefs.soundEnabled
                    ? (v) => controller.savePreferences(
                          prefs.copyWith(prSoundEnabled: v),
                        )
                    : null,
              ),
              SwitchListTile(
                title: const Text('Vibrate / Haptics'),
                subtitle: const Text('Tactile feedback on sets and rest end'),
                value: prefs.hapticsEnabled,
                onChanged: (v) => controller.savePreferences(
                  prefs.copyWith(hapticsEnabled: v),
                ),
              ),
              ListTile(
                title: const Text('Rest End Sound'),
                subtitle: Text(
                  OpenGymSoundService.profileFor(prefs.restSound).label,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Preview sound',
                      icon: const Icon(Icons.volume_up_outlined),
                      onPressed: () => controller.soundService.playRestEndChime(
                        kind: prefs.restSound,
                        soundEnabled: true,
                        hapticsEnabled: prefs.hapticsEnabled,
                      ),
                    ),
                    DropdownButton<String>(
                      value: OpenGymSoundService.restSounds
                              .any((s) => s.id == prefs.restSound)
                          ? prefs.restSound
                          : 'chime',
                      items: OpenGymSoundService.restSounds
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s.id,
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          controller.savePreferences(
                            prefs.copyWith(restSound: v),
                          );
                          controller.soundService.playRestEndChime(
                            kind: v,
                            soundEnabled: prefs.soundEnabled,
                            hapticsEnabled: false,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (controller.liveUpdateStatus.isSupported) ...<Widget>[
                ListTile(
                  leading: Icon(
                    controller.liveUpdateStatus.canPostPromotedNotifications
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_active_outlined,
                  ),
                  title: const Text('Live Workout Status Chip'),
                  subtitle: Text(
                    controller.liveUpdateStatus.canPostPromotedNotifications
                        ? 'Enabled — live workout & rest timers appear in the status bar'
                        : 'Enable Live Updates in Android settings to show the status bar chip',
                  ),
                  trailing: Icon(
                    controller.liveUpdateStatus.canPostPromotedNotifications
                        ? Icons.chevron_right
                        : Icons.open_in_new,
                  ),
                  onTap: () => controller.openLiveUpdateSettings(),
                ),
                const Divider(),
              ],
              ListTile(
                leading: Icon(
                  controller.healthConnectSettings.enabled &&
                          controller.healthConnectSdkStatus ==
                              HealthConnectSdkStatus.available
                      ? Icons.favorite_rounded
                      : Icons.health_and_safety_outlined,
                ),
                title: const Text('Android Health Connect'),
                subtitle: Text(
                  controller.healthConnectSdkStatus ==
                          HealthConnectSdkStatus.unavailable
                      ? 'Unavailable on this device'
                      : controller.healthConnectSettings.enabled
                          ? 'Connected (workouts, body metrics, calories & HR)'
                          : 'Off (tap to configure)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          HealthConnectSettingsScreen(controller: controller),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  conn != null && conn.isConnected
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                ),
                title: const Text('Connect to Server'),
                subtitle: Text(
                  conn != null && conn.isConnected
                      ? 'Connected: ${conn.serverUrl}'
                      : 'Offline (Local device storage only)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ServerConnectScreen(controller: controller),
                    ),
                  );
                },
              ),
              const Divider(),
              const _PinOpenGymTile(),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Export Local Backup (JSON)'),
                subtitle: const Text('Copy all workouts & routines to clipboard'),
                onTap: () => _exportBackup(context),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Restore from JSON Backup'),
                subtitle: const Text('Merge exported records into local storage'),
                onTap: () => _importBackup(context),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('WebDAV Backup / Restore'),
                subtitle: const Text('Upload or restore snapshot via WebDAV URL'),
                onTap: () => _showWebDavDialog(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showWebDavDialog(BuildContext context) async {
    final urlCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('WebDAV Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'WebDAV File URL',
                hintText: 'https://cloud.example.com/remote.php/dav/.../opengym.json',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password / App Token',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final count = await controller.restoreFromWebDav(
                  fileUrl: urlCtrl.text,
                  username: userCtrl.text,
                  password: passCtrl.text,
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restored $count records via WebDAV.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('WebDAV restore failed: $e')),
                  );
                }
              }
            },
            child: const Text('Restore'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await controller.backupToWebDav(
                  fileUrl: urlCtrl.text,
                  username: userCtrl.text,
                  password: passCtrl.text,
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Uploaded backup to WebDAV.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('WebDAV upload failed: $e')),
                  );
                }
              }
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }
}

class _PinOpenGymTile extends StatefulWidget {
  const _PinOpenGymTile();

  @override
  State<_PinOpenGymTile> createState() => _PinOpenGymTileState();
}

class _PinOpenGymTileState extends State<_PinOpenGymTile> {
  static const MethodChannel _shortcutsChannel = MethodChannel(
    'housekeepr/shortcuts',
  );
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final supported =
          await _shortcutsChannel.invokeMethod<bool>('canPinShortcuts') ??
          false;
      if (mounted && supported) {
        setState(() => _supported = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.add_to_home_screen_outlined),
      title: const Text('Pin OpenGym to Home Screen'),
      subtitle: const Text('Add a direct OpenGym icon to your launcher'),
      onTap: () async {
        try {
          await _shortcutsChannel.invokeMethod<bool>('pinShortcut', {
            'id': 'open_gym',
            'shortLabel': 'OpenGym',
            'longLabel': 'Open OpenGym',
            'uri': 'housekeepr://opengym',
            'iconKey': 'open_gym',
          });
        } catch (_) {}
      },
    );
  }
}
