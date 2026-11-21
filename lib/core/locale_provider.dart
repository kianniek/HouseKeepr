import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_repository.dart';

/// Manages the active app locale and notifies listeners when it changes.
///
/// A `null` [locale] represents System default. On Android 13+ (API 33+),
/// choices are bidirectionally synchronized with Android's per-app
/// `LocaleManager` via `housekeepr/locale`.
class LocaleProvider extends ChangeNotifier {
  static const List<Locale> supportedLocales = [Locale('en'), Locale('nl')];
  static const MethodChannel channel = MethodChannel('housekeepr/locale');

  static final LocaleProvider instance = LocaleProvider._();

  LocaleProvider._();

  Locale? _locale;
  bool _channelHandlerRegistered = false;

  Locale? get locale => _locale;

  static Locale? normalizeSupportedCode(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    final lower = code.trim().toLowerCase().split(RegExp('[-_]')).first;
    for (final supported in supportedLocales) {
      if (supported.languageCode == lower) {
        return supported;
      }
    }
    return null;
  }

  void _ensureChannelHandler() {
    if (_channelHandlerRegistered || kIsWeb) return;
    _channelHandlerRegistered = true;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onSystemLocaleChanged') {
        final code = call.arguments as String?;
        final next = normalizeSupportedCode(code);
        await _applyLocaleFromSystem(next);
      }
    });
  }

  Future<void> _applyLocaleFromSystem(
    Locale? next, {
    SharedPreferences? prefsOverride,
  }) async {
    try {
      final prefs = prefsOverride ?? await SharedPreferences.getInstance();
      final settings = SettingsRepository(prefs);
      await settings.setLocaleCode(next?.languageCode);
      await settings.setLocaleMigrated(true);
    } catch (_) {}
    if (_locale == next) return;
    _locale = next;
    notifyListeners();
  }

  /// Loads the active locale, syncing with Android 13+ `LocaleManager` when
  /// supported and performing a one-time migration from legacy prefs.
  Future<void> load([SharedPreferences? prefsOverride]) async {
    _ensureChannelHandler();
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final settings = SettingsRepository(prefs);
    final savedCode = settings.getLocaleCode();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final state = await channel.invokeMapMethod<String, dynamic>(
          'getAppLocale',
        );
        if (state != null && state['supported'] == true) {
          final osLocale = normalizeSupportedCode(
            state['languageCode'] as String?,
          );
          if (osLocale != null) {
            _locale = osLocale;
            await settings.setLocaleCode(osLocale.languageCode);
            await settings.setLocaleMigrated(true);
          } else if (!settings.isLocaleMigrated() && savedCode != null) {
            final legacy = normalizeSupportedCode(savedCode);
            _locale = legacy;
            await settings.setLocaleMigrated(true);
            if (legacy != null) {
              await channel.invokeMethod<bool>(
                'setAppLocale',
                <String, String?>{'languageCode': legacy.languageCode},
              );
            }
          } else {
            _locale = null;
            await settings.setLocaleCode(null);
            await settings.setLocaleMigrated(true);
          }
          notifyListeners();
          return;
        }
      } on MissingPluginException {
        // Fall through to SharedPreferences in tests or non-Android hosts.
      } on PlatformException {
        // Fall through to SharedPreferences if bridge invocation fails.
      }
    }

    _locale = normalizeSupportedCode(savedCode);
    notifyListeners();
  }

  /// Switches the active locale (`null` for System default) and persists the choice.
  Future<void> setLocale(
    Locale? locale, {
    SharedPreferences? prefsOverride,
  }) async {
    final normalized = normalizeSupportedCode(locale?.languageCode);
    if (_locale != normalized) {
      _locale = normalized;
      notifyListeners();
    }

    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final settings = SettingsRepository(prefs);
    await settings.setLocaleCode(normalized?.languageCode);
    await settings.setLocaleMigrated(true);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await channel.invokeMethod<bool>('setAppLocale', <String, String?>{
          'languageCode': normalized?.languageCode,
        });
      } on MissingPluginException {
        // Ignored in tests
      } on PlatformException {
        // Ignored if unavailable
      }
    }
  }
}
