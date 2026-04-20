import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

import '../core/settings_repository.dart';
import '../home_screen.dart';
import '../services/notification_service.dart';

/// Settings page now exposes notification scheduling controls: enable/disable
/// and start/end of day times. Changes are persisted via `SettingsRepository`
/// and applied to the `NotificationService` immediately.

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsRepository? _settings;
  bool _enabled = true;
  bool _useFloatingNav = true;
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsRepository(prefs);
    setState(() {
      _settings = s;
      _enabled = s.notificationsEnabled();
      _useFloatingNav = s.useFloatingNav();
      _start = s.notificationStart();
      _end = s.notificationEnd();
      _loading = false;
    });
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t == null) return;
    setState(() => _start = t);
    await _settings?.setNotificationStart(t);
    await NotificationService.instance.scheduleDailyStartEnd(
      enabled: _enabled,
      start: _start,
      end: _end,
    );
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t == null) return;
    setState(() => _end = t);
    await _settings?.setNotificationEnd(t);
    await NotificationService.instance.scheduleDailyStartEnd(
      enabled: _enabled,
      start: _start,
      end: _end,
    );
  }

  Future<void> _toggleEnabled(bool v) async {
    setState(() => _enabled = v);
    await _settings?.setNotificationsEnabled(v);
    await NotificationService.instance.scheduleDailyStartEnd(
      enabled: _enabled,
      start: _start,
      end: _end,
    );
  }

  Future<void> _toggleFloatingNav(bool v) async {
    setState(() => _useFloatingNav = v);
    await _settings?.setUseFloatingNav(v);
    // Notify HomeScreen immediately so the nav style switches in real time.
    HomeScreen.floatingNavNotifier.value = v;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Floating pill navigation'),
            subtitle: const Text('Use a floating navigation bar style'),
            value: _useFloatingNav,
            onChanged: _toggleFloatingNav,
          ),
          SwitchListTile(
            title: const Text('Daily notifications'),
            subtitle: const Text('Receive a summary at start and end of day'),
            value: _enabled,
            onChanged: _toggleEnabled,
          ),
          ListTile(
            title: const Text('Start of day time'),
            subtitle: Text(_start.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: _pickStart,
          ),
          ListTile(
            title: const Text('End of day time'),
            subtitle: Text(_end.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: _pickEnd,
          ),
          ExpansionTile(
            title: const Text('Diagnostics'),
            leading: const Icon(Icons.bug_report),
            children: [
              ListTile(
                title: const Text('Test notification'),
                subtitle: const Text('Send a test notification now'),
                trailing: const Icon(Icons.notifications_active),
                onTap: () async {
                  await NotificationService.instance.showTestNotification();
                },
              ),
              ListTile(
                title: const Text('Test splashscreen'),
                subtitle: const Text('Play the startup animation'),
                trailing: const Icon(Icons.play_circle_fill),
                onTap: () {
                  _showTestSplash();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showTestSplash() async {
    await Navigator.of(context).push(_TestSplashRoute());
  }
}

class _TestSplashRoute extends PageRouteBuilder<void> {
  _TestSplashRoute()
    : super(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _TestSplashScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      );
}

class _TestSplashScreen extends StatefulWidget {
  const _TestSplashScreen();

  @override
  State<_TestSplashScreen> createState() => _TestSplashScreenState();
}

class _TestSplashScreenState extends State<_TestSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final splashBackground = Theme.of(context).colorScheme.surface;
    final splashPrimary = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: splashBackground,
        body: SafeArea(
          child: Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.width * 0.7,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(splashPrimary, BlendMode.srcIn),
                child: Opacity(
                  // 0.99 forces a saveLayer, which merges the overlapping
                  // paths into a single flat shape before drawing.
                  opacity: 0.99,
                  child: Lottie.asset(
                    'assets/HouseKeeprAnimationLottie.json',
                    controller: _controller,
                    fit: BoxFit.contain,
                    animate: false,
                    repeat: false,
                    onLoaded: (composition) {
                      _controller.duration = composition.duration;
                      _controller.forward(from: 0);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
