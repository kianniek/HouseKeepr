import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/services/theme_controller.dart';
import 'package:housekeepr/ui/common/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeController persists theme type and themeMode override', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController.instance;
    await controller.load();

    expect(controller.currentTheme, AppThemeType.classic);
    expect(controller.themeMode, ThemeMode.system);

    await controller.setTheme(AppThemeType.forest);
    await controller.setThemeMode(ThemeMode.dark);

    expect(controller.currentTheme, AppThemeType.forest);
    expect(controller.themeMode, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme_type'), 'forest');
    expect(prefs.getString('app_theme_mode'), 'dark');
  });
}
