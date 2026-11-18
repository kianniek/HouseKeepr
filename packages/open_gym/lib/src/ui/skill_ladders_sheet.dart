import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../state/open_gym_controller.dart';
import 'active_workout_screen.dart';

/// Calisthenics progression ladders modal bottom sheet matching
/// `skill_ladders_1.png` through `skill_ladders_7.png`.
Future<void> showSkillLaddersSheet(
  BuildContext context,
  OpenGymController controller,
) {
  final customLadders = <_SkillLadder>[];

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final loggedNames = controller.history
            .expand((w) => w.entries)
            .where((e) => e.sets.any((s) => s.isCompleted))
            .map((e) => e.exerciseName.toLowerCase())
            .toSet();
        final allLadders = <_SkillLadder>[..._ladders, ...customLadders];

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: <Widget>[
                Text(
                  'Skill ladders',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bodyweight moves from easier to harder. Own every set at the top of the range and the next rung is yours.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ...allLadders.map((ladder) {
                  int highestDone = -1;
                  for (var r = 0; r < ladder.rungs.length; r++) {
                    final rungLower = ladder.rungs[r].toLowerCase();
                    if (loggedNames.any((n) => n.contains(rungLower))) {
                      highestDone = r;
                    }
                  }
                  final currentRung = (highestDone + 1)
                      .clamp(0, ladder.rungs.length - 1);
                  final statusText = highestDone < 0
                      ? 'Not started'
                      : 'Rung ${highestDone + 1} of ${ladder.rungs.length}';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                ladder.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                statusText,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: highestDone >= 0
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: highestDone >= 0
                                      ? FontWeight.w600
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...ladder.rungs.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final isDone = idx <= highestDone;
                            final isCurrent = idx == currentRung;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    isDone
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: 20,
                                    color: isDone || isCurrent
                                        ? colorScheme.primary
                                        : colorScheme.outline,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      style: isCurrent
                                          ? theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            )
                                          : theme.textTheme.bodyMedium?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                    ),
                                  ),
                                  if (isCurrent)
                                    Text(
                                      highestDone < 0
                                          ? 'Start here'
                                          : 'Up next',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              controller.startEmptyWorkout(title: ladder.title);
                              final targetRung = ladder.rungs[currentRung];
                              final match = controller.exercises.where(
                                (e) => e.name.toLowerCase().contains(
                                      targetRung.split(' ').first.toLowerCase(),
                                    ),
                              ).firstOrNull;
                              controller.addExerciseToActiveWorkout(
                                match ??
                                    Exercise.create(
                                      name: targetRung,
                                      bodyPart: ladder.bodyPart,
                                      equipment: 'body weight',
                                      target: ladder.bodyPart,
                                    ),
                              );
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => ActiveWorkoutScreen(
                                    controller: controller,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Train it'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: () async {
                    final nameCtrl = TextEditingController();
                    final rungsCtrl = TextEditingController();
                    final created = await showDialog<_SkillLadder>(
                      context: sheetContext,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('New skill ladder'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            TextField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ladder name',
                                hintText: 'e.g. Muscle-up ladder',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: rungsCtrl,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Rungs (comma separated)',
                                hintText: 'Chest-to-bar Pull-Up, Explosive Pull-Up, Muscle-Up',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              final title = nameCtrl.text.trim();
                              final rungs = rungsCtrl.text
                                  .split(',')
                                  .map((s) => s.trim())
                                  .where((s) => s.isNotEmpty)
                                  .toList();
                              if (title.isEmpty || rungs.isEmpty) return;
                              Navigator.of(dialogCtx).pop(
                                _SkillLadder(
                                  title: title,
                                  bodyPart: 'full body',
                                  rungs: rungs,
                                ),
                              );
                            },
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    );
                    if (created != null) {
                      setSheetState(() => customLadders.add(created));
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Make your own ladder'),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class _SkillLadder {
  const _SkillLadder({
    required this.title,
    required this.bodyPart,
    required this.rungs,
  });

  final String title;
  final String bodyPart;
  final List<String> rungs;
}

const List<_SkillLadder> _ladders = <_SkillLadder>[
  _SkillLadder(
    title: 'Push-up ladder',
    bodyPart: 'chest',
    rungs: <String>[
      'Push-Up (Wall)',
      'Incline Push-Up',
      'Kneeling Push-Up',
      'Push-Up',
      'Diamond Push-Up',
      'Archer Push Up',
      'Single Arm Push-Up',
    ],
  ),
  _SkillLadder(
    title: 'Pull-up ladder',
    bodyPart: 'back',
    rungs: <String>[
      'Inverted Row',
      'Band Assisted Pull-Up',
      'Chin Up (Isometric And Negative)',
      'Chin-Up',
      'Pull-Up',
      'Archer Pull Up',
    ],
  ),
  _SkillLadder(
    title: 'Dip ladder',
    bodyPart: 'chest',
    rungs: <String>[
      'Bench Dip',
      'Band Assisted Dip',
      'Parallel Bar Dip',
      'Ring Dip',
      'Weighted Dip',
    ],
  ),
  _SkillLadder(
    title: 'Squat ladder',
    bodyPart: 'upper legs',
    rungs: <String>[
      'Bodyweight Box Squat',
      'Bodyweight Squat',
      'Split Squat',
      'Shrimp Squat',
      'Pistol Squat',
    ],
  ),
  _SkillLadder(
    title: 'Hinge ladder',
    bodyPart: 'upper legs',
    rungs: <String>[
      'Glute Bridge',
      'Single-Leg Glute Bridge',
      'Hip Thrust',
      'Romanian Deadlift',
      'Nordic Hamstring Curl',
    ],
  ),
  _SkillLadder(
    title: 'Core ladder',
    bodyPart: 'waist',
    rungs: <String>[
      'Forearm Plank',
      'Hollow Hold',
      'Hanging Knee Raise',
      'Hanging Leg Raise',
      'Dragon Flag',
    ],
  ),
  _SkillLadder(
    title: 'Handstand ladder',
    bodyPart: 'shoulders',
    rungs: <String>[
      'Pike Push-Up',
      'Elevated Pike Push-Up',
      'Wall Handstand Hold',
      'Wall Handstand Push-Up',
      'Freestanding Handstand',
    ],
  ),
];
