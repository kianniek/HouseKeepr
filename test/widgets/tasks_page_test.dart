import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/home_screen.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/ui/features/tasks/pages/tasks_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockTaskRepository extends Mock implements TaskRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockUser extends Mock implements fb.User {}

void main() {
  late _MockTaskRepository mockRepo;
  late _MockSettingsRepository mockSettings;
  late _MockUser mockUser;

  setUpAll(() {
    registerFallbackValue(<Task>[]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepo = _MockTaskRepository();
    mockSettings = _MockSettingsRepository();
    mockUser = _MockUser();

    when(() => mockUser.uid).thenReturn('user-1');
    when(() => mockSettings.getSyncMode()).thenReturn(SyncMode.localOnly);
    when(
      () => mockRepo.materializeOccurrences(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockRepo.saveTasks(any())).thenAnswer((_) async {});
  });

  Widget buildPage(TaskCubit cubit, {fb.User? user}) {
    return MaterialApp(
      home: BlocProvider<TaskCubit>.value(
        value: cubit,
        child: TasksPage(currentUser: user),
      ),
    );
  }

  testWidgets(
    'removes Check off all tasks, shows My Tasks & time-horizon sections',
    (tester) async {
      final now = DateTime.now();
      final tasks = [
        Task(
          id: '1',
          title: 'Wipe kitchen counter.',
          room: 'Kitchen',
          assignedToId: 'user-1',
          assignedToName: 'Alice',
          deadline: now,
        ),
        Task(
          id: '2',
          title: 'Clean bathroom mirror',
          room: 'Bathroom',
          assignedToId: 'user-2',
          assignedToName: 'Bob',
          deadline: now.add(const Duration(days: 10)),
        ),
        const Task(
          id: '3',
          title: 'Organize closet',
          room: 'Bedroom',
          isHouseholdTask: true,
        ),
      ];

      when(
        () => mockRepo.loadTasksPage(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        ),
      ).thenReturn(tasks);
      when(() => mockRepo.loadTasks()).thenReturn(tasks);

      final cubit = TaskCubit(mockRepo, settings: mockSettings);
      await cubit.initializationFuture;

      await tester.pumpWidget(buildPage(cubit, user: mockUser));
      await tester.pumpAndSettle();

      // #7: Check off all tasks removed
      expect(find.text('Check off all tasks'), findsNothing);
      expect(find.text('My Tasks'), findsOneWidget);

      // #8: Trailing period stripped on display
      expect(find.text('Wipe kitchen counter'), findsOneWidget);
      expect(find.text('Wipe kitchen counter.'), findsNothing);

      // #6: Grouped into Due Soon, Upcoming, Whenever
      expect(find.text('Due Soon'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Whenever'), findsOneWidget);

      // #5: Bottom Done / Put Off buttons removed
      expect(find.text('Done'), findsNothing);
      expect(find.text('Put Off'), findsNothing);

      // #7: Toggle My Tasks filter
      await tester.tap(find.text('My Tasks'));
      await tester.pumpAndSettle();

      expect(find.text('Wipe kitchen counter'), findsOneWidget);
      expect(find.text('Clean bathroom mirror'), findsNothing);
      expect(find.text('Organize closet'), findsNothing);

      // Compose with Kitchen room filter
      await tester.tap(find.text('Kitchen'));
      await tester.pumpAndSettle();
      expect(find.text('Wipe kitchen counter'), findsOneWidget);

      await cubit.close();
    },
  );

  testWidgets('tapping a task card opens Task Detail sheet with Last completed',
      (tester) async {
    final tasks = [
      const Task(
        id: '1',
        title: 'Refresh water filter',
        room: 'Kitchen',
        description: 'Replace Brita cartridge',
        isRepeating: true,
        repeatRule: 'every:1:month',
        completedDates: ['2026-10-15'],
      ),
    ];

    when(
      () => mockRepo.loadTasksPage(
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenReturn(tasks);
    when(() => mockRepo.loadTasks()).thenReturn(tasks);

    final cubit = TaskCubit(mockRepo, settings: mockSettings);
    await cubit.initializationFuture;

    await tester.pumpWidget(buildPage(cubit, user: mockUser));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refresh water filter'));
    await tester.pumpAndSettle();

    expect(find.text('Last completed: 2026-10-15'), findsOneWidget);
    expect(find.text('Replace Brita cartridge'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await cubit.close();
  });

  testWidgets('AppBar Auto-Balance button opens preview sheet and reschedules',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tasks = [
      Task(
        id: '1',
        title: 'Vacuum living room',
        deadline: today,
      ),
      Task(
        id: '2',
        title: 'Clean sink',
        deadline: today.subtract(const Duration(days: 1)),
      ),
    ];

    when(
      () => mockRepo.loadTasksPage(
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenReturn(tasks);
    when(() => mockRepo.loadTasks()).thenReturn(tasks);

    final cubit = TaskCubit(mockRepo, settings: mockSettings);
    await cubit.initializationFuture;

    await tester.pumpWidget(buildPage(cubit, user: mockUser));
    await tester.pumpAndSettle();

    final autoBalanceBtn = find.byTooltip('Auto-balance tasks');
    expect(autoBalanceBtn, findsOneWidget);

    await tester.tap(autoBalanceBtn);
    await tester.pumpAndSettle();

    expect(find.text('Auto-Balance Tasks'), findsOneWidget);
    expect(find.text('Keep up to 4 tasks for today'), findsOneWidget);

    // Toggle off "Keep up to 4 tasks for today" so both tasks move to upcoming days.
    await tester.tap(find.text('Keep up to 4 tasks for today'));
    await tester.pumpAndSettle();

    expect(find.text('Reschedule 2 tasks'), findsOneWidget);
    await tester.tap(find.text('Reschedule 2 tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Balanced 2 tasks'), findsOneWidget);
    for (final t in cubit.state.tasks) {
      expect(t.deadline!.toLocal().isAfter(today), isTrue);
    }

    await cubit.close();
  });

  testWidgets('pending openRebalanceSheetNotifier opens preview sheet on mount',
      (tester) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final tasks = [
      Task(
        id: '1',
        title: 'Overdue chore',
        deadline: yesterday,
      ),
    ];

    when(
      () => mockRepo.loadTasksPage(
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenReturn(tasks);
    when(() => mockRepo.loadTasks()).thenReturn(tasks);

    HomeScreen.openRebalanceSheetNotifier.value = true;
    final cubit = TaskCubit(mockRepo, settings: mockSettings);
    await cubit.initializationFuture;

    await tester.pumpWidget(buildPage(cubit, user: mockUser));
    await tester.pumpAndSettle();

    expect(HomeScreen.openRebalanceSheetNotifier.value, isFalse);
    expect(find.text('Auto-Balance Tasks'), findsOneWidget);
    expect(find.text('Overdue chore'), findsWidgets);

    await cubit.close();
  });
}
