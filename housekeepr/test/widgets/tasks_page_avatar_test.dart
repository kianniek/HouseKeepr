import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/ui/tasks_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Displays assignee initials when no photo', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = TaskRepository(prefs);
    final cubit = TaskCubit(repo);
    final t = Task(id: '1', title: 'Hello', assignedToName: 'Alice Bob');
    await cubit.addTask(t);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TaskCubit>.value(
          value: cubit,
          child: const TasksPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Expect initials 'AB' to be displayed by AssigneeAvatar
    expect(find.text('AB'), findsOneWidget);
  });
}
