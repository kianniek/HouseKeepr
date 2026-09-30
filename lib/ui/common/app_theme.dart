import 'package:flutter/material.dart';

enum AppThemeType { classic, midnight, forest, sunset }

extension AppThemeTypeX on AppThemeType {
  String get label {
    switch (this) {
      case AppThemeType.classic:
        return 'Classic';
      case AppThemeType.midnight:
        return 'Midnight';
      case AppThemeType.forest:
        return 'Forest';
      case AppThemeType.sunset:
        return 'Sunset';
    }
  }
}

/// AppThemePalette maps a theme type to explicit light/dark ColorScheme roles.
class AppThemePalette {
  final AppThemeType type;
  final Color seed;

  // Light role colors
  final Color lightPrimary;
  final Color lightOnPrimary;
  final Color lightPrimaryContainer;
  final Color lightOnPrimaryContainer;
  final Color lightSecondary;
  final Color lightTertiary;
  final Color lightSurface;
  final Color lightError;
  final Color lightOnSurface;
  final Color lightOutline;

  // Dark role colors
  final Color darkPrimary;
  final Color darkOnPrimary;
  final Color darkPrimaryContainer;
  final Color darkOnPrimaryContainer;
  final Color darkSecondary;
  final Color darkTertiary;
  final Color darkSurface;
  final Color darkError;
  final Color darkOnSurface;
  final Color darkOutline;

  const AppThemePalette._({
    required this.type,
    required this.seed,
    required this.lightPrimary,
    required this.lightOnPrimary,
    required this.lightPrimaryContainer,
    required this.lightOnPrimaryContainer,
    required this.lightSecondary,
    required this.lightTertiary,
    required this.lightSurface,
    required this.lightError,
    required this.lightOnSurface,
    required this.lightOutline,
    required this.darkPrimary,
    required this.darkOnPrimary,
    required this.darkPrimaryContainer,
    required this.darkOnPrimaryContainer,
    required this.darkSecondary,
    required this.darkTertiary,
    required this.darkSurface,
    required this.darkError,
    required this.darkOnSurface,
    required this.darkOutline,
  });

  ColorScheme lightScheme() {
    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return cs.copyWith(
      primary: lightPrimary,
      onPrimary: lightOnPrimary,
      primaryContainer: lightPrimaryContainer,
      onPrimaryContainer: lightOnPrimaryContainer,
      secondary: lightSecondary,
      tertiary: lightTertiary,
      surface: lightSurface,
      error: lightError,
      onSurface: lightOnSurface,
      outline: lightOutline,
    );
  }

  ColorScheme darkScheme() {
    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return cs.copyWith(
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkOnPrimaryContainer,
      secondary: darkSecondary,
      tertiary: darkTertiary,
      surface: darkSurface,
      error: darkError,
      onSurface: darkOnSurface,
      outline: darkOutline,
    );
  }

  static AppThemePalette forType(AppThemeType t) => _palettes[t]!;

