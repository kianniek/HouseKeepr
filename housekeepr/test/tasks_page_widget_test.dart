import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:housekeepr/ui/tasks_page.dart';
import 'package:housekeepr/ui/task_add_dialog.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/models/task.dart';

import 'test_utils.dart';

void main() {
  group('TasksPage widget', () {
    late TaskCubit cubit;

    setUp(() {
      final prefs = InMemoryPrefs();
      final repo = TaskRepository(prefs);
      cubit = TaskCubit(repo);
    });

    tearDown(() {
      cubit.close();
    });

    testWidgets('can add a new task via FAB dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TaskCubit>.value(
            value: cubit,
            child: Scaffold(
              body: TasksPage(),
              floatingActionButton: Builder(
                builder: (ctx) => FloatingActionButton(
                  onPressed: () =>
                      showTaskAddEditDialog(ctx, currentUser: null),
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ),
        ),
      );

      // Ensure page built
      await tester.pumpAndSettle();

      // Tap FAB
      final fab = find.byIcon(Icons.add);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('New Task'), findsOneWidget);

      // Enter title (first TextField)
      final titleField = find.widgetWithText(TextField, 'Title');
      expect(titleField, findsOneWidget);
      await tester.enterText(titleField, 'Test task');
      await tester.pumpAndSettle();

      // Press Add
      final addButton = find.widgetWithText(ElevatedButton, 'Add');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Task should appear in the list
      expect(find.text('Test task'), findsOneWidget);
    });

    testWidgets('can edit an existing task', (WidgetTester tester) async {
      // Pre-populate cubit with a task
      final t = Task(id: 'id1', title: 'Original');
      await cubit.addTask(t);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TaskCubit>.value(
            value: cubit,
            child: Scaffold(
              body: TasksPage(),
              floatingActionButton: Builder(
                builder: (ctx) => FloatingActionButton(
                  onPressed: () =>
                      showTaskAddEditDialog(ctx, currentUser: null),
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find the original title
      expect(find.text('Original'), findsOneWidget);

      // Tap the edit icon for that task. There may be multiple edit icons; find by ancestor
      final editButtons = find.byIcon(Icons.edit);
      expect(editButtons, findsWidgets);

      // Tap the first edit button
      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      // Dialog should say 'Edit Task'
      expect(find.text('Edit Task'), findsOneWidget);

      // Change title: find the Title text field and enter new text
      final titleField = find.widgetWithText(TextField, 'Title');
      expect(titleField, findsOneWidget);
      await tester.enterText(titleField, 'Updated');
      await tester.pumpAndSettle();

      // Tap Save (button text is 'Save')
      final saveButton = find.widgetWithText(ElevatedButton, 'Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // New title should be visible
      expect(find.text('Updated'), findsOneWidget);
      expect(find.text('Original'), findsNothing);
    });
  });
}
