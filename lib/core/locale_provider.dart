import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_repository.dart';

/// Manages the active app locale and notifies listeners when it changes.
/// The selected locale is persisted via [SettingsRepository].
/// Access via the singleton [LocaleProvider.instance].
class LocaleProvider extends ChangeNotifier {
  static const List<Locale> supportedLocales = [Locale('en'), Locale('nl')];

  static final LocaleProvider instance = LocaleProvider._();

  LocaleProvider._();

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  /// Loads the previously saved locale from SharedPreferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsRepository(prefs);
    final code = settings.getLocaleCode();
    _locale = Locale(code);
    notifyListeners();
  }

  /// Switches the active locale and persists the choice.
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsRepository(prefs);
    await settings.setLocaleCode(locale.languageCode);
  }
}
