import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/ui/household_dashboard_page.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/models/task.dart';

import '../test_utils.dart';

class FakeTaskCubit extends TaskCubit {
  final Completer<bool> completer = Completer<bool>();
  FakeTaskCubit(super.repo);

  @override
  Future<bool> retryTask(String taskId) {
    return completer.future;
  }
}

void main() {
  testWidgets('Retry button shows progress indicator and SnackBar', (
    WidgetTester tester,
  ) async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);
    final cubit = FakeTaskCubit(repo);

    final task = Task(
      id: 't1',
      title: 'Failing Task',
      syncStatus: SyncStatus.failed,
      lastSyncError: 'Network error',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TaskCubit>.value(
          value: cubit,
          child: Scaffold(body: TaskListTile(task: task)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // retry button is present
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    // Tap retry
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    // Progress indicator should appear while the future is unresolved
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete the retry future successfully
    cubit.completer.complete(true);
    await tester.pumpAndSettle();

    // SnackBar with success message should be shown
    expect(find.text('Retry started'), findsOneWidget);

    // Progress indicator should be gone
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
