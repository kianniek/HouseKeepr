import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';

import '../test_utils.dart';

import 'package:housekeepr/firestore/remote_task_repository.dart';
import 'package:housekeepr/services/write_queue.dart' as wq;

class FakeRemoteTaskRepo implements RemoteTaskRepository {
  int saveCalls = 0;
  int deleteCalls = 0;
  final List<Task> saved = [];

  @override
  Future<void> saveTask(Task t) async {
    saveCalls++;
    saved.add(t);
  }

  @override
  Future<void> deleteTask(String id) async {
    deleteCalls++;
  }
}

class CapturingWriteQueue extends wq.WriteQueue {
  CapturingWriteQueue(super.prefs);
  wq.QueueOp? lastOp;
  @override
  void enqueueOp(wq.QueueOp op) {
    lastOp = op;
    super.enqueueOp(op);
  }
}

void main() {
  test(
    'TaskCubit calls remoteRepo.saveTask when sync and no writeQueue',
    () async {
      final prefs = InMemoryPrefs();
      final repo = TaskRepository(prefs);
      final settings = SettingsRepository(prefs);
      await settings.setSyncMode(SyncMode.sync);

      final cubit = TaskCubit(repo, settings: settings);

      final fakeRemote = FakeRemoteTaskRepo();
      cubit.setRemoteRepository(fakeRemote);

      final task = Task(id: 'rt1', title: 'Remote');
      await cubit.addTask(task);

      // local state updated
      expect(cubit.state.tasks.any((t) => t.id == 'rt1'), isTrue);
      // remote save should have been invoked
      expect(fakeRemote.saveCalls, 1);
    },
  );

  test('TaskCubit enqueues op when writeQueue provided', () async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);
    final settings = SettingsRepository(prefs);
    await settings.setSyncMode(SyncMode.sync);

    final prefs2 = InMemoryPrefs();
    final fakeWrite = CapturingWriteQueue(prefs2);
    final cubit = TaskCubit(repo, settings: settings, writeQueue: fakeWrite);

    final fakeRemote = FakeRemoteTaskRepo();
    cubit.setRemoteRepository(fakeRemote);

    final task = Task(id: 'rt2', title: 'Queued');
    await cubit.addTask(task);

    // local state updated
    expect(cubit.state.tasks.any((t) => t.id == 'rt2'), isTrue);
    // remote should not be called directly
    expect(fakeRemote.saveCalls, 0);
    // writeQueue should have an op
    expect(fakeWrite.lastOp, isNotNull);
    expect(fakeWrite.lastOp!.type, wq.QueueOpType.saveTask);
    expect(fakeWrite.lastOp!.id, 'rt2');
  });
}
