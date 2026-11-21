import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/settings_repository.dart';

/// Semantic haptic feedback types mapped to native Android
/// [HapticFeedbackConstants] via `housekeepr/haptics`.
enum AppHapticType {
  confirm,
  reject,
  toggleOn,
  toggleOff,
  tick,
  segmentTick,
  gestureStart,
  gestureEnd,
  longPress,
}

/// Centralized semantic haptic feedback helper respecting the user's
/// in-app haptics preference and OS haptic settings.
class AppHaptics {
  AppHaptics._();

  static final AppHaptics instance = AppHaptics._();

  static const MethodChannel channel = MethodChannel('housekeepr/haptics');

  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> load([SharedPreferences? prefsOverride]) async {
    try {
      final prefs = prefsOverride ?? await SharedPreferences.getInstance();
      _enabled = SettingsRepository(prefs).hapticsEnabled();
    } catch (_) {
      _enabled = true;
    }
  }

  Future<void> setEnabled(
    bool value, {
    SharedPreferences? prefsOverride,
  }) async {
    _enabled = value;
    try {
      final prefs = prefsOverride ?? await SharedPreferences.getInstance();
      await SettingsRepository(prefs).setHapticsEnabled(value);
    } catch (_) {}
  }

  void confirm() => _perform(AppHapticType.confirm);
  void reject() => _perform(AppHapticType.reject);
  void toggleOn() => _perform(AppHapticType.toggleOn);
  void toggleOff() => _perform(AppHapticType.toggleOff);
  void tick() => _perform(AppHapticType.tick);
  void segmentTick() => _perform(AppHapticType.segmentTick);
  void gestureStart() => _perform(AppHapticType.gestureStart);
  void gestureEnd() => _perform(AppHapticType.gestureEnd);
  void longPress() => _perform(AppHapticType.longPress);

  void _perform(AppHapticType type) {
    if (!_enabled || kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_invokeAndroid(type));
      return;
    }
    unawaited(_fallbackFlutterHaptic(type));
  }

  Future<void> _invokeAndroid(AppHapticType type) async {
    try {
      await channel.invokeMethod<bool>('perform', <String, String>{
        'type': type.name,
      });
    } on MissingPluginException {
      await _fallbackFlutterHaptic(type);
    } on PlatformException {
      // Ignore platform errors (e.g. headless environments)
    }
  }

  Future<void> _fallbackFlutterHaptic(AppHapticType type) async {
    try {
      switch (type) {
        case AppHapticType.confirm:
        case AppHapticType.gestureEnd:
          await HapticFeedback.mediumImpact();
        case AppHapticType.reject:
        case AppHapticType.longPress:
          await HapticFeedback.heavyImpact();
        case AppHapticType.toggleOn:
        case AppHapticType.toggleOff:
        case AppHapticType.gestureStart:
          await HapticFeedback.lightImpact();
        case AppHapticType.tick:
        case AppHapticType.segmentTick:
          await HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }
}
