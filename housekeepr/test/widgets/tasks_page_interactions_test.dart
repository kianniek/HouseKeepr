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
  testWidgets('Checkbox toggles task completed and delete removes task', (
    tester,
  ) async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);
    final settings = SettingsRepository(prefs);
    await settings.setSyncMode(SyncMode.localOnly);

    final cubit = TaskCubit(repo, settings: settings);

    // Add an initial task directly through the cubit so the page shows it.
    final task = Task(id: 't1', title: 'Do laundry');
    cubit.addTask(task);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TaskCubit>.value(
          value: cubit,
          child: const TasksPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Do laundry'), findsOneWidget);

    // Toggle the checkbox (leading) to mark completed
    final checkbox = find.byType(Checkbox).first;
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(cubit.state.tasks.any((t) => t.id == 't1' && t.completed), isTrue);

    // Tap trailing delete button and ensure task removed
    final deleteBtn = find.byIcon(Icons.delete).first;
    expect(deleteBtn, findsOneWidget);
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();

    expect(find.text('Do laundry'), findsNothing);
    expect(cubit.state.tasks.where((t) => t.id == 't1'), isEmpty);
  });
}
