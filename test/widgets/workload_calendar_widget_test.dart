import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/ui/features/tasks/pages/tasks_page.dart';
import 'package:housekeepr/ui/features/tasks/widgets/workload_calendar_card.dart';
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

  testWidgets('WorkloadCalendarCard toggles Week/Month and filters TasksPage on tap',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));

    final tasks = [
      Task(
        id: '1',
        title: 'Today chore',
        room: 'Kitchen',
        assignedToId: 'user-1',
        deadline: today,
      ),
      Task(
        id: '2',
        title: 'Tomorrow chore',
        room: 'Bathroom',
        assignedToId: 'user-1',
        deadline: tomorrow,
      ),
      Task(
        id: '3',
        title: 'Overdue chore',
        room: 'Kitchen',
        assignedToId: 'user-1',
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

    final cubit = TaskCubit(mockRepo, settings: mockSettings);
    await cubit.initializationFuture;

    await tester.pumpWidget(buildPage(cubit, user: mockUser));
    await tester.pumpAndSettle();

    expect(find.byType(WorkloadCalendarCard), findsOneWidget);
    // Defaults to Week view -> button shows "Month" to expand
    expect(find.text('Month'), findsOneWidget);
    // Compact view starts on Today (first day cell is today's day number)
    expect(find.text('${today.day}'), findsWidgets);

    // Toggle to Month view
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('Week'), findsOneWidget);

    // Toggle back to Week view (resets to Today as first day)
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('Month'), findsOneWidget);

    // Tap Tomorrow in the rolling strip -> filters without shifting Today off first column
    await tester.tap(
      find.descendant(
        of: find.byType(WorkloadCalendarCard),
        matching: find.text('${tomorrow.day}'),
      ).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Tomorrow chore'), findsOneWidget);
    expect(find.text('Today chore'), findsNothing);
    expect(find.text('${today.day}'), findsWidgets);

    // Tap Today in the calendar to filter to Today + Overdue
    await tester.tap(
      find.descendant(
        of: find.byType(WorkloadCalendarCard),
        matching: find.text('${today.day}'),
      ).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Due Today'), findsOneWidget);
    expect(find.text('Today chore'), findsOneWidget);
    expect(find.text('Overdue chore'), findsOneWidget);
    expect(find.text('Tomorrow chore'), findsNothing);
    expect(find.text('Clear'), findsOneWidget);

    // Tap Clear to return to all tasks
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Due Soon'), findsOneWidget);
    expect(find.text('Tomorrow chore'), findsOneWidget);

    await cubit.close();
  });
}
