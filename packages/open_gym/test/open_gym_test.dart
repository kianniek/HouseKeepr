import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_gym/open_gym.dart';

void main() {
  late Directory tempDir;
  late LocalHealthDataStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('open_gym_test_');
    store = LocalHealthDataStore(storagePathProvider: () async => tempDir.path);
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

  group('Analytics, 1RM Formulas & Server Sync', () {
    test('OneRmEstimator and OpenGymAnalyticsService compute plates & streaks',
        () {
      expect(
        OneRmEstimator.estimate(100, 5, formula: 'brzycki'),
        closeTo(112.5, 0.1),
      );
      expect(
        OneRmEstimator.estimate(100, 5, formula: 'weighted'),
        greaterThan(110),
      );

      const analytics = OpenGymAnalyticsService();
      final plates = analytics.calculatePlatesPerSide(targetWeight: 100);
      expect(plates[25], 1);
      expect(plates[15], 1);

      final ramp = analytics.generateWarmupRamp(workingWeight: 100);
      expect(ramp, hasLength(3));
    });

    test('OpenGymServerClient & SyncService pair and sync with MockClient',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/pair/redeem') {
          expect(request.headers['CF-Access-Client-Id'], 'cf-id');
          return http.Response(jsonEncode({'token': 'tok-123'}), 200);
        }
        if (request.url.path == '/api/sync' && request.method == 'PUT') {
          expect(request.headers['Authorization'], 'Bearer tok-123');
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        if (request.url.path == '/api/sync' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'collections': {
                'weigh_ins': [
                  {
                    'id': 'w-remote-1',
                    'date': '2026-11-16',
                    'weightKg': 79.5,
                    'updatedAt': '2026-11-16T12:00:00.000Z',
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final controller = OpenGymController(
        store: store,
        serverClient: OpenGymServerClient(httpClient: mockClient),
      );
      await controller.initialize();
      await controller.saveWeighIn(
        WeighIn.create(date: '2026-11-15', weightKg: 80.0),
      );

      await controller.connectServerWithCode(
        serverUrl: 'https://gym.example.com',
        code: '123456',
        cfAccessClientId: 'cf-id',
        cfAccessClientSecret: 'cf-secret',
      );
      expect(controller.serverConnection?.isConnected, isTrue);

      final result = await controller.syncNow();
      expect(result.pushedCount, greaterThanOrEqualTo(1));
      expect(result.pulledCount, 1);
      expect(controller.weighIns.any((w) => w.id == 'w-remote-1'), isTrue);
      controller.dispose();
    });

    test('Programme scheduling, drop-sets, ProgressPhoto & WebDAV work',
        () async {
      final dropSet = ExerciseSet.create(
        weight: 100,
        reps: 5,
        setType: SetType.dropset,
        drops: const <SetDrop>[SetDrop(weight: 80, reps: 6)],
        isCompleted: true,
      );
      expect(dropSet.volume, 980); // 500 + 480

      final controller = OpenGymController(store: store);
      await controller.initialize();
      final today = DateTime(2026, 11, 16); // Monday (1)
      final firstTemplate = controller.templates.first;
      await controller.saveProgramme(
        Programme.create(
          name: 'Test Split',
          weekdayToTemplateId: <int, String>{today.weekday: firstTemplate.id},
          isActive: true,
        ),
      );
      expect(controller.todaysScheduledTemplate(today)?.id, firstTemplate.id);

      final photo = ProgressPhoto.create(
        date: '2026-11-16',
        pose: 'front',
        base64Image: 'AAAA',
      );
      await controller.saveProgressPhoto(photo);
      expect(controller.progressPhotos, hasLength(1));

      String? uploadedBody;
      final webdavMock = MockClient((req) async {
        if (req.method == 'PUT') {
          uploadedBody = req.body;
          return http.Response('', 201);
        }
        if (req.method == 'GET') {
          return http.Response(uploadedBody ?? '{}', 200);
        }
        return http.Response('', 404);
      });
      final webdavClient = WebDavClient(httpClient: webdavMock);
      await controller.backupToWebDav(
        fileUrl: 'https://dav.example.com/opengym.json',
        username: 'u',
        password: 'p',
        client: webdavClient,
      );
      expect(uploadedBody, contains('open_gym_flutter_backup_v1'));
      final restored = await controller.restoreFromWebDav(
        fileUrl: 'https://dav.example.com/opengym.json',
        username: 'u',
        password: 'p',
        client: webdavClient,
      );
      expect(restored, greaterThanOrEqualTo(1));
      controller.dispose();
    });

    test('ExerciseMediaService resolves URLs and caches still bytes locally',
        () async {
      expect(
        ExerciseMediaService.stillUrlFor('0025'),
        contains('/still/0025.webp'),
      );
      expect(
        ExerciseMediaService.clipUrlFor(
          '0025',
          serverUrl: 'https://gym.example.com/',
        ),
        'https://gym.example.com/exercise-media/clip/0025.mp4',
      );

      var fetchCount = 0;
      final mediaClient = MockClient((req) async {
        fetchCount++;
        return http.Response.bytes(<int>[1, 2, 3, 4], 200);
      });

      final mediaService = ExerciseMediaService(
        store: store,
        httpClient: mediaClient,
      );

      final first = await mediaService.loadStillBytes('0025');
      expect(first, equals(<int>[1, 2, 3, 4]));
      expect(fetchCount, 1);

      // New service instance reading from persisted HealthDataStore cache
      final mediaService2 = ExerciseMediaService(
        store: store,
        httpClient: mediaClient,
      );
      final cached = await mediaService2.loadStillBytes('0025');
      expect(cached, equals(<int>[1, 2, 3, 4]));
      expect(fetchCount, 1);
    });

    test('WavSynthesizer produces valid WAV buffers for all rest sound profiles',
        () {
      for (final profile in OpenGymSoundService.restSounds) {
        final bytes = WavSynthesizer.synthesize(
          profile.notes,
          peak: profile.peak,
          holdFraction: profile.holdFraction,
          timbre: profile.timbre,
        );
        expect(bytes.length, greaterThan(44));
        // RIFF / WAVE header
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      }

      final prefs = OpenGymPreferences(
        updatedAt: HealthRecordMetadata.nowUtcIso(),
        soundEnabled: false,
        hapticsEnabled: false,
        prSoundEnabled: false,
        restSound: 'whistle',
      );
      final roundTrip = OpenGymPreferences.fromJson(prefs.toJson());
      expect(roundTrip.soundEnabled, isFalse);
      expect(roundTrip.hapticsEnabled, isFalse);
      expect(roundTrip.prSoundEnabled, isFalse);
      expect(roundTrip.restSound, 'whistle');
    });
  });

  group('OpenGymRoot Widget', () {
    testWidgets('renders [Home, Plan, Start, Stats, Exercises] navbar and starts workout',
        (tester) async {
      final memoryStore = _MemoryHealthDataStore();
      await tester.pumpWidget(
        MaterialApp(
          home: OpenGymRoot(store: memoryStore),
        ),
      );
      for (var i = 0;
          i < 60 && find.text('OpenGym').evaluate().isEmpty;
          i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(find.text('OpenGym'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);

      // Verify left-to-right order of navbar labels
      final homeX = tester.getCenter(find.text('Home')).dx;
      final planX = tester.getCenter(find.text('Plan')).dx;
      final startX = tester.getCenter(find.text('Start')).dx;
      final statsX = tester.getCenter(find.text('Stats')).dx;
      final exercisesX = tester.getCenter(find.text('Exercises')).dx;
      expect(homeX < planX, isTrue);
      expect(planX < startX, isTrue);
      expect(startX < statsX, isTrue);
      expect(statsX < exercisesX, isTrue);

      // Tap Plan tab
      await tester.tap(find.text('Plan'));
      await tester.pump();
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Routines'), findsOneWidget);

      // Tap Stats tab
      await tester.tap(find.text('Stats'));
      await tester.pump();
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Lifts'), findsOneWidget);
      expect(find.text('Effort'), findsOneWidget);

      // Tap Start center button -> opens ActiveWorkoutScreen
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Finish'), findsOneWidget);

      // 3-dots menu opens WorkoutMenuSheet (and NOT Discard workout)
      await tester.tap(find.byTooltip('Workout menu'));
      await tester.pumpAndSettle();
      expect(find.text('Workout settings'), findsOneWidget);
      expect(find.text('Pause workout'), findsOneWidget);
      expect(find.text('Layout'), findsOneWidget);
      expect(find.text('Discard workout'), findsNothing);

      // Expand More in WorkoutMenuSheet
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Add routine'), findsOneWidget);
      expect(find.text('Rename workout'), findsOneWidget);
      expect(find.text('Don\'t count for progression'), findsOneWidget);

      // Close sheet via back/tap outside
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Finish button opens FinishWorkoutSheet with Finish and save & Discard workout
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing logged yet'), findsOneWidget);
      expect(find.text('Finish and save'), findsOneWidget);
      expect(find.text('Discard workout'), findsOneWidget);

      // Tapping Discard workout opens Discard workout? dialog
      await tester.tap(find.text('Discard workout'));
      await tester.pumpAndSettle();
      expect(find.text('Discard workout?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);
    });

    test('Workout preferences, progression flag, notes & duplicateSet work',
        () async {
      final controller = OpenGymController(store: store);
      await controller.initialize();

      final updatedPrefs = controller.preferences.copyWith(
        flashScreen: true,
        keepScreenAwake: false,
        workoutLayout: 'compact',
        effortMode: 'rir',
        swipeActionsEnabled: false,
        exerciseAnimationSize: 'full',
      );
      await controller.savePreferences(updatedPrefs);
      final roundTrip =
          OpenGymPreferences.fromJson(controller.preferences.toJson());
      expect(roundTrip.flashScreen, isTrue);
      expect(roundTrip.keepScreenAwake, isFalse);
      expect(roundTrip.workoutLayout, 'compact');
      expect(roundTrip.effortMode, 'rir');
      expect(roundTrip.swipeActionsEnabled, isFalse);
      expect(roundTrip.exerciseAnimationSize, 'full');

      controller.startFromTemplate(controller.templates.first);
      controller.setSessionNote('Felt strong today');
      expect(controller.activeWorkout?.notes, 'Felt strong today');

      controller.setCountForProgression(false);
      expect(controller.activeWorkout?.countForProgression, isFalse);

      final initialSets = controller.activeWorkout!.entries.first.sets.length;
      controller.duplicateSet(0, 0);
      expect(
        controller.activeWorkout!.entries.first.sets.length,
        initialSets + 1,
      );

      controller.updateSet(0, 0, rir: 2);
      expect(controller.activeWorkout!.entries.first.sets.first.rir, 2);

      if (controller.templates.length > 1) {
        final beforeEntries = controller.activeWorkout!.entries.length;
        controller.addRoutineToActiveWorkout(controller.templates[1]);
        expect(
          controller.activeWorkout!.entries.length,
          greaterThanOrEqualTo(beforeEntries),
        );
      }

      // Per-exercise menu actions
      controller.setEntryNote(0, 'Brace core');
      expect(controller.activeWorkout!.entries[0].notes, 'Brace core');

      final initialEntrySets = controller.activeWorkout!.entries[0].sets.length;
      controller.addWarmupSet(0);
      expect(
        controller.activeWorkout!.entries[0].sets.length,
        initialEntrySets + 1,
      );
      expect(controller.activeWorkout!.entries[0].sets.first.isWarmup, isTrue);

      controller.setEntryRestSeconds(0, 120);
      expect(controller.activeWorkout!.entries[0].restSeconds, 120);

      controller.setEntryProgressionMode(0, 'double');
      expect(controller.activeWorkout!.entries[0].progressionMode, 'double');

      controller.setEntryCountForProgression(0, false);
      expect(controller.activeWorkout!.entries[0].countForProgression, isFalse);

      if (controller.activeWorkout!.entries.length >= 2) {
        controller.toggleSupersetWithNext(0);
        expect(controller.activeWorkout!.entries[0].supersetId, isNotNull);
        expect(
          controller.activeWorkout!.entries[0].supersetId,
          controller.activeWorkout!.entries[1].supersetId,
        );
        final firstId = controller.activeWorkout!.entries[0].exerciseId;
        controller.moveEntryDown(0);
        expect(controller.activeWorkout!.entries[1].exerciseId, firstId);
        controller.moveEntryUp(1);
        expect(controller.activeWorkout!.entries[0].exerciseId, firstId);
      }

      final roundTripEntry = WorkoutEntry.fromJson(
        controller.activeWorkout!.entries[0].toJson(),
      );
      expect(roundTripEntry.countForProgression, isFalse);
      expect(roundTripEntry.progressionMode, 'double');

      controller.dispose();
    });

    testWidgets(
        'Inline exercise animation expands/minimizes/pauses and exercise menu opens',
        (tester) async {
      final memoryStore = _MemoryHealthDataStore();
      await tester.pumpWidget(
        MaterialApp(
          home: OpenGymRoot(store: memoryStore),
        ),
      );
      for (var i = 0;
          i < 60 && find.text('OpenGym').evaluate().isEmpty;
          i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Tap thumbnail to expand inline animation
      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pump();
      expect(find.text('Minimize'), findsOneWidget);
      expect(find.text('Tap to pause'), findsOneWidget);

      // Toggle pause -> Tap to play
      await tester.ensureVisible(find.text('Tap to pause'));
      await tester.pump();
      await tester.tap(find.text('Tap to pause'));
      await tester.pump();
      expect(find.text('Tap to play'), findsOneWidget);

      // Minimize back to thumbnail
      await tester.ensureVisible(find.text('Minimize'));
      await tester.pump();
      await tester.tap(find.text('Minimize'));
      await tester.pump();
      expect(find.text('Minimize'), findsNothing);
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);

      // Open per-exercise 3-dots menu
      await tester.ensureVisible(find.byTooltip('Exercise options'));
      await tester.pump();
      await tester.tap(find.byTooltip('Exercise options'));
      await tester.pumpAndSettle();
      expect(find.text('Add note'), findsOneWidget);
      expect(find.text('Swap exercise'), findsOneWidget);
      expect(find.text('Add warm-up set'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Remove exercise'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Remove exercise'), findsOneWidget);

      // Expand More section
      await tester.ensureVisible(find.text('More'));
      await tester.pump();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Exercise settings'), findsOneWidget);
      expect(find.text('Plate loading'), findsOneWidget);
      expect(find.text('How to do it'), findsOneWidget);
      expect(find.text('Watch on YouTube'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Make superset with next'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Make superset with next'), findsOneWidget);
    });

    test(
        'ProgressionService prescribes linear (step-up + 3-stall deload), greyskull, double, density, and undulating',
        () {
      const service = ProgressionService();

      WorkoutLog makeLog(
        String id,
        List<int> repsPerSet, {
        double weight = 100,
        int restSeconds = 90,
      }) {
        return WorkoutLog.create(
          title: 'Session $id',
          entries: <WorkoutEntry>[
            WorkoutEntry(
              exerciseId: 'barbell_bench_press',
              exerciseName: 'Barbell Bench Press',
              bodyPart: 'chest',
              equipment: 'barbell',
              restSeconds: restSeconds,
              sets: repsPerSet
                  .map(
                    (r) => ExerciseSet.create(
                      weight: weight,
                      reps: r,
                      isCompleted: true,
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      }

      const linearEntry = WorkoutTemplateEntry(
        exerciseId: 'barbell_bench_press',
        exerciseName: 'Barbell Bench Press',
        bodyPart: 'chest',
        equipment: 'barbell',
        targetSets: 3,
        targetReps: 5,
        defaultWeight: 100,
        restSeconds: 90,
        progressionPolicy: 'linear',
      );

      // Clean hit adds +2.5 kg.
      final linearUp = service.prescribe(
        entry: linearEntry,
        history: <WorkoutLog>[
          makeLog('1', <int>[5, 5, 5], weight: 100),
        ],
      );
      expect(linearUp.weight, 102.5);
      expect(linearUp.reps, 5);

      // 3 consecutive stalls triggers a -10% deload (100 * 0.9 = 90.0).
      final linearDeload = service.prescribe(
        entry: linearEntry,
        history: <WorkoutLog>[
          makeLog('3', <int>[5, 4, 3], weight: 100),
          makeLog('2', <int>[5, 4, 4], weight: 100),
          makeLog('1', <int>[5, 5, 4], weight: 100),
        ],
      );
      expect(linearDeload.weight, 90.0);
      expect(linearDeload.insightReason, contains('3 times in a row'));

      // Greyskull LP: doubled final AMRAP set earns 2x increment (+5.0 kg).
      const greyskullEntry = WorkoutTemplateEntry(
        exerciseId: 'barbell_bench_press',
        exerciseName: 'Barbell Bench Press',
        bodyPart: 'chest',
        equipment: 'barbell',
        targetSets: 3,
        targetReps: 5,
        defaultWeight: 100,
        progressionPolicy: 'greyskull',
      );
      final gslpDoubled = service.prescribe(
        entry: greyskullEntry,
        history: <WorkoutLog>[
          makeLog('1', <int>[5, 5, 10], weight: 100),
        ],
      );
      expect(gslpDoubled.weight, 105.0);

      final gslpReset = service.prescribe(
        entry: greyskullEntry,
        history: <WorkoutLog>[
          makeLog('1', <int>[5, 5, 3], weight: 100),
        ],
      );
      expect(gslpReset.weight, 90.0);

      // Double progression climbs reps then bumps weight and resets to minReps.
      const doubleEntry = WorkoutTemplateEntry(
        exerciseId: 'barbell_bench_press',
        exerciseName: 'Barbell Bench Press',
        bodyPart: 'chest',
        equipment: 'barbell',
        targetSets: 3,
        targetReps: 10,
        targetRepsMin: 6,
        defaultWeight: 60,
        progressionPolicy: 'double',
      );
      final doubleClimb = service.prescribe(
        entry: doubleEntry,
        history: <WorkoutLog>[
          makeLog('1', <int>[8, 8, 7], weight: 60),
        ],
      );
      expect(doubleClimb.weight, 60.0);
      expect(doubleClimb.reps, 8);

      final doubleTopOut = service.prescribe(
        entry: doubleEntry,
        history: <WorkoutLog>[
          makeLog('1', <int>[10, 10, 10], weight: 60),
        ],
      );
      expect(doubleTopOut.weight, 62.5);
      expect(doubleTopOut.reps, 6);

      // Density trims rest by 15s until floor (45s), then increments weight & resets rest.
      const densityEntry = WorkoutTemplateEntry(
        exerciseId: 'barbell_bench_press',
        exerciseName: 'Barbell Bench Press',
        bodyPart: 'chest',
        equipment: 'barbell',
        targetSets: 3,
        targetReps: 8,
        defaultWeight: 60,
        restSeconds: 90,
        progressionPolicy: 'density',
      );
      final densityTrim = service.prescribe(
        entry: densityEntry,
        history: <WorkoutLog>[
          makeLog('1', <int>[8, 8, 8], weight: 60, restSeconds: 90),
        ],
      );
      expect(densityTrim.weight, 60.0);
      expect(densityTrim.restSeconds, 75);

      final densityStepUp = service.prescribe(
        entry: densityEntry,
        history: <WorkoutLog>[
          makeLog('1', <int>[8, 8, 8], weight: 60, restSeconds: 45),
        ],
      );
      expect(densityStepUp.weight, 62.5);
      expect(densityStepUp.restSeconds, 90);

      // Undulating cycles Heavy (sessions % 3 == 1), Light (== 2), Medium (== 0).
      const undulatingEntry = WorkoutTemplateEntry(
        exerciseId: 'barbell_bench_press',
        exerciseName: 'Barbell Bench Press',
        bodyPart: 'chest',
        equipment: 'barbell',
        targetSets: 3,
        targetReps: 10,
        defaultWeight: 80,
        progressionPolicy: 'undulating',
      );
      final heavyDay = service.prescribe(
        entry: undulatingEntry,
        history: <WorkoutLog>[makeLog('1', <int>[10, 10, 10], weight: 80)],
      );
      expect(heavyDay.insightReason, startsWith('Heavy day:'));
      final lightDay = service.prescribe(
        entry: undulatingEntry,
        history: <WorkoutLog>[
          makeLog('2', <int>[6, 6, 6], weight: 90),
          makeLog('1', <int>[10, 10, 10], weight: 80),
        ],
      );
      expect(lightDay.insightReason, startsWith('Light day:'));
    });

    test(
        'OpenGymController manages rotation loop stops, duplicate stops, undo snapshots, duplicate & delete templates',
        () async {
      final memoryStore = _MemoryHealthDataStore();
      final controller = OpenGymController(store: memoryStore);
      await controller.initialize();

      expect(controller.templates, isNotEmpty);
      final t0 = controller.templates.first;
      final initialCount = controller.templates.length;
      final initialSeqLen = controller.rotationSequence.length;
      final initialRoutinesInLoop = controller.totalRoutinesInLoop;

      // Loop allows duplicate stops and Rest day stops.
      await controller.addStopToRotation(t0.id);
      await controller.addStopToRotation(OpenGymController.restStopId);
      await controller.addStopToRotation(t0.id);
      expect(controller.rotationSequence.length, initialSeqLen + 3);
      expect(controller.totalRoutinesInLoop, initialRoutinesInLoop + 2);
      expect(controller.nextRotationStopIndex, 0);

      final removeIdx = initialSeqLen + 1;
      final snap = await controller.removeStopFromRotation(removeIdx);
      expect(controller.rotationSequence.length, initialSeqLen + 2);
      expect(
        controller.rotationSequence.contains(OpenGymController.restStopId),
        isFalse,
      );

      await controller.restoreRotationSnapshot(snap);
      expect(controller.rotationSequence.length, initialSeqLen + 3);
      expect(
        controller.rotationSequence[removeIdx],
        OpenGymController.restStopId,
      );

      // Duplicate places copy directly below original; delete+undo restores cleanly.
      final copy = await controller.duplicateTemplate(t0.id);
      expect(controller.templates.length, initialCount + 1);
      expect(controller.templates[1].id, copy.id);
      expect(copy.name, '${t0.name} (Copy)');

      final delSnap = await controller.deleteTemplateWithSnapshot(copy.id);
      expect(delSnap, isNotNull);
      expect(controller.templates.length, initialCount);

      await controller.restoreTemplateSnapshot(delSnap!);
      expect(controller.templates.length, initialCount + 1);
      expect(controller.templates[1].id, copy.id);

      controller.dispose();
    });

    testWidgets(
        'Plan tab rotation loop, Plan options sheet, New routine editor, and 7 skill ladders',
        (tester) async {
      final memoryStore = _MemoryHealthDataStore();
      await tester.pumpWidget(
        MaterialApp(
          home: OpenGymRoot(store: memoryStore),
        ),
      );
      for (var i = 0;
          i < 60 && find.text('OpenGym').evaluate().isEmpty;
          i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      // Open Plan tab and switch to Rotation mode.
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rotation'));
      await tester.pumpAndSettle();
      expect(find.text('The loop'), findsOneWidget);

      // Add a routine stop into the loop, then toggle Edit mode.
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Add to the rotation'), findsOneWidget);
      final sheetItem = find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.textContaining('exercises'),
          )
          .first;
      await tester.ensureVisible(sheetItem);
      await tester.pumpAndSettle();
      await tester.tap(sheetItem);
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Open top-right Plan options share sheet and close it.
      await tester.tap(find.byTooltip('Plan options'));
      await tester.pumpAndSettle();
      expect(find.text('Export plan file'), findsOneWidget);
      expect(find.text('Print / Save as PDF'), findsOneWidget);
      Navigator.of(tester.element(find.text('Export plan file'))).pop();
      await tester.pumpAndSettle();

      // Switch to Routines -> New routine and verify auto-saving settings card.
      await tester.tap(find.text('Routines'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New routine'));
      await tester.pumpAndSettle();
      expect(find.text('Progression'), findsOneWidget);
      expect(find.text('Folder'), findsOneWidget);
      expect(find.text('Routine type'), findsOneWidget);
      expect(find.text('Deload routine'), findsOneWidget);

      await tester.tap(find.byTooltip('Back to Plan'));
      await tester.pumpAndSettle();

      // Navigate to Exercises -> Ladders and check all 7 built-in ladders.
      await tester.tap(find.text('Exercises'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ladders'));
      await tester.pumpAndSettle();
      expect(find.text('Skill ladders'), findsOneWidget);
      expect(find.text('Push-up ladder'), findsOneWidget);
      expect(find.text('Pull-up ladder'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Handstand ladder'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Handstand ladder'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Make your own ladder'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Make your own ladder'), findsOneWidget);
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
