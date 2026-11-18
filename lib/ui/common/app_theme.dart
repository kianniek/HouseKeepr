import 'package:flutter/material.dart';

enum AppThemeType { orange, strawberry, blueberry, lime, grape }

extension AppThemeTypeX on AppThemeType {
  String get label {
    switch (this) {
      case AppThemeType.orange:
        return 'Orange';
      case AppThemeType.strawberry:
        return 'Strawberry';
      case AppThemeType.blueberry:
        return 'Blueberry';
      case AppThemeType.lime:
        return 'Lime';
      case AppThemeType.grape:
        return 'Grape';
    }
  }
}

/// Semantic colors beyond core [ColorScheme] roles with full Light/Dark parity.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color warningContainer;
  final Color onWarningContainer;
  final Color daytimeAccent;
  final Color eveningAccent;
  final Color favoriteAccent;

  const AppSemanticColors({
    required this.warningContainer,
    required this.onWarningContainer,
    required this.daytimeAccent,
    required this.eveningAccent,
    required this.favoriteAccent,
  });

  static const AppSemanticColors light = AppSemanticColors(
    warningContainer: Color(0xFFFFF3CD),
    onWarningContainer: Color(0xFF5D3A00),
    daytimeAccent: Color(0xFFB26A00),
    eveningAccent: Color(0xFF3F51B5),
    favoriteAccent: Color(0xFFB26A00),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    warningContainer: Color(0xFF4A3200),
    onWarningContainer: Color(0xFFFFDF8F),
    daytimeAccent: Color(0xFFFFCA28),
    eveningAccent: Color(0xFF9FA8DA),
    favoriteAccent: Color(0xFFFFCA28),
  );

  static AppSemanticColors of(BuildContext context) {
    final ext = Theme.of(context).extension<AppSemanticColors>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  @override
  AppSemanticColors copyWith({
    Color? warningContainer,
    Color? onWarningContainer,
    Color? daytimeAccent,
    Color? eveningAccent,
    Color? favoriteAccent,
  }) {
    return AppSemanticColors(
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      daytimeAccent: daytimeAccent ?? this.daytimeAccent,
      eveningAccent: eveningAccent ?? this.eveningAccent,
      favoriteAccent: favoriteAccent ?? this.favoriteAccent,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      daytimeAccent: Color.lerp(daytimeAccent, other.daytimeAccent, t)!,
      eveningAccent: Color.lerp(eveningAccent, other.eveningAccent, t)!,
      favoriteAccent: Color.lerp(favoriteAccent, other.favoriteAccent, t)!,
    );
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
    final ter = ColorScheme.fromSeed(
      seedColor: lightTertiary,
      brightness: Brightness.light,
    );
    return cs.copyWith(
      primary: lightPrimary,
      onPrimary: lightOnPrimary,
      primaryContainer: lightPrimaryContainer,
      onPrimaryContainer: lightOnPrimaryContainer,
      tertiary: ter.primary,
      onTertiary: ter.onPrimary,
      tertiaryContainer: ter.primaryContainer,
      onTertiaryContainer: ter.onPrimaryContainer,
      error: lightError,
      onError: const Color(0xFFFFFFFF),
      onSurface: lightOnSurface,
    );
  }

  ColorScheme darkScheme() {
    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    final ter = ColorScheme.fromSeed(
      seedColor: darkTertiary,
      brightness: Brightness.dark,
    );
    return cs.copyWith(
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkOnPrimaryContainer,
      tertiary: ter.primary,
      onTertiary: ter.onPrimary,
      tertiaryContainer: ter.primaryContainer,
      onTertiaryContainer: ter.onPrimaryContainer,
      surface: darkSurface,
      error: darkError,
      onError: const Color(0xFF000000),
      onSurface: darkOnSurface,
    );
  }

  static AppThemePalette forType(AppThemeType t) => _palettes[t]!;

  /// Lookup [AppThemeType] by enum or legacy name, falling back to [AppThemeType.orange].
  static AppThemeType typeFromName(String? name) {
    switch (name) {
      case 'classic':
        return AppThemeType.orange;
      case 'midnight':
        return AppThemeType.blueberry;
      case 'forest':
        return AppThemeType.lime;
      case 'sunset':
        return AppThemeType.strawberry;
      default:
        return AppThemeType.values.firstWhere(
          (e) => e.name == name,
          orElse: () => AppThemeType.orange,
        );
    }
  }

  /// Lookup palette by enum name, falling back to [AppThemeType.orange].
  static AppThemePalette forName(String? name) => forType(typeFromName(name));

  /// Exports ARGB color integers for Android home-screen widgets.
  Map<String, int> toWidgetColorsMap(Brightness brightness) {
    final scheme = brightness == Brightness.dark ? darkScheme() : lightScheme();
    return {
      'surface': scheme.surface.toARGB32(),
      'surfaceContainer': scheme.surfaceContainerHighest.toARGB32(),
      'onSurface': scheme.onSurface.toARGB32(),
      'onSurfaceVariant': scheme.onSurfaceVariant.toARGB32(),
      'primary': scheme.primary.toARGB32(),
      'onPrimary': scheme.onPrimary.toARGB32(),
      'primaryContainer': scheme.primaryContainer.toARGB32(),
      'onPrimaryContainer': scheme.onPrimaryContainer.toARGB32(),
      'outline': scheme.outline.toARGB32(),
    };
  }

  static const Map<AppThemeType, AppThemePalette> _palettes = {
    AppThemeType.orange: AppThemePalette._(
      type: AppThemeType.orange,
      seed: Color(0xFFF68801),
      // Light (WCAG AA >= 4.5:1 onPrimary/primary)
      lightPrimary: Color(0xFFC65102),
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
    AppThemeType.strawberry: AppThemePalette._(
      type: AppThemeType.strawberry,
      seed: Color(0xFFE53935),
      // Light
      lightPrimary: Color(0xFFC62828),
      lightOnPrimary: Color(0xFFFFFFFF),
      lightPrimaryContainer: Color(0xFFFFCDD2),
      lightOnPrimaryContainer: Color(0xFF410002),
      lightSecondary: Color(0xFF00897B),
      lightTertiary: Color(0xFFFF7043),
      lightSurface: Color(0xFFFFFFFF),
      lightError: Color(0xFFB00020),
      lightOnSurface: Color(0xFF1F1F1F),
      lightOutline: Color(0xFFBDBDBD),
      // Dark
      darkPrimary: Color(0xFFFF6B6B),
      darkOnPrimary: Color(0xFF2B0000),
      darkPrimaryContainer: Color(0xFF7F1D1D),
      darkOnPrimaryContainer: Color(0xFFFFDAD6),
      darkSecondary: Color(0xFF4DB6AC),
      darkTertiary: Color(0xFFFFAB91),
      darkSurface: Color(0xFF121212),
      darkError: Color(0xFFCF6679),
      darkOnSurface: Color(0xFFECECEC),
      darkOutline: Color(0xFF3A3A3A),
    ),
    AppThemeType.blueberry: AppThemePalette._(
      type: AppThemeType.blueberry,
      seed: Color(0xFF1E88E5),
      // Light
      lightPrimary: Color(0xFF1565C0),
      lightOnPrimary: Color(0xFFFFFFFF),
      lightPrimaryContainer: Color(0xFFBBDEFB),
      lightOnPrimaryContainer: Color(0xFF001D36),
      lightSecondary: Color(0xFF7B1FA2),
      lightTertiary: Color(0xFF00ACC1),
      lightSurface: Color(0xFFFFFFFF),
      lightError: Color(0xFFB00020),
      lightOnSurface: Color(0xFF191919),
      lightOutline: Color(0xFFB0BEC5),
      // Dark
      darkPrimary: Color(0xFF64B5F6),
      darkOnPrimary: Color(0xFF001833),
      darkPrimaryContainer: Color(0xFF0D47A1),
      darkOnPrimaryContainer: Color(0xFFD6E9FF),
      darkSecondary: Color(0xFFCE93D8),
      darkTertiary: Color(0xFF4DD0E1),
      darkSurface: Color(0xFF0D111A),
      darkError: Color(0xFFCF6679),
      darkOnSurface: Color(0xFFE6EEF5),
      darkOutline: Color(0xFF37474F),
    ),
    AppThemeType.lime: AppThemePalette._(
      type: AppThemeType.lime,
      seed: Color(0xFF43A047),
      // Light
      lightPrimary: Color(0xFF2E7D32),
      lightOnPrimary: Color(0xFFFFFFFF),
      lightPrimaryContainer: Color(0xFFC8E6C9),
      lightOnPrimaryContainer: Color(0xFF052107),
      lightSecondary: Color(0xFF00897B),
      lightTertiary: Color(0xFFFBC02D),
      lightSurface: Color(0xFFFFFFFF),
      lightError: Color(0xFFB00020),
      lightOnSurface: Color(0xFF1A1A1A),
      lightOutline: Color(0xFFBDBDBD),
      // Dark
      darkPrimary: Color(0xFF69F0AE),
      darkOnPrimary: Color(0xFF00210E),
      darkPrimaryContainer: Color(0xFF1B5E20),
      darkOnPrimaryContainer: Color(0xFFD7F9DB),
      darkSecondary: Color(0xFF4DB6AC),
      darkTertiary: Color(0xFFFFEE58),
      darkSurface: Color(0xFF0E140F),
      darkError: Color(0xFFCF6679),
      darkOnSurface: Color(0xFFE6F3EA),
      darkOutline: Color(0xFF2E4432),
    ),
    AppThemeType.grape: AppThemePalette._(
      type: AppThemeType.grape,
      seed: Color(0xFF8E24AA),
      // Light
      lightPrimary: Color(0xFF7B1FA2),
      lightOnPrimary: Color(0xFFFFFFFF),
      lightPrimaryContainer: Color(0xFFE1BEE7),
      lightOnPrimaryContainer: Color(0xFF2C003E),
      lightSecondary: Color(0xFFD81B60),
      lightTertiary: Color(0xFF00ACC1),
      lightSurface: Color(0xFFFFFFFF),
      lightError: Color(0xFFB00020),
      lightOnSurface: Color(0xFF1F1F1F),
      lightOutline: Color(0xFFBDBDBD),
      // Dark
      darkPrimary: Color(0xFFCE93D8),
      darkOnPrimary: Color(0xFF260033),
      darkPrimaryContainer: Color(0xFF4A148C),
      darkOnPrimaryContainer: Color(0xFFF3E5F5),
      darkSecondary: Color(0xFFF48FB1),
      darkTertiary: Color(0xFF80DEEA),
      darkSurface: Color(0xFF140E18),
      darkError: Color(0xFFCF6679),
      darkOnSurface: Color(0xFFEDE7F6),
      darkOutline: Color(0xFF3E2E4A),
    ),
  };
}
