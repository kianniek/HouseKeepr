import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  group('TaskCubit', () {
    late MockTaskRepository mockRepo;
    late MockSettingsRepository mockSettings;

    setUpAll(() {
      registerFallbackValue(<Task>[]);
    });

    setUp(() {
      mockRepo = MockTaskRepository();
      mockSettings = MockSettingsRepository();

      // Default stubs
      when(() => mockSettings.getSyncMode()).thenReturn(SyncMode.sync);
      when(
        () => mockRepo.loadTasksPage(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        ),
      ).thenReturn([]);
      when(() => mockRepo.loadTasks()).thenReturn([]);
      when(
        () => mockRepo.materializeOccurrences(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockRepo.saveTasks(any())).thenAnswer((_) async {});
    });

    test('initial state is correct', () {
      final cubit = TaskCubit(mockRepo, settings: mockSettings);
      expect(cubit.state, TaskState.initial());
      cubit.close();
    });

    test('emits loaded tasks on initialization', () async {
      final cubit = TaskCubit(mockRepo, settings: mockSettings);
      await cubit.initializationFuture;
      expect(cubit.state.tasks, isEmpty);
      cubit.close();
    });

    test('adds a task and emits updated state', () async {
      final cubit = TaskCubit(mockRepo, settings: mockSettings);
      await cubit.initializationFuture;

      await cubit.addTask(Task(id: '1', title: 'Test Task'));

      expect(cubit.state.tasks.length, 1);
      expect(cubit.state.tasks.first.title, 'Test Task');
      verify(() => mockRepo.saveTasks(any())).called(1);
      cubit.close();
    });
  });
}
