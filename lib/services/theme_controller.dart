import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/common/app_theme.dart';
import 'widget_service.dart';

/// Manages the app's fruit theme palette and light/dark/system mode.
///
/// Preferences are stored locally per signed-in user in [SharedPreferences]
/// and are never synced to the cloud.
class ThemeController extends ChangeNotifier {
  static const String _prefsKey = 'app_theme_type';
  static const String _modePrefsKey = 'app_theme_mode';
  static const MethodChannel _shortcutsChannel = MethodChannel(
    'housekeepr/shortcuts',
  );
  static final ThemeController instance = ThemeController._();

  ThemeController._();

  SharedPreferences? _prefs;
  String? _userId;
  AppThemeType _current = AppThemeType.orange;
  ThemeMode _themeMode = ThemeMode.system;
  ColorScheme? _rawDynamicLight;
  ColorScheme? _rawDynamicDark;
  ColorScheme? _dynamicLightScheme;
  ColorScheme? _dynamicDarkScheme;

  AppThemeType get currentTheme => _current;
  ThemeMode get themeMode => _themeMode;
  String? get userId => _userId;
  bool get isDynamicSupported =>
      _dynamicLightScheme != null && _dynamicDarkScheme != null;
  ColorScheme? get dynamicLightScheme => _dynamicLightScheme;
  ColorScheme? get dynamicDarkScheme => _dynamicDarkScheme;

  String get _scopedThemeKey =>
      _userId == null ? _prefsKey : '${_prefsKey}_$_userId';
  String get _scopedModeKey =>
      _userId == null ? _modePrefsKey : '${_modePrefsKey}_$_userId';

  Future<void> load({String? userId}) async {
    _userId = userId;
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
    _syncToWidgets();
  }

  /// Switches the active local user profile and reloads their local theme.
  Future<void> setUserId(String? uid) async {
    if (_userId == uid && _prefs != null) return;
    _userId = uid;
    _prefs ??= await SharedPreferences.getInstance();
    _loadFromPrefs();
    notifyListeners();
    _syncToWidgets();
  }

  void _loadFromPrefs() {
    final savedTheme = _prefs?.getString(_scopedThemeKey);
    _current = savedTheme != null
        ? AppThemePalette.typeFromName(savedTheme)
        : AppThemeType.orange;

    final modeStr = _prefs?.getString(_scopedModeKey);
    _themeMode = modeStr != null
        ? ThemeMode.values.firstWhere(
            (m) => m.name == modeStr,
            orElse: () => ThemeMode.system,
          )
        : ThemeMode.system;
  }

  Future<void> setTheme(AppThemeType type) async {
    if (_current == type) return;
    _current = type;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_scopedThemeKey, type.name);
    notifyListeners();
    _syncToWidgets();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_scopedModeKey, mode.name);
    notifyListeners();
    _syncToWidgets();
  }

  void _syncToWidgets() {
    unawaited(
      WidgetService.instance.syncThemeToWidgets(
        appTheme: _current,
        appMode: _themeMode,
      ),
    );
    _syncToShortcuts();
  }

  void _syncToShortcuts() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    unawaited(_invokeUpdateShortcutTheme());
  }

  Future<void> _invokeUpdateShortcutTheme() async {
    try {
      await _shortcutsChannel.invokeMethod<bool>('updateShortcutTheme', {
        'themeMode': _themeMode.name,
        'lightPrimary': lightScheme.primary.toARGB32(),
        'lightBackground': lightScheme.surface.toARGB32(),
        'darkPrimary': darkScheme.primary.toARGB32(),
        'darkBackground': darkScheme.surface.toARGB32(),
      });
    } on MissingPluginException {
      // Ignored on platforms/tests without the Android shortcut bridge.
    } on PlatformException catch (e) {
      debugPrint('ThemeController: failed to sync shortcut theme: $e');
    }
  }

  /// Caches wallpaper ColorSchemes supplied by [DynamicColorBuilder].
  void updateDynamicSchemes(ColorScheme? light, ColorScheme? dark) {
    if (_rawDynamicLight == light && _rawDynamicDark == dark) return;
    _rawDynamicLight = light;
    _rawDynamicDark = dark;
    _dynamicLightScheme = light?.harmonizedWithPrimary();
    _dynamicDarkScheme = dark?.harmonizedWithPrimary();
    if (_current == AppThemeType.dynamic) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
        _syncToWidgets();
      });
    }
  }

  ColorScheme get lightScheme {
    if (_current == AppThemeType.dynamic && _dynamicLightScheme != null) {
      return _dynamicLightScheme!;
    }
    return AppThemePalette.forType(
      _current,
    ).lightScheme().harmonizedWithPrimary();
  }

  ColorScheme get darkScheme {
    if (_current == AppThemeType.dynamic && _dynamicDarkScheme != null) {
      return _dynamicDarkScheme!;
    }
    return AppThemePalette.forType(
      _current,
    ).darkScheme().harmonizedWithPrimary();
  }
}
