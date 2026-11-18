import 'package:flutter/material.dart';

/// Descriptor for one routine icon choice in [showRoutineGlyphPickerSheet].
class RoutineGlyphOption {
  const RoutineGlyphOption({
    required this.key,
    required this.icon,
    required this.label,
    required this.category,
  });

  final String key;
  final IconData icon;
  final String label;
  final String category;
}

/// All 20 routine icons across 4 categories matching
/// `Plan/plan_routines_new_routine_copy_icon_sheet.png`.
const List<RoutineGlyphOption> kRoutineGlyphOptions = <RoutineGlyphOption>[
  // Strength
  RoutineGlyphOption(
    key: 'overhead_press',
    icon: Icons.accessibility_new_rounded,
    label: 'Overhead press',
    category: 'Strength',
  ),
  RoutineGlyphOption(
    key: 'barbell_row',
    icon: Icons.rowing_rounded,
    label: 'Row / Hinge',
    category: 'Strength',
  ),
  RoutineGlyphOption(
    key: 'core_torso',
    icon: Icons.shield_outlined,
    label: 'Core / Torso',
    category: 'Strength',
  ),
  RoutineGlyphOption(
    key: 'legs',
    icon: Icons.airline_seat_legroom_normal_rounded,
    label: 'Lower body',
    category: 'Strength',
  ),
  RoutineGlyphOption(
    key: 'pullup',
    icon: Icons.vertical_align_top_rounded,
    label: 'Pull-up',
    category: 'Strength',
  ),
  // Equipment
  RoutineGlyphOption(
    key: 'dumbbell',
    icon: Icons.fitness_center_rounded,
    label: 'Dumbbell',
    category: 'Equipment',
  ),
  RoutineGlyphOption(
    key: 'barbell',
    icon: Icons.horizontal_distribute_rounded,
    label: 'Barbell',
    category: 'Equipment',
  ),
  RoutineGlyphOption(
    key: 'kettlebell',
    icon: Icons.shopping_bag_outlined,
    label: 'Kettlebell',
    category: 'Equipment',
  ),
  RoutineGlyphOption(
    key: 'plate',
    icon: Icons.album_outlined,
    label: 'Plate',
    category: 'Equipment',
  ),
  RoutineGlyphOption(
    key: 'cable_stack',
    icon: Icons.view_week_outlined,
    label: 'Cable stack',
    category: 'Equipment',
  ),
  // Cardio
  RoutineGlyphOption(
    key: 'run',
    icon: Icons.directions_run_rounded,
    label: 'Run',
    category: 'Cardio',
  ),
  RoutineGlyphOption(
    key: 'bike',
    icon: Icons.directions_bike_rounded,
    label: 'Cycle',
    category: 'Cardio',
  ),
  RoutineGlyphOption(
    key: 'swim',
    icon: Icons.pool_rounded,
    label: 'Swim',
    category: 'Cardio',
  ),
  RoutineGlyphOption(
    key: 'boxing',
    icon: Icons.sports_mma_rounded,
    label: 'Combat',
    category: 'Cardio',
  ),
  RoutineGlyphOption(
    key: 'timer',
    icon: Icons.timer_outlined,
    label: 'Conditioning',
    category: 'Cardio',
  ),
  // Recovery
  RoutineGlyphOption(
    key: 'stretch',
    icon: Icons.self_improvement_rounded,
    label: 'Mobility',
    category: 'Recovery',
  ),
  RoutineGlyphOption(
    key: 'moon',
    icon: Icons.nightlight_outlined,
    label: 'Rest / Sleep',
    category: 'Recovery',
  ),
  RoutineGlyphOption(
    key: 'heart',
    icon: Icons.favorite_border_rounded,
    label: 'Heart health',
    category: 'Recovery',
  ),
  RoutineGlyphOption(
    key: 'flame',
    icon: Icons.local_fire_department_outlined,
    label: 'Metcon',
    category: 'Recovery',
  ),
  RoutineGlyphOption(
    key: 'bolt',
    icon: Icons.bolt_rounded,
    label: 'Power',
    category: 'Recovery',
  ),
];

/// Resolves [iconKey] to its Material [IconData].
IconData routineGlyphIconData(String iconKey) {
  for (final opt in kRoutineGlyphOptions) {
    if (opt.key == iconKey) return opt.icon;
  }
  return Icons.accessibility_new_rounded;
}

/// 40×40 rounded-square badge used in Plan Schedule, Plan Routines, and Loop rows.
class RoutineGlyphBadge extends StatelessWidget {
  const RoutineGlyphBadge({
    super.key,
    required this.iconKey,
    this.isRestDay = false,
    this.size = 40,
  });

  final String iconKey;
  final bool isRestDay;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isRestDay
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isRestDay ? Icons.nightlight_outlined : routineGlyphIconData(iconKey),
        size: size * 0.55,
        color: isRestDay
            ? colorScheme.onSurfaceVariant
            : colorScheme.onPrimary,
      ),
    );
  }
}

/// Opens the 4-section "Pick an icon" modal bottom sheet matching
/// `Plan/plan_routines_new_routine_copy_icon_sheet.png`.
Future<String?> showRoutineGlyphPickerSheet(
  BuildContext context, {
  required String currentIconKey,
}) {
  const categories = <String>['Strength', 'Equipment', 'Cardio', 'Recovery'];

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final colorScheme = theme.colorScheme;

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: <Widget>[
            Text(
              'Pick an icon',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            for (final category in categories) ...<Widget>[
              Text(
                category,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: kRoutineGlyphOptions
                    .where((opt) => opt.category == category)
                    .map((opt) {
                  final selected = opt.key == currentIconKey;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(sheetCtx).pop(opt.key),
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: selected
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            opt.icon,
                            color: selected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      );
    },
  );
}
