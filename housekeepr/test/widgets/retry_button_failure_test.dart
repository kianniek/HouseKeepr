import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/ui/household_dashboard_page.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/models/task.dart';

import '../test_utils.dart';

class FakeTaskCubitFail extends TaskCubit {
  final Completer<bool> completer = Completer<bool>();
  FakeTaskCubitFail(super.repo);

  @override
  Future<bool> retryTask(String taskId) {
    return completer.future;
  }
}

void main() {
  testWidgets('Retry failure shows failure SnackBar and clears progress', (
    WidgetTester tester,
  ) async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);
    final cubit = FakeTaskCubitFail(repo);

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

    // Complete the retry future with failure (false)
    cubit.completer.complete(false);
    await tester.pumpAndSettle();

    // SnackBar with failure message should be shown
    expect(find.text('Retry failed to start'), findsOneWidget);

    // Progress indicator should be gone
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
