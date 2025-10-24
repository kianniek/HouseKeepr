import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/ui/tasks_page.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';
import 'package:housekeepr/models/task.dart';

import '../test_utils.dart';

void main() {
  testWidgets('Checking repeating task records today in completedDates', (
    tester,
  ) async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);
    final settings = SettingsRepository(prefs);
    await settings.setSyncMode(SyncMode.localOnly);

    final cubit = TaskCubit(repo, settings: settings);

    final today = DateTime.now();
    final weekday = today.weekday;

    final task = Task(
      id: 'r1',
      title: 'Take out trash',
      isRepeating: true,
      repeatRule: 'weekly',
      repeatDays: [weekday],
    );

    await cubit.addTask(task);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TaskCubit>.value(
          value: cubit,
          child: const TasksPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to the Repeating tab since the task is a repeating template
    await tester.tap(find.text('Repeating'));
    await tester.pumpAndSettle();

    expect(find.text('Take out trash'), findsOneWidget);

    // initial template completed should remain false
    expect(cubit.state.tasks.any((t) => t.id == 'r1' && t.completed), isFalse);

    // find the leading checkbox and tap it
    final checkbox = find.byType(Checkbox).first;
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    final todayStr = DateTime.now().toUtc().toIso8601String().split('T')[0];

    final updated = cubit.state.tasks.firstWhere((t) => t.id == 'r1');
    expect(updated.completed, isFalse);
    expect(updated.completedDates, isNotNull);
    expect(updated.completedDates!.contains(todayStr), isTrue);

    // untick should remove today's entry
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    final updated2 = cubit.state.tasks.firstWhere((t) => t.id == 'r1');
    expect(updated2.completedDates?.contains(todayStr) ?? false, isFalse);
  });
}
