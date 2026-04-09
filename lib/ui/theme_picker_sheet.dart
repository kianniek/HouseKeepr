import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../services/theme_controller.dart';

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
                    'Select theme',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ...AppThemeType.values.map((t) {
                  final selected = controller.currentTheme == t;
                  final palette = AppThemePalette.forType(t);
                  final scheme = Theme.of(context).brightness == Brightness.dark
                      ? palette.darkScheme()
                      : palette.lightScheme();
                  return ListTile(
                    leading: ThemePreviewRow(scheme: scheme),
                    title: Text(t.label),
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
        border: Border.all(color: Colors.black12),
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
