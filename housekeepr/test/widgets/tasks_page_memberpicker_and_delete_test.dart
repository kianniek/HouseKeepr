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
  testWidgets('Trailing delete button removes task', (tester) async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);
    final settings = SettingsRepository(prefs);
    await settings.setSyncMode(SyncMode.localOnly);

    final cubit = TaskCubit(repo, settings: settings);
    final t = Task(id: 'td1', title: 'Take out trash');
    cubit.addTask(t);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TaskCubit>.value(
          value: cubit,
          child: const TasksPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Take out trash'), findsOneWidget);

    // Tap the trailing delete icon
    final deleteBtn = find.byIcon(Icons.delete).first;
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();

    expect(find.text('Take out trash'), findsNothing);
    expect(cubit.state.tasks.where((e) => e.id == 'td1'), isEmpty);
  });

  testWidgets('Add Task dialog with MemberPicker (household) adds task', (
    tester,
  ) async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);
    final settings = SettingsRepository(prefs);
    await settings.setSyncMode(SyncMode.localOnly);

    final cubit = TaskCubit(repo, settings: settings);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TaskCubit>.value(
          value: cubit,
          // provide a householdId so TasksPage renders MemberPicker branch
          child: const TasksPage(householdId: 'hhouse'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No tasks yet'), findsOneWidget);

    // open add dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Enter title and Add. MemberPicker will fallback to Unassigned in tests
    await tester.enterText(find.byType(TextField).first, 'Buy eggs');
    await tester.pump();
    final addBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Add'),
    );
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(find.text('Buy eggs'), findsOneWidget);
    final created = cubit.state.tasks.firstWhere((t) => t.title == 'Buy eggs');
    expect(created.assignedToId, isNull);
    expect(created.assignedToName, isNull);
  });
}
