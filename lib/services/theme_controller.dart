import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/common/app_theme.dart';
import 'widget_service.dart';

class ThemeController extends ChangeNotifier {
  static const String _prefsKey = 'app_theme_type';
  static const String _modePrefsKey = 'app_theme_mode';
  static final ThemeController instance = ThemeController._();

  ThemeController._();

  SharedPreferences? _prefs;
  AppThemeType _current = AppThemeType.classic;
  ThemeMode _themeMode = ThemeMode.system;

  AppThemeType get currentTheme => _current;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final s = _prefs?.getString(_prefsKey);
    if (s != null) {
      _current = AppThemeType.values.firstWhere(
        (e) => e.name == s,
        orElse: () => AppThemeType.classic,
      );
    }
    final modeStr = _prefs?.getString(_modePrefsKey);
    if (modeStr != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == modeStr,
        orElse: () => ThemeMode.system,
      );
    }
    unawaited(
      WidgetService.instance.syncThemeToWidgets(
        appTheme: _current,
        appMode: _themeMode,
      ),
    );
  }

  Future<void> setTheme(AppThemeType type) async {
    if (_current == type) return;
    _current = type;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_prefsKey, type.name);
    notifyListeners();
    unawaited(
      WidgetService.instance.syncThemeToWidgets(
        appTheme: _current,
        appMode: _themeMode,
      ),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_modePrefsKey, mode.name);
    notifyListeners();
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
