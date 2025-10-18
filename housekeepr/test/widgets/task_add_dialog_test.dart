import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/ui/tasks_page.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/models/task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housekeepr/repositories/task_repository.dart';

class FakeTaskCubit extends TaskCubit {
  FakeTaskCubit(super.repo);

  Task? lastAdded;

  @override
  Future<void> addTask(Task task) async {
    lastAdded = task;
    await super.addTask(task);
  }
}

void main() {
  testWidgets('Add dialog flow calls TaskCubit.addTask with assigned name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = TaskRepository(prefs);
    final cubit = FakeTaskCubit(repo);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TaskCubit>.value(
          value: cubit,
          child: const TasksPage(),
        ),
      ),
    );

    // Open add dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Enter title and assigned free-text (since householdId is null)
    await tester.enterText(find.byType(TextField).at(0), 'Buy milk');
    await tester.enterText(find.byType(TextField).at(1), 'Charlie');
    await tester.pumpAndSettle();

    // Add button should be enabled and tap it
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(cubit.lastAdded, isNotNull);
    expect(cubit.lastAdded!.title, 'Buy milk');
    expect(cubit.lastAdded!.assignedToName, 'Charlie');
  });
}
