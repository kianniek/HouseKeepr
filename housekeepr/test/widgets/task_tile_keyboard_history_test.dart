import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import 'package:housekeepr/ui/household_dashboard_page.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/repositories/history_repository.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/models/completion_record.dart';

import '../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskListTile keyboard & history', () {
    late TaskCubit cubit;
    late HistoryRepository hr;

    setUp(() async {
      final prefs = InMemoryPrefs();
      final repo = TaskRepository(prefs);
      cubit = TaskCubit(repo);
      hr = HistoryRepository(prefs);
      cubit.attachWriteQueueAndHistory(null, hr);
    });

    tearDown(() {
      cubit.close();
    });

    testWidgets('Space toggles completion via keyboard', (
      WidgetTester tester,
    ) async {
      final task = Task(id: 'k1', title: 'Keyboard Task');
      await cubit.addTask(task);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TaskCubit>.value(
            value: cubit,
            child: Scaffold(body: TaskListTile(task: task)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Give focus by tapping the tile
      final tile = find.text('Keyboard Task');
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      // Send SPACE key
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      // Cubit state should reflect the completed change
      final updated = cubit.state.tasks.firstWhere((t) => t.id == 'k1');
      expect(updated.completed, true);
    });

    testWidgets('H opens history dialog via keyboard', (
      WidgetTester tester,
    ) async {
      final task = Task(id: 'h1', title: 'History Task');
      await cubit.addTask(task);

      // add a completion record for that task
      final rec = CompletionRecord(
        taskId: 'h1',
        date: '2025-01-01',
        completedBy: 'tester',
      );
      await hr.add(rec);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TaskCubit>.value(
            value: cubit,
            child: Scaffold(body: TaskListTile(task: task)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Focus the tile
      await tester.tap(find.text('History Task'));
      await tester.pumpAndSettle();

      // Send 'H' key
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pumpAndSettle();

      // The Dialog with title 'Task history' should be visible
      expect(find.text('Task history'), findsOneWidget);
    });
  });
}
