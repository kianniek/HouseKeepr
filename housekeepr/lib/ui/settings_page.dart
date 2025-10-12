import 'package:flutter/material.dart';
import '../core/settings_repository.dart';
import '../core/sync_mode.dart';

class SettingsPage extends StatefulWidget {
  final SettingsRepository settings;
  const SettingsPage({super.key, required this.settings});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SyncMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.settings.getSyncMode();
  }

  void _setMode(SyncMode? m) async {
    if (m == null) return;
    setState(() => _mode = m);
    await widget.settings.setSyncMode(m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Sync mode'),
            subtitle: Text(_mode.toKey()),
          ),
          RadioGroup<SyncMode>(
            groupValue: _mode,
            onChanged: (SyncMode? newValue) {
              _setMode(newValue);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('Sync'),
                Radio<SyncMode>(value: SyncMode.sync),
                const Text('localOnly'),
                Radio<SyncMode>(value: SyncMode.localOnly),
                const Text('remoteOnly'),
                Radio<SyncMode>(value: SyncMode.remoteOnly),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
