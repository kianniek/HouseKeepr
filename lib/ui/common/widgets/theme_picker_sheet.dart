import 'package:flutter/material.dart';

import '../../../generated/app_localizations.dart';
import '../../../services/theme_controller.dart';
import '../app_theme.dart';

Future<void> showThemePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const ThemePickerSheet(),
  );
}

class ThemePickerSheet extends StatelessWidget {
  const ThemePickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    AppLocalizations.of(context).selectTheme,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {controller.themeMode},
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty) {
                          controller.setThemeMode(selection.first);
                        }
                      },
                    ),
                  ),
                ),
                const Divider(height: 16),
                ...AppThemeType.values
                    .where(
                      (t) =>
                          t != AppThemeType.dynamic ||
                          controller.isDynamicSupported,
                    )
                    .map((t) {
                      final selected = controller.currentTheme == t;
                      final ColorScheme scheme;
                      if (t == AppThemeType.dynamic &&
                          controller.isDynamicSupported) {
                        scheme = Theme.of(context).brightness == Brightness.dark
                            ? controller.dynamicDarkScheme!
                            : controller.dynamicLightScheme!;
                      } else {
                        final palette = AppThemePalette.forType(t);
                        scheme = Theme.of(context).brightness == Brightness.dark
                            ? palette.darkScheme()
                            : palette.lightScheme();
                      }
                      final label = t == AppThemeType.dynamic
                          ? AppLocalizations.of(context).themeDynamic
                          : t.label;
                      return ListTile(
                        leading: ThemePreviewRow(scheme: scheme),
                        title: Text(label),
                        trailing: selected ? const Icon(Icons.check) : null,
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          await controller.setTheme(t);
                          navigator.maybePop();
                        },
                      );
                    }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ThemePreviewRow extends StatelessWidget {
  final ColorScheme scheme;
  const ThemePreviewRow({super.key, required this.scheme});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c) => Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(scheme.primary),
        dot(scheme.secondary),
        dot(scheme.tertiary),
        dot(scheme.surface),
      ],
    );
  }
}
