import 'dart:async';

import 'package:flutter/material.dart';
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
  static final ThemeController instance = ThemeController._();

  ThemeController._();

  SharedPreferences? _prefs;
  String? _userId;
  AppThemeType _current = AppThemeType.orange;
  ThemeMode _themeMode = ThemeMode.system;

  AppThemeType get currentTheme => _current;
  ThemeMode get themeMode => _themeMode;
  String? get userId => _userId;

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
  }

  ColorScheme get lightScheme =>
      AppThemePalette.forType(_current).lightScheme();
  ColorScheme get darkScheme => AppThemePalette.forType(_current).darkScheme();
}
