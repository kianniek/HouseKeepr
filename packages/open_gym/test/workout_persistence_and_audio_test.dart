import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';
import 'package:open_gym/open_gym.dart';
import 'package:open_gym/src/ui/active_workout_screen.dart';

class _InMemoryHealthDataStore implements HealthDataStore {
  final Map<String, Map<String, Map<String, dynamic>>> _db =
      <String, Map<String, Map<String, dynamic>>>{};

  String _key(String moduleId, String collection) => '$moduleId::$collection';

  @override
  Future<void> clearModuleData(String moduleId) async {
    _db.removeWhere((k, _) => k.startsWith('$moduleId::'));
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    _db[_key(moduleId, collection)]?.remove(id);
  }

  @override
  Future<List<Map<String, dynamic>>> readCollection(
    String moduleId,
    String collection,
  ) async {
    final col = _db[_key(moduleId, collection)];
    if (col == null) return <Map<String, dynamic>>[];
    return col.values.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<Map<String, dynamic>?> readRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    final rec = _db[_key(moduleId, collection)]?[id];
    return rec == null ? null : Map<String, dynamic>.from(rec);
  }

  @override
  Future<void> upsertRecord(
    String moduleId,
    String collection,
    Map<String, dynamic> record,
  ) async {
    final col = _db.putIfAbsent(
      _key(moduleId, collection),
      () => <String, Map<String, dynamic>>{},
    );
    final copy = Map<String, dynamic>.from(record);
    copy['id'] ??= HealthRecordMetadata.generateId();
    copy['updatedAt'] ??= HealthRecordMetadata.nowUtcIso();
    copy['isSynced'] ??= false;
    col[copy['id'] as String] = copy;
  }
}

