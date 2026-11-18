import 'package:flutter/material.dart';

import '../state/open_gym_controller.dart';
import '../sync/open_gym_server_client.dart';

/// Optional self-hosted openGym server pairing & sync screen.
///
/// OpenGym works 100% offline by default; users can use this screen in
/// Settings if they want to pair with their own self-hosted server.
class ServerConnectScreen extends StatefulWidget {
  const ServerConnectScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  @override
  State<ServerConnectScreen> createState() => _ServerConnectScreenState();
}

class _ServerConnectScreenState extends State<ServerConnectScreen> {
  final _urlCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _cfIdCtrl = TextEditingController();
  final _cfSecretCtrl = TextEditingController();

  bool _usePassword = false;
  bool _showCfAccess = false;
  bool _busy = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _codeCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _cfIdCtrl.dispose();
    _cfSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
      _isError = false;
    });
    try {
      final cfId = _cfIdCtrl.text.trim();
      final cfSecret = _cfSecretCtrl.text.trim();
      if (_usePassword) {
        await widget.controller.connectServerWithPassword(
          serverUrl: _urlCtrl.text,
          username: _userCtrl.text,
          password: _passCtrl.text,
          cfAccessClientId: cfId.isEmpty ? null : cfId,
          cfAccessClientSecret: cfSecret.isEmpty ? null : cfSecret,
        );
      } else {
        await widget.controller.connectServerWithCode(
          serverUrl: _urlCtrl.text,
          code: _codeCtrl.text,
          cfAccessClientId: cfId.isEmpty ? null : cfId,
          cfAccessClientSecret: cfSecret.isEmpty ? null : cfSecret,
        );
      }
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Connected to server.';
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
      _isError = false;
    });
    try {
      final res = await widget.controller.syncNow();
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Synced: pushed ${res.pushedCount}, pulled ${res.pulledCount}.';
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Sync failed: $e';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final conn = widget.controller.serverConnection;
        final isPlainHttp = OpenGymServerClient.isPlainHttpRemote(_urlCtrl.text);

        return Scaffold(
          appBar: AppBar(title: const Text('Server Connection')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                color: conn != null && conn.isConnected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                child: ListTile(
                  leading: Icon(
                    conn != null && conn.isConnected
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                  ),
                  title: Text(
                    conn != null && conn.isConnected
                        ? 'Connected to ${conn.serverUrl}'
                        : 'Offline (Local-First Mode)',
                  ),
                  subtitle: Text(
                    conn != null && conn.isConnected
                        ? (conn.lastSyncedAt != null
                            ? 'Last synced: ${conn.lastSyncedAt}'
                            : 'Ready to sync')
                        : 'All workouts and measurements stay on this device.',
                  ),
                ),
              ),
              if (_statusMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                Card(
                  color: _isError
                      ? colorScheme.errorContainer
                      : colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _isError
                            ? colorScheme.onErrorContainer
                            : colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (conn != null && conn.isConnected) ...<Widget>[
                FilledButton.icon(
                  onPressed: _busy ? null : _syncNow,
                  icon: const Icon(Icons.sync),
                  label: Text(_busy ? 'Syncing...' : 'Sync Now'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          await widget.controller.disconnectServer();
                          if (mounted) {
                            setState(() {
                              _statusMessage = 'Disconnected. Switched to offline mode.';
                              _isError = false;
                            });
                          }
                        },
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect Server'),
                ),
              ] else ...<Widget>[
                Text(
                  'Connect to a Self-Hosted openGym Server',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'https://gym.example.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                ),
                if (isPlainHttp) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Warning: Plain http:// sends credentials unencrypted on your network.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Pairing Code'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Username & Password'),
                    ),
                  ],
                  selected: <bool>{_usePassword},
                  onSelectionChanged: (s) =>
                      setState(() => _usePassword = s.first),
                ),
                const SizedBox(height: 12),
                if (!_usePassword)
                  TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pairing Code',
                      hintText: 'Enter code from your openGym web settings',
                      border: OutlineInputBorder(),
                    ),
                  )
                else ...<Widget>[
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cloudflare Access Service Token'),
                  subtitle: const Text('Optional headers for Zero Trust servers'),
                  value: _showCfAccess,
                  onChanged: (v) => setState(() => _showCfAccess = v),
                ),
                if (_showCfAccess) ...<Widget>[
                  TextField(
                    controller: _cfIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'CF-Access-Client-Id',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cfSecretCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'CF-Access-Client-Secret',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _connect,
                  icon: const Icon(Icons.link),
                  label: Text(_busy ? 'Connecting...' : 'Connect'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
