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

    expect(controller.currentTheme, AppThemeType.orange);
    expect(controller.themeMode, ThemeMode.system);

    await controller.setTheme(AppThemeType.lime);
    await controller.setThemeMode(ThemeMode.dark);

    expect(controller.currentTheme, AppThemeType.lime);
    expect(controller.themeMode, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme_type'), 'lime');
    expect(prefs.getString('app_theme_mode'), 'dark');
  });

  test('ThemeController isolates local themes per user', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController.instance;
    await controller.load(userId: 'userA');

    expect(controller.currentTheme, AppThemeType.orange);
    await controller.setTheme(AppThemeType.strawberry);
    await controller.setThemeMode(ThemeMode.light);

    await controller.setUserId('userB');
    expect(controller.currentTheme, AppThemeType.orange);
    expect(controller.themeMode, ThemeMode.system);

    await controller.setTheme(AppThemeType.grape);
    await controller.setThemeMode(ThemeMode.dark);

    await controller.setUserId('userA');
    expect(controller.currentTheme, AppThemeType.strawberry);
    expect(controller.themeMode, ThemeMode.light);
  });
}
