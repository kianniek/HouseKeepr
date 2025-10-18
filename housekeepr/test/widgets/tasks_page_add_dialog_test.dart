import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/ui/tasks_page.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';

import '../test_utils.dart';

void main() {
  testWidgets('Add Task dialog flow updates cubit and shows item', (
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
          child: const TasksPage(),
        ),
      ),
    );

    expect(find.text('No tasks yet'), findsOneWidget);

    // open add dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // enter title and add
    await tester.enterText(find.byType(TextField).first, 'New Task');
    // allow StatefulBuilder to rebuild the dialog buttons
    await tester.pump();
    final addBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Add'),
    );
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // Now the list should show the created task
    expect(find.text('New Task'), findsOneWidget);
    expect(cubit.state.tasks.any((t) => t.title == 'New Task'), isTrue);
  });
}