class _FakeWorkoutNotificationScheduler
    implements WorkoutNotificationScheduler {
  int scheduleCount = 0;
  int cancelCount = 0;
  DateTime? lastScheduledEndsAt;
  String? lastSoundProfileId;
  bool? lastSoundEnabled;

  @override
  Future<void> cancelRestEnd() async {
    cancelCount++;
  }

  @override
  Future<void> scheduleRestEnd({
    required DateTime endsAt,
    required String soundProfileId,
    required bool soundEnabled,
    required bool hapticsEnabled,
    required String workoutTitle,
  }) async {
    scheduleCount++;
    lastScheduledEndsAt = endsAt;
    lastSoundProfileId = soundProfileId;
    lastSoundEnabled = soundEnabled;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OpenGymSoundService audio focus', () {
    test('configures non-interrupting audio context on Android and iOS', () {
      final ctx = OpenGymSoundService.nonInterruptingAudioContext;
      expect(
        ctx.android.audioFocus,
        AndroidAudioFocus.gainTransientMayDuck,
      );
      expect(
        ctx.android.usageType,
        AndroidUsageType.assistanceSonification,
      );
      expect(ctx.iOS.category, AVAudioSessionCategory.ambient);
    });
  });

  group('Active workout persistence & rest notifications', () {
    test(
      'persists and restores active workout, selectedEntryIndex, view mode, and rest timer across re-init',
      () async {
        final store = _InMemoryHealthDataStore();
        final scheduler = _FakeWorkoutNotificationScheduler();

        final controller1 = OpenGymController(
          store: store,
          notificationScheduler: scheduler,
        );
        await controller1.initialize();

        for (final layout in <String>['cards', 'compact', 'focus', 'list']) {
          await controller1.savePreferences(
            controller1.preferences.copyWith(workoutLayout: layout),
          );
        }
        await controller1.savePreferences(
          controller1.preferences.copyWith(
            workoutLayout: 'focus',
            soundEnabled: false,
          ),
        );

        final template = controller1.templates.first;
        controller1.startFromTemplate(template);
        controller1.setSelectedEntryIndex(
          template.entries.length > 1 ? 1 : 0,
        );
        controller1.setInActiveWorkoutScreen(true);
        controller1.updateSet(0, 0, weight: 82.5, reps: 7);
        controller1.toggleSetCompleted(0, 0);
        controller1.startRest(90);

        // Allow unawaited saveActiveSession microtasks to flush.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(scheduler.scheduleCount, greaterThanOrEqualTo(1));
        expect(scheduler.lastSoundProfileId, controller1.preferences.restSound);

        final savedTitle = controller1.activeWorkout!.title;
        final savedEntryIndex = controller1.selectedEntryIndex;
        controller1.dispose();

        // Re-create controller from the same store (simulating cold restart).
        final controller2 = OpenGymController(
          store: store,
          notificationScheduler: scheduler,
        );
        await controller2.initialize();

        expect(controller2.hasActiveWorkout, isTrue);
        expect(controller2.activeWorkout!.title, savedTitle);
        expect(controller2.selectedEntryIndex, savedEntryIndex);
        expect(controller2.isInActiveWorkoutScreen, isTrue);
        expect(controller2.preferences.workoutLayout, 'focus');
        expect(controller2.activeWorkout!.entries[0].sets[0].weight, 82.5);
        expect(controller2.activeWorkout!.entries[0].sets[0].reps, 7);
        expect(controller2.activeWorkout!.entries[0].sets[0].isCompleted, isTrue);
        expect(controller2.isResting, isTrue);
        expect(controller2.restRemainingSeconds, inInclusiveRange(1, 90));

        // Pause cancels rest notification; resume reschedules it.
        final cancelsBeforePause = scheduler.cancelCount;
        controller2.togglePause();
        expect(controller2.isPaused, isTrue);
        expect(scheduler.cancelCount, cancelsBeforePause + 1);

        final schedulesBeforeResume = scheduler.scheduleCount;
        controller2.togglePause();
        expect(controller2.isPaused, isFalse);
        expect(scheduler.scheduleCount, schedulesBeforeResume + 1);

        // Finish clears active session and cancels rest notification.
        await controller2.finishWorkout();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(controller2.hasActiveWorkout, isFalse);

        final controller3 = OpenGymController(store: store);
        await controller3.initialize();
        expect(controller3.hasActiveWorkout, isFalse);

        controller2.dispose();
        controller3.dispose();
      },
    );

    test('discardWorkout clears persisted active session and cancels rest', () async {
      final store = _InMemoryHealthDataStore();
      final scheduler = _FakeWorkoutNotificationScheduler();
      final controller = OpenGymController(
        store: store,
        notificationScheduler: scheduler,
      );
      await controller.initialize();

      controller.startEmptyWorkout();
      controller.startRest(60);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final cancelsBeforeDiscard = scheduler.cancelCount;
      controller.discardWorkout();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(scheduler.cancelCount, cancelsBeforeDiscard + 1);
      expect(controller.hasActiveWorkout, isFalse);

      final controller2 = OpenGymController(store: store);
      await controller2.initialize();
      expect(controller2.hasActiveWorkout, isFalse);

      controller.dispose();
      controller2.dispose();
    });
  });

  group('Widget restoration & deep-link routing', () {
    for (final layout in <String>['cards', 'compact', 'focus', 'list']) {
      testWidgets(
        'OpenGymRoot restores ActiveWorkoutScreen in $layout layout at saved exercise',
        (tester) async {
          final store = _InMemoryHealthDataStore();
          await tester.runAsync(() async {
            final setup = OpenGymController(store: store);
            await setup.initialize();
            await setup.savePreferences(
              setup.preferences.copyWith(
                workoutLayout: layout,
                soundEnabled: false,
              ),
            );
            final template = setup.templates.first;
            setup.startFromTemplate(template);
            setup.setSelectedEntryIndex(template.entries.length > 1 ? 1 : 0);
            setup.setInActiveWorkoutScreen(true);
            await Future<void>.delayed(const Duration(milliseconds: 20));
            setup.dispose();
          });

          await tester.pumpWidget(
            MaterialApp(
              home: OpenGymRoot(store: store),
            ),
          );
          for (var i = 0;
              i < 60 && find.byType(ActiveWorkoutScreen).evaluate().isEmpty;
              i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
          }
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(ActiveWorkoutScreen), findsOneWidget);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }

    testWidgets(
      'OpenGymLauncher routes warm deep link to existing OpenGymRoot without duplicating',
      (tester) async {
        final store = _InMemoryHealthDataStore();
        await tester.runAsync(() async {
          final setup = OpenGymController(store: store);
          await setup.initialize();
          await setup.savePreferences(
            setup.preferences.copyWith(soundEnabled: false),
          );
          setup.startEmptyWorkout();
          setup.setInActiveWorkoutScreen(false);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          setup.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => OpenGymLauncher.launch(
                      context,
                      store,
                      autoStartNextWorkout: true,
                    ),
                    child: const Text('DeepLink'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Push OpenGymRoot directly (as if already open on dashboard).
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => OpenGymRoot(store: store),
          ),
        );
        for (var i = 0;
            i < 60 && find.byType(OpenGymRoot).evaluate().isEmpty;
            i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(OpenGymRoot), findsOneWidget);
        expect(OpenGymLauncher.isOpen, isTrue);

        // Trigger warm deep link via OpenGymLauncher.launch while OpenGymRoot is open.
        final ctx = tester.element(find.byType(OpenGymRoot));
        await OpenGymLauncher.launch(
          ctx,
          store,
          autoStartNextWorkout: true,
          libraryLoader: () async {},
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(OpenGymRoot), findsOneWidget);
        expect(find.byType(ActiveWorkoutScreen), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}
