import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';
import 'package:open_gym/open_gym.dart';
import 'package:open_gym/src/ui/active_workout_screen.dart';
import 'package:open_gym/src/ui/open_gym_dashboard_screen.dart';

class _InMemoryHealthDataStore implements HealthDataStore {
  final Map<String, Map<String, Map<String, dynamic>>> _data =
      <String, Map<String, Map<String, dynamic>>>{};

  Map<String, Map<String, dynamic>> _col(String moduleId, String collection) {
    return _data.putIfAbsent(
      '$moduleId::$collection',
      () => <String, Map<String, dynamic>>{},
    );
  }

  @override
  Future<void> clearModuleData(String moduleId) async {
    _data.removeWhere((key, _) => key.startsWith('$moduleId::'));
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    _col(moduleId, collection).remove(id);
  }

  @override
  Future<List<Map<String, dynamic>>> readCollection(
    String moduleId,
    String collection,
  ) async {
    return _col(moduleId, collection).values.toList();
  }

  @override
  Future<Map<String, dynamic>?> readRecord(
    String moduleId,
    String collection,
    String id,
  ) async {
    return _col(moduleId, collection)[id];
  }

  @override
  Future<void> upsertRecord(
    String moduleId,
    String collection,
    Map<String, dynamic> record,
  ) async {
    final id = record['id'] as String? ?? 'default';
    _col(moduleId, collection)[id] = Map<String, dynamic>.from(record);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('housekeepr/shortcuts');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('OpenGymShortcutService sends template name and fallback labels', () async {
    const service = OpenGymShortcutService(channel: channel);
    final template = WorkoutTemplate.create(
      name: 'Push Day',
      iconKey: 'dumbbell',
      entries: const <WorkoutTemplateEntry>[],
    );

    await service.updateNextWorkoutShortcut(template);
    expect(calls, hasLength(1));
    expect(calls.first.method, 'updateNextWorkoutShortcut');
    final args = calls.first.arguments as Map<Object?, Object?>;
    expect(args['shortLabel'], 'Next: Push Day');
    expect(args['longLabel'], 'Start Push Day');
    expect(args['iconColor'], OpenGymShortcutService.defaultIconColor.toARGB32());
    expect(
      args['backgroundColor'],
      OpenGymShortcutService.defaultBackgroundColor.toARGB32(),
    );
    expect(args['iconBytes'], isA<Uint8List>());
    expect((args['iconBytes'] as Uint8List).isNotEmpty, isTrue);

    await service.updateNextWorkoutShortcut(
      null,
      iconColor: const Color(0xFF1565C0),
      backgroundColor: const Color(0xFF0D111A),
    );
    expect(calls, hasLength(2));
    expect(calls.last.arguments, <String, dynamic>{
      'shortLabel': 'Quick Workout',
      'longLabel': 'Start Quick Workout',
      'iconColor': const Color(0xFF1565C0).toARGB32(),
      'backgroundColor': const Color(0xFF0D111A).toARGB32(),
    });
  });

  test('OpenGymController syncs dynamic shortcut on initialize and finishWorkout', () async {
    final store = _InMemoryHealthDataStore();
    final repo = OpenGymRepository(store);
    final push = WorkoutTemplate.create(
      name: 'Push A',
      entries: const <WorkoutTemplateEntry>[],
    );
    final pull = WorkoutTemplate.create(
      name: 'Pull A',
      entries: const <WorkoutTemplateEntry>[],
    );
    await repo.saveTemplate(push);
    await repo.saveTemplate(pull);
    await repo.savePreferences(
      OpenGymPreferences(
        rotationSequence: <String>[push.id, pull.id],
        updatedAt: HealthRecordMetadata.nowUtcIso(),
      ),
    );

    final controller = OpenGymController(store: store);
    await controller.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(calls, isNotEmpty);
    final initArgs = calls.last.arguments as Map<Object?, Object?>;
    expect(initArgs['shortLabel'], 'Next: Push A');
    expect(initArgs['longLabel'], 'Start Push A');
    expect(
      initArgs['iconColor'],
      OpenGymShortcutService.defaultIconColor.toARGB32(),
    );
    expect(
      initArgs['backgroundColor'],
      OpenGymShortcutService.defaultBackgroundColor.toARGB32(),
    );
    expect(initArgs['iconBytes'], isA<Uint8List>());

    controller.updateShortcutColors(
      iconColor: const Color(0xFF64B5F6),
      backgroundColor: const Color(0xFF0D111A),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final themedArgs = calls.last.arguments as Map<Object?, Object?>;
    expect(themedArgs['iconColor'], const Color(0xFF64B5F6).toARGB32());
    expect(themedArgs['backgroundColor'], const Color(0xFF0D111A).toARGB32());

    controller.startFromTemplate(push);
    await controller.finishWorkout();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final nextArgs = calls.last.arguments as Map<Object?, Object?>;
    expect(nextArgs['shortLabel'], 'Next: Pull A');
    expect(nextArgs['longLabel'], 'Start Pull A');
    expect(nextArgs['iconColor'], const Color(0xFF64B5F6).toARGB32());
    expect(nextArgs['backgroundColor'], const Color(0xFF0D111A).toARGB32());
    expect(nextArgs['iconBytes'], isA<Uint8List>());

    controller.dispose();
  });

  testWidgets(
    'OpenGymDashboardScreen auto-starts next workout when autoStartNextWorkout is true',
    (tester) async {
      final store = _InMemoryHealthDataStore();
      final repo = OpenGymRepository(store);
      final push = WorkoutTemplate.create(
        name: 'Push A',
        entries: const <WorkoutTemplateEntry>[],
      );
      await repo.saveTemplate(push);

      final controller = OpenGymController(store: store);
      await tester.runAsync(() => controller.initialize());

      await tester.pumpWidget(
        MaterialApp(
          home: OpenGymDashboardScreen(
            controller: controller,
            onExitModule: () {},
            autoStartNextWorkout: true,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.hasActiveWorkout, isTrue);
      expect(controller.activeWorkout?.title, 'Push A');
      expect(find.byType(ActiveWorkoutScreen), findsOneWidget);

      controller.discardWorkout();
      controller.dispose();
    },
  );
}