  static const Map<AppThemeType, AppThemePalette> _palettes = {
    AppThemeType.classic: AppThemePalette._(
      type: AppThemeType.classic,
      seed: Color(0xFFF68801),
      // Light
      lightPrimary: Color(0xFFF57C00),
      lightOnPrimary: Color(0xFFFFFFFF),
      lightPrimaryContainer: Color(0xFFFFE0B2),
      lightOnPrimaryContainer: Color(0xFF3E1700),
      lightSecondary: Color(0xFF00796B),
      lightTertiary: Color(0xFF6D4C41),
      lightSurface: Color(0xFFFFFFFF),
      lightError: Color(0xFFB00020),
      lightOnSurface: Color(0xFF1F1F1F),
      lightOutline: Color(0xFFBDBDBD),
      // Dark
      darkPrimary: Color(0xFFFFAB40),
      darkOnPrimary: Color(0xFF000000),
      darkPrimaryContainer: Color(0xFF6E3200),
      darkOnPrimaryContainer: Color(0xFFFFE0B2),
      darkSecondary: Color(0xFF4DB6AC),
      darkTertiary: Color(0xFF8D6E63),
      darkSurface: Color(0xFF121212),
      darkError: Color(0xFFCF6679),
      darkOnSurface: Color(0xFFECECEC),
      darkOutline: Color(0xFF333333),
    ),
    AppThemeType.midnight: AppThemePalette._(
      type: AppThemeType.midnight,
      seed: Color(0xFF0D47A1),
      // Light
      lightPrimary: Color(0xFF0D47A1),
      lightOnPrimary: Color(0xFFFFFFFF),
      lightPrimaryContainer: Color(0xFFBBDEFB),
      lightOnPrimaryContainer: Color(0xFF001F3F),
      lightSecondary: Color(0xFF6A1B9A),
      lightTertiary: Color(0xFF00ACC1),
      lightSurface: Color(0xFFFFFFFF),
      lightError: Color(0xFFB00020),
      lightOnSurface: Color(0xFF191919),
      lightOutline: Color(0xFFB0BEC5),
      // Dark
      darkPrimary: Color(0xFF82B1FF),
      darkOnPrimary: Color(0xFF001233),
      darkPrimaryContainer: Color(0xFF0B3B6F),
      darkOnPrimaryContainer: Color(0xFFDAECFF),
      darkSecondary: Color(0xFFCE93D8),
      darkTertiary: Color(0xFF80DEEA),
      darkSurface: Color(0xFF0B0F1A),
      darkError: Color(0xFFCF6679),
      darkOnSurface: Color(0xFFE6EEF5),
      darkOutline: Color(0xFF37474F),
    ),
    AppThemeType.forest: AppThemePalette._(
      type: AppThemeType.forest,
      seed: Color(0xFF2E7D32),
      // Light
      lightPrimary: Color(0xFF2E7D32),
      lightOnPrimary: Color(0xFFFFFFFF),
      lightPrimaryContainer: Color(0xFFC8E6C9),
      lightOnPrimaryContainer: Color(0xFF071A08),
      lightSecondary: Color(0xFF558B2F),
      lightTertiary: Color(0xFF8BC34A),
      lightSurface: Color(0xFFFFFFFF),
      lightError: Color(0xFFB00020),
      lightOnSurface: Color(0xFF1A1A1A),
      lightOutline: Color(0xFF9E9E9E),
      // Dark
      darkPrimary: Color(0xFFA5D6A7),
      darkOnPrimary: Color(0xFF002104),
      darkPrimaryContainer: Color(0xFF134E18),
      darkOnPrimaryContainer: Color(0xFFDFF6DF),
      darkSecondary: Color(0xFF8BC34A),
      darkTertiary: Color(0xFF3DDC84),
      darkSurface: Color(0xFF0B130A),
      darkError: Color(0xFFCF6679),
      darkOnSurface: Color(0xFFE6F3EA),
      darkOutline: Color(0xFF294022),
    ),
    AppThemeType.sunset: AppThemePalette._(
      type: AppThemeType.sunset,
      seed: Color(0xFFFF7043),
      // Light
      lightPrimary: Color(0xFFFF7043),
      lightOnPrimary: Color(0xFFFFFFFF),
      lightPrimaryContainer: Color(0xFFFFCCBC),
      lightOnPrimaryContainer: Color(0xFF3C0B00),
      lightSecondary: Color(0xFFFF5252),
      lightTertiary: Color(0xFFFFD54F),
      lightSurface: Color(0xFFFFFFFF),
      lightError: Color(0xFFB00020),
      lightOnSurface: Color(0xFF2A2A2A),
      lightOutline: Color(0xFFBDBDBD),
      // Dark
      darkPrimary: Color(0xFFFFAB91),
      darkOnPrimary: Color(0xFF2B0000),
      darkPrimaryContainer: Color(0xFF7A2F19),
      darkOnPrimaryContainer: Color(0xFFFFDCCF),
      darkSecondary: Color(0xFFFF8A80),
      darkTertiary: Color(0xFFFFE082),
      darkSurface: Color(0xFF121212),
      darkError: Color(0xFFCF6679),
      darkOnSurface: Color(0xFFECECEC),
      darkOutline: Color(0xFF3A3A3A),
    ),
  };
}
