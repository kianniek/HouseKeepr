import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';
import 'package:open_gym/open_gym.dart';

void main() {
  late Directory tempDir;
  late LocalHealthDataStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('open_gym_test_');
    store = LocalHealthDataStore(directoryProvider: () async => tempDir);
  });

  tearDown(() async {
    await store.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Models JSON serialization & metadata', () {
    test('Exercise round-trips with HealthRecordMetadata', () {
      final ex = Exercise.create(
        name: 'Incline Bench',
        bodyPart: 'chest',
        equipment: 'barbell',
        target: 'upper pectorals',
      );
      final decoded = Exercise.fromJson(ex.toJson());
      expect(decoded.id, ex.id);
      expect(decoded.name, 'Incline Bench');
      expect(decoded.updatedAt, ex.updatedAt);
      expect(decoded.isSynced, isFalse);
    });

    test('WorkoutLog and ExerciseSet compute volume and 1RM', () {
      final set1 = ExerciseSet.create(
        weight: 100,
        reps: 5,
        isCompleted: true,
      );
      final warmup = ExerciseSet.create(
        weight: 60,
        reps: 10,
        isWarmup: true,
        isCompleted: true,
      );
      final log = WorkoutLog.create(
        title: 'Push Day',
        entries: <WorkoutEntry>[
          WorkoutEntry(
            exerciseId: '0025',
            exerciseName: 'Barbell Bench Press',
            bodyPart: 'chest',
            equipment: 'barbell',
            sets: <ExerciseSet>[warmup, set1],
          ),
        ],
      );

      final roundTrip = WorkoutLog.fromJson(log.toJson());
      expect(roundTrip.totalVolume, 500);
      expect(roundTrip.completedSetsCount, 2);
      expect(set1.estimated1RM(), closeTo(116.67, 0.1));
      expect(warmup.estimated1RM(), isNull);
    });
  });

  group('OpenGymController & Timers & PRs', () {
    test('logs sets, triggers rest timer, detects PR, and persists workout',
        () async {
      final controller = OpenGymController(store: store);
      await controller.initialize();

      expect(controller.templates, isNotEmpty);
      expect(controller.exercises, isNotEmpty);

      // Seed a baseline workout in history
      controller.startEmptyWorkout(title: 'Day 1');
      final bench =
          controller.exercises.firstWhere((e) => e.id == '0025');
      controller.addExerciseToActiveWorkout(bench);
      controller.updateSet(0, 0, weight: 80, reps: 5);
      final firstPrs = controller.toggleSetCompleted(0, 0);
      expect(firstPrs, isEmpty); // No prior history -> no PRs
      expect(controller.isResting, isTrue);
      expect(controller.restRemainingSeconds, 90);

      controller.addRest(15);
      expect(controller.restRemainingSeconds, 105);
      controller.skipRest();
      expect(controller.isResting, isFalse);

      await controller.finishWorkout();
      expect(controller.hasActiveWorkout, isFalse);
      expect(controller.history, hasLength(1));

      // Second workout beats baseline weight (100 > 80) -> earns PRs
      controller.startEmptyWorkout(title: 'Day 2');
      controller.addExerciseToActiveWorkout(bench);
      controller.updateSet(0, 0, weight: 100, reps: 5);
      final secondPrs = controller.toggleSetCompleted(0, 0);
      expect(secondPrs, containsAll(<RecordKind>[RecordKind.weight, RecordKind.e1rm, RecordKind.volume]));

      await controller.finishWorkout();
      expect(controller.history, hasLength(2));
      controller.dispose();
    });
  });

  group('OpenGymRoot Widget', () {
    testWidgets('renders dashboard tabs and starts an empty workout',
        (tester) async {
      final memoryStore = _MemoryHealthDataStore();
      await tester.pumpWidget(
        MaterialApp(
          home: OpenGymRoot(store: memoryStore),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('OpenGym'), findsOneWidget);
      expect(find.text('Start Empty Workout'), findsOneWidget);
      expect(find.text('Quick Start Routines'), findsOneWidget);

      await tester.tap(find.text('Start Empty Workout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Quick Workout'), findsOneWidget);
      expect(find.text('Add Exercise'), findsOneWidget);
    });
  });
}

class _MemoryHealthDataStore implements HealthDataStore {
  final Map<String, Map<String, Map<String, dynamic>>> _data =
      <String, Map<String, Map<String, dynamic>>>{};

  @override
  Future<void> clearModuleData(String moduleId) async {
    _data.removeWhere((key, _) => key.startsWith('$moduleId:'));
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    _data['$moduleId:$collection']?.remove(id);
  }

  @override
  Future<List<Map<String, dynamic>>> readCollection(
    String moduleId,
    String collection,
  ) async {
    return (_data['$moduleId:$collection']?.values ?? const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> readRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    final found = _data['$moduleId:$collection']?[id];
    return found == null ? null : Map<String, dynamic>.from(found);
  }

  @override
  Future<void> upsertRecord(
    String moduleId,
    String collection,
    Map<String, dynamic> record,
  ) async {
    final key = '$moduleId:$collection';
    final map = _data.putIfAbsent(key, () => <String, Map<String, dynamic>>{});
    final copy = Map<String, dynamic>.from(record);
    final id = (copy['id'] as String?) ?? HealthRecordMetadata.generateId();
    copy['id'] = id;
    copy['updatedAt'] ??= HealthRecordMetadata.nowUtcIso();
    copy['isSynced'] ??= false;
    map[id] = copy;
  }
}
