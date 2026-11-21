import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/ui/features/dashboard/dashboard_page.dart';
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
    when(() => mockUser.displayName).thenReturn('Alex');
    when(() => mockSettings.getSyncMode()).thenReturn(SyncMode.localOnly);
    when(
      () => mockRepo.materializeOccurrences(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockRepo.saveTasks(any())).thenAnswer((_) async {});
  });

  testWidgets(
      'Daily Progress counts repeating tasks, shows overdue badge, and navigates to Today',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayStr = now.toUtc().toIso8601String().split('T')[0];

    final tasks = [
      Task(
        id: '1',
        title: 'Daily counter wipe',
        room: 'Kitchen',
        priority: TaskPriority.medium,
        isRepeating: true,
        repeatRule: 'every:1:day',
        deadline: yesterday,
        completedDates: [todayStr],
      ),
      Task(
        id: '2',
        title: 'Vacuum living room',
        room: 'Living Room',
        priority: TaskPriority.high,
        deadline: today,
      ),
      Task(
        id: '3',
        title: 'Old overdue chore',
        room: 'Bathroom',
        priority: TaskPriority.low,
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

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TaskCubit>.value(
          value: cubit,
          child: DashboardPage(currentUser: mockUser),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Daily Progress'), findsOneWidget);
    expect(find.text('1 overdue'), findsOneWidget);
    expect(find.text('1 of 2 done · 1 left'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Next up'), findsOneWidget);
    expect(find.text('Vacuum living room'), findsOneWidget);

    // Tapping the Next up task opens the Task Detail bottom sheet
    await tester.tap(find.text('Vacuum living room'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Dismiss the bottom sheet
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('View Today\'s Tasks'));
    await tester.pumpAndSettle();

    expect(find.byType(TasksPage), findsOneWidget);
    expect(find.text('Due Today'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);

    await cubit.close();
  });
}
