import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/common/app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const String _prefsKey = 'app_theme_type';
  static final ThemeController instance = ThemeController._();

  ThemeController._();

  late SharedPreferences _prefs;
  AppThemeType _current = AppThemeType.classic;

  AppThemeType get currentTheme => _current;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final s = _prefs.getString(_prefsKey);
    if (s != null) {
      try {
        _current = AppThemeType.values.firstWhere((e) => e.name == s);
      } catch (_) {
        _current = AppThemeType.classic;
      }
    }
  }

  Future<void> setTheme(AppThemeType type) async {
    if (_current == type) return;
    _current = type;
    await _prefs.setString(_prefsKey, type.name);
    notifyListeners();
  }

  ColorScheme get lightScheme =>
      AppThemePalette.forType(_current).lightScheme();
  ColorScheme get darkScheme => AppThemePalette.forType(_current).darkScheme();
}
