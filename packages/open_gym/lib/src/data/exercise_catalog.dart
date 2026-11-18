import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/exercise.dart';
import '../models/workout_template.dart';

/// Built-in exercise library and starter routines ported from OpenGym.
class ExerciseCatalog {
  ExerciseCatalog._();

  static const String _seedTimestamp = '2026-01-01T00:00:00.000Z';
  static const String _assetPath = 'packages/open_gym/assets/exercises.json';

  /// Loads the full bundled 5,632-exercise openGym catalogue from assets.
  ///
  /// Falls back to [builtInExercises] if the asset bundle is unavailable
  /// (e.g. in pure Dart unit tests).
  static Future<List<Exercise>> loadBundledExercises() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final result = <Exercise>[];
        for (final item in decoded) {
          if (item is Map) {
            result.add(Exercise.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        return result;
      }
    } catch (_) {
      // Fallback to built-in curated list when asset bundle is not present.
    }
    return List<Exercise>.from(builtInExercises);
  }

  static final List<Exercise> builtInExercises = <Exercise>[
    const Exercise(
      id: '0025',
      name: 'Barbell Bench Press',
      bodyPart: 'chest',
      equipment: 'barbell',
      target: 'pectorals',
      secondaryMuscles: <String>['triceps', 'front delts'],
      category: 'strength',
      description:
          'Classic flat bench press. Lower the bar to your chest and press it up to build chest, shoulders, and triceps.',
      instructions: <String>[
        'Lie flat on a bench with feet planted firmly on the floor.',
        'Grip the barbell slightly wider than shoulder-width.',
        'Lower the bar under control to mid-chest, keeping elbows tucked ~45°.',
        'Press back up to full lockout.',
      ],
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0043',
      name: 'Barbell Squat',
      bodyPart: 'upper legs',
      equipment: 'barbell',
      target: 'quads',
      secondaryMuscles: <String>['glutes', 'hamstrings', 'core'],
      category: 'strength',
      description:
          'Foundational lower-body compound lift targeting quads, glutes, and posterior chain.',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0032',
      name: 'Barbell Deadlift',
      bodyPart: 'back',
      equipment: 'barbell',
      target: 'hamstrings',
      secondaryMuscles: <String>['glutes', 'lower back', 'traps'],
      category: 'strength',
      description:
          'Full-body hip hinge lifting a loaded barbell from the floor to lockout.',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0091',
      name: 'Barbell Overhead Press',
      bodyPart: 'shoulders',
      equipment: 'barbell',
      target: 'delts',
      secondaryMuscles: <String>['triceps', 'upper chest', 'core'],
      category: 'strength',
      description:
          'Standing strict barbell press from shoulders to overhead lockout.',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0027',
      name: 'Barbell Bent-Over Row',
      bodyPart: 'back',
      equipment: 'barbell',
      target: 'upper back',
      secondaryMuscles: <String>['lats', 'biceps', 'rear delts'],
      category: 'strength',
      description:
          'Hinge at the hips with a flat back and pull the barbell to your lower ribcage.',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0289',
      name: 'Dumbbell Incline Press',
      bodyPart: 'chest',
      equipment: 'dumbbell',
      target: 'upper chest',
      secondaryMuscles: <String>['front delts', 'triceps'],
      category: 'strength',
      description:
          'Press dumbbells on a 30–45° incline bench to emphasize the clavicular chest.',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0308',
      name: 'Dumbbell Flyes',
      bodyPart: 'chest',
      equipment: 'dumbbell',
      target: 'pectorals',
      secondaryMuscles: <String>['front delts'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0651',
      name: 'Push-Up',
      bodyPart: 'chest',
      equipment: 'body weight',
      target: 'pectorals',
      secondaryMuscles: <String>['triceps', 'front delts', 'core'],
      category: 'calisthenics',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0652',
      name: 'Pull-Up',
      bodyPart: 'back',
      equipment: 'body weight',
      target: 'lats',
      secondaryMuscles: <String>['biceps', 'upper back'],
      category: 'calisthenics',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0150',
      name: 'Lat Pulldown',
      bodyPart: 'back',
      equipment: 'cable',
      target: 'lats',
      secondaryMuscles: <String>['biceps', 'rear delts'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0292',
      name: 'One-Arm Dumbbell Row',
      bodyPart: 'back',
      equipment: 'dumbbell',
      target: 'lats',
      secondaryMuscles: <String>['biceps', 'rhomboids'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0861',
      name: 'Seated Cable Row',
      bodyPart: 'back',
      equipment: 'cable',
      target: 'upper back',
      secondaryMuscles: <String>['lats', 'biceps'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0334',
      name: 'Dumbbell Lateral Raise',
      bodyPart: 'shoulders',
      equipment: 'dumbbell',
      target: 'lateral delts',
      secondaryMuscles: <String>['traps'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0405',
      name: 'Dumbbell Shoulder Press',
      bodyPart: 'shoulders',
      equipment: 'dumbbell',
      target: 'delts',
      secondaryMuscles: <String>['triceps'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0200',
      name: 'Cable Face Pull',
      bodyPart: 'shoulders',
      equipment: 'cable',
      target: 'rear delts',
      secondaryMuscles: <String>['upper back', 'rotator cuff'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0294',
      name: 'Dumbbell Bicep Curl',
      bodyPart: 'upper arms',
      equipment: 'dumbbell',
      target: 'biceps',
      secondaryMuscles: <String>['forearms'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0031',
      name: 'Barbell Curl',
      bodyPart: 'upper arms',
      equipment: 'barbell',
      target: 'biceps',
      secondaryMuscles: <String>['forearms'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0201',
      name: 'Cable Triceps Pushdown',
      bodyPart: 'upper arms',
      equipment: 'cable',
      target: 'triceps',
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0060',
      name: 'EZ-Bar Skullcrusher',
      bodyPart: 'upper arms',
      equipment: 'barbell',
      target: 'triceps',
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0251',
      name: 'Chest Dip',
      bodyPart: 'upper arms',
      equipment: 'body weight',
      target: 'triceps',
      secondaryMuscles: <String>['chest', 'front delts'],
      category: 'calisthenics',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0085',
      name: 'Romanian Deadlift',
      bodyPart: 'upper legs',
      equipment: 'barbell',
      target: 'hamstrings',
      secondaryMuscles: <String>['glutes', 'lower back'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0584',
      name: 'Leg Press',
      bodyPart: 'upper legs',
      equipment: 'machine',
      target: 'quads',
      secondaryMuscles: <String>['glutes'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0336',
      name: 'Dumbbell Walking Lunge',
      bodyPart: 'upper legs',
      equipment: 'dumbbell',
      target: 'quads',
      secondaryMuscles: <String>['glutes', 'hamstrings'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0586',
      name: 'Seated Leg Curl',
      bodyPart: 'upper legs',
      equipment: 'machine',
      target: 'hamstrings',
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0587',
      name: 'Leg Extension',
      bodyPart: 'upper legs',
      equipment: 'machine',
      target: 'quads',
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0417',
      name: 'Standing Calf Raise',
      bodyPart: 'lower legs',
      equipment: 'machine',
      target: 'calves',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0001',
      name: '3/4 Sit-Up',
      bodyPart: 'waist',
      equipment: 'body weight',
      target: 'abs',
      secondaryMuscles: <String>['hip flexors'],
      category: 'calisthenics',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0464',
      name: 'Forearm Plank',
      bodyPart: 'waist',
      equipment: 'body weight',
      target: 'abs',
      secondaryMuscles: <String>['core', 'shoulders'],
      category: 'calisthenics',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0472',
      name: 'Hanging Leg Raise',
      bodyPart: 'waist',
      equipment: 'body weight',
      target: 'abs',
      secondaryMuscles: <String>['hip flexors'],
      category: 'calisthenics',
      updatedAt: _seedTimestamp,
    ),
    const Exercise(
      id: '0530',
      name: 'Kettlebell Swing',
      bodyPart: 'full body',
      equipment: 'kettlebell',
      target: 'glutes',
      secondaryMuscles: <String>['hamstrings', 'core', 'shoulders'],
      category: 'strength',
      updatedAt: _seedTimestamp,
    ),
  ];

  static List<WorkoutTemplate> starterTemplates() {
    return <WorkoutTemplate>[
      WorkoutTemplate.create(
        id: 'starter-ppl-push',
        name: 'Push Day (PPL)',
        goal: 'hypertrophy',
        split: 'ppl',
        iconKey: 'barbell',
        sortOrder: 0,
        description: 'Chest, shoulders, and triceps compound & isolation work.',
        entries: const <WorkoutTemplateEntry>[
          WorkoutTemplateEntry(
            exerciseId: '0025',
            exerciseName: 'Barbell Bench Press',
            bodyPart: 'chest',
            equipment: 'barbell',
            targetSets: 4,
            targetReps: 8,
            restSeconds: 120,
          ),
          WorkoutTemplateEntry(
            exerciseId: '0289',
            exerciseName: 'Dumbbell Incline Press',
            bodyPart: 'chest',
            equipment: 'dumbbell',
            targetSets: 3,
            targetReps: 10,
            restSeconds: 90,
          ),
          WorkoutTemplateEntry(
            exerciseId: '0334',
            exerciseName: 'Dumbbell Lateral Raise',
            bodyPart: 'shoulders',
            equipment: 'dumbbell',
            targetSets: 3,
            targetReps: 15,
            restSeconds: 60,
          ),
          WorkoutTemplateEntry(
            exerciseId: '0201',
            exerciseName: 'Cable Triceps Pushdown',
            bodyPart: 'upper arms',
            equipment: 'cable',
            targetSets: 3,
            targetReps: 12,
            restSeconds: 60,
          ),
        ],
      ),
      WorkoutTemplate.create(
        id: 'starter-ppl-pull',
        name: 'Pull Day (PPL)',
        goal: 'hypertrophy',
        split: 'ppl',
        iconKey: 'pullup',
        sortOrder: 1,
        description: 'Back width, thickness, rear delts, and biceps.',
        entries: const <WorkoutTemplateEntry>[
          WorkoutTemplateEntry(
            exerciseId: '0027',
            exerciseName: 'Barbell Bent-Over Row',
            bodyPart: 'back',
            equipment: 'barbell',
            targetSets: 4,
            targetReps: 8,
            restSeconds: 120,
          ),
          WorkoutTemplateEntry(
            exerciseId: '0150',
            exerciseName: 'Lat Pulldown',
            bodyPart: 'back',
            equipment: 'cable',
            targetSets: 3,
            targetReps: 10,
            restSeconds: 90,
          ),
          WorkoutTemplateEntry(
            exerciseId: '0200',
            exerciseName: 'Cable Face Pull',
            bodyPart: 'shoulders',
            equipment: 'cable',
            targetSets: 3,
            targetReps: 15,
            restSeconds: 60,
          ),
          WorkoutTemplateEntry(
            exerciseId: '0294',
            exerciseName: 'Dumbbell Bicep Curl',
            bodyPart: 'upper arms',
            equipment: 'dumbbell',
            targetSets: 3,
            targetReps: 12,
            restSeconds: 60,
          ),
        ],
      ),
      WorkoutTemplate.create(
        id: 'starter-ppl-legs',
        name: 'Leg Day (PPL)',
        goal: 'strength',
        split: 'ppl',
        iconKey: 'legs',
        sortOrder: 2,
        description: 'Quads, hamstrings, glutes, and calves.',
        entries: const <WorkoutTemplateEntry>[
          WorkoutTemplateEntry(
            exerciseId: '0043',
            exerciseName: 'Barbell Squat',
            bodyPart: 'upper legs',
            equipment: 'barbell',
            targetSets: 4,
            targetReps: 6,
            restSeconds: 150,
          ),
          WorkoutTemplateEntry(
            exerciseId: '0085',
            exerciseName: 'Romanian Deadlift',
            bodyPart: 'upper legs',
            equipment: 'barbell',
            targetSets: 3,
            targetReps: 8,
            restSeconds: 120,
          ),
          WorkoutTemplateEntry(
            exerciseId: '0587',
            exerciseName: 'Leg Extension',
            bodyPart: 'upper legs',
            equipment: 'machine',
            targetSets: 3,
            targetReps: 12,
            restSeconds: 75,
          ),
          WorkoutTemplateEntry(
            exerciseId: '0417',
            exerciseName: 'Standing Calf Raise',
            bodyPart: 'lower legs',
            equipment: 'machine',
            targetSets: 4,
            targetReps: 15,
            restSeconds: 60,
          ),
        ],
      ),
      WorkoutTemplate.create(
        id: 'starter-5x5',
        name: '5×5 Strength',
        goal: 'strength',
        split: 'full-body',
        iconKey: 'overhead_press',
        sortOrder: 3,
        description:
            'Five sets of five on core barbell lifts with linear progression.',
        entries: const <WorkoutTemplateEntry>[
          WorkoutTemplateEntry(
            exerciseId: '0043',
            exerciseName: 'Barbell Squat',
            bodyPart: 'upper legs',
            equipment: 'barbell',
            targetSets: 5,
            targetReps: 5,
            restSeconds: 180,
          ),
          WorkoutTemplateEntry(
            exerciseId: '0025',
            exerciseName: 'Barbell Bench Press',
            bodyPart: 'chest',
            equipment: 'barbell',
            targetSets: 5,
            targetReps: 5,
            restSeconds: 150,
          ),
          WorkoutTemplateEntry(
            exerciseId: '0027',
            exerciseName: 'Barbell Bent-Over Row',
            bodyPart: 'back',
            equipment: 'barbell',
            targetSets: 5,
            targetReps: 5,
            restSeconds: 150,
          ),
        ],
      ),
    ];
  }

  /// Named starter plans for the "Load starter plan" sheet.
  static List<
      ({
        String id,
        String title,
        String subtitle,
        List<WorkoutTemplate> templates,
        Map<int, List<String>> weeklySchedule,
      })> starterPlans() {
    final all = starterTemplates();
    final push = all[0];
    final pull = all[1];
    final legs = all[2];
    final fiveByFive = all[3];

    final upper = WorkoutTemplate.create(
      name: 'Upper Body',
      goal: 'hypertrophy',
      split: 'upper-lower',
      iconKey: 'barbell',
      entries: <WorkoutTemplateEntry>[
        push.entries[0],
        pull.entries[0],
        push.entries[2],
        pull.entries[1],
      ],
    );
    final lower = WorkoutTemplate.create(
      name: 'Lower Body',
      goal: 'strength',
      split: 'upper-lower',
      iconKey: 'legs',
      entries: legs.entries,
    );
    final homeBw = WorkoutTemplate.create(
      name: 'Bodyweight Full Body',
      goal: 'endurance',
      split: 'home',
      iconKey: 'core_torso',
      entries: const <WorkoutTemplateEntry>[
        WorkoutTemplateEntry(
          exerciseId: '0662',
          exerciseName: 'Push-Up',
          bodyPart: 'chest',
          equipment: 'body weight',
          targetSets: 3,
          targetReps: 12,
          restSeconds: 60,
        ),
        WorkoutTemplateEntry(
          exerciseId: '0651',
          exerciseName: 'Pull-Up',
          bodyPart: 'back',
          equipment: 'body weight',
          targetSets: 3,
          targetReps: 8,
          restSeconds: 90,
        ),
        WorkoutTemplateEntry(
          exerciseId: '0620',
          exerciseName: 'Plank',
          bodyPart: 'waist',
          equipment: 'body weight',
          targetSets: 3,
          targetReps: 1,
          restSeconds: 45,
        ),
      ],
    );

    return <({
      String id,
      String title,
      String subtitle,
      List<WorkoutTemplate> templates,
      Map<int, List<String>> weeklySchedule,
    })>[
      (
        id: 'ppl',
        title: 'Push / Pull / Legs',
        subtitle: '3 days/week • Mon, Wed, Fri',
        templates: <WorkoutTemplate>[push, pull, legs],
        weeklySchedule: <int, List<String>>{
          1: <String>[push.id],
          3: <String>[pull.id],
          5: <String>[legs.id],
        },
      ),
      (
        id: 'ul',
        title: 'Upper / Lower',
        subtitle: '4 days/week • Mon, Tue, Thu, Fri',
        templates: <WorkoutTemplate>[upper, lower],
        weeklySchedule: <int, List<String>>{
          1: <String>[upper.id],
          2: <String>[lower.id],
          4: <String>[upper.id],
          5: <String>[lower.id],
        },
      ),
      (
        id: '5x5',
        title: '5×5 Strength',
        subtitle: '3 days/week • Mon, Wed, Fri',
        templates: <WorkoutTemplate>[fiveByFive],
        weeklySchedule: <int, List<String>>{
          1: <String>[fiveByFive.id],
          3: <String>[fiveByFive.id],
          5: <String>[fiveByFive.id],
        },
      ),
      (
        id: 'home_bw',
        title: 'Bodyweight at home',
        subtitle: '3 days/week • No equipment',
        templates: <WorkoutTemplate>[homeBw],
        weeklySchedule: <int, List<String>>{
          1: <String>[homeBw.id],
          3: <String>[homeBw.id],
          5: <String>[homeBw.id],
        },
      ),
    ];
  }
}
