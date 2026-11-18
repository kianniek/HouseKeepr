import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/ui/common/app_theme.dart';

double _channelLuminance(double channel) {
  return channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color color) {
  final r = _channelLuminance(color.r);
  final g = _channelLuminance(color.g);
  final b = _channelLuminance(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color a, Color b) {
  final l1 = _relativeLuminance(a);
  final l2 = _relativeLuminance(b);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppThemePalette WCAG 2.1 AA Contrast Matrix', () {
    for (final type in AppThemeType.values) {
      final palette = AppThemePalette.forType(type);

      for (final brightness in [Brightness.light, Brightness.dark]) {
        test('${type.name} (${brightness.name}) meets WCAG AA thresholds', () {
          final scheme = brightness == Brightness.light
              ? palette.lightScheme()
              : palette.darkScheme();

          expect(
            _contrastRatio(scheme.primary, scheme.onPrimary),
            greaterThanOrEqualTo(4.5),
            reason: '${type.name} ${brightness.name} primary/onPrimary',
          );
          expect(
            _contrastRatio(scheme.primaryContainer, scheme.onPrimaryContainer),
            greaterThanOrEqualTo(4.5),
            reason:
                '${type.name} ${brightness.name} primaryContainer/onPrimaryContainer',
          );
          expect(
            _contrastRatio(scheme.secondary, scheme.onSecondary),
            greaterThanOrEqualTo(4.5),
            reason: '${type.name} ${brightness.name} secondary/onSecondary',
          );
          expect(
            _contrastRatio(
              scheme.secondaryContainer,
              scheme.onSecondaryContainer,
            ),
            greaterThanOrEqualTo(4.5),
            reason:
                '${type.name} ${brightness.name} secondaryContainer/onSecondaryContainer',
          );
          expect(
            _contrastRatio(scheme.tertiary, scheme.onTertiary),
            greaterThanOrEqualTo(4.5),
            reason: '${type.name} ${brightness.name} tertiary/onTertiary',
          );
          expect(
            _contrastRatio(
              scheme.tertiaryContainer,
              scheme.onTertiaryContainer,
            ),
            greaterThanOrEqualTo(4.5),
            reason:
                '${type.name} ${brightness.name} tertiaryContainer/onTertiaryContainer',
          );
          expect(
            _contrastRatio(scheme.error, scheme.onError),
            greaterThanOrEqualTo(4.5),
            reason: '${type.name} ${brightness.name} error/onError',
          );
          expect(
            _contrastRatio(scheme.surface, scheme.onSurface),
            greaterThanOrEqualTo(4.5),
            reason: '${type.name} ${brightness.name} surface/onSurface',
          );
          expect(
            _contrastRatio(scheme.outline, scheme.surface),
            greaterThanOrEqualTo(3.0),
            reason: '${type.name} ${brightness.name} outline/surface',
          );
        });
      }
    }

    test('AppSemanticColors warningContainer/onWarningContainer >= 4.5:1', () {
      expect(
        _contrastRatio(
          AppSemanticColors.light.warningContainer,
          AppSemanticColors.light.onWarningContainer,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          AppSemanticColors.dark.warningContainer,
          AppSemanticColors.dark.onWarningContainer,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
