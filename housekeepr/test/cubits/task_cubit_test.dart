import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';

import '../test_utils.dart';

void main() {
  test(
    'TaskCubit add/update/delete/replaceAll emits expected states',
    () async {
      final prefs = InMemoryPrefs();
      final repo = TaskRepository(prefs);
      final settings = SettingsRepository(prefs);
      await settings.setSyncMode(SyncMode.localOnly);

      final cubit = TaskCubit(repo, settings: settings);

      // initially empty
      expect(cubit.state.tasks, isEmpty);

      final task = Task(id: 't1', title: 'Title');
      await cubit.addTask(task);
      expect(cubit.state.tasks.length, 1);
      expect(cubit.state.tasks.first.title, 'Title');

      final updated = task.copyWith(title: 'New');
      await cubit.updateTask(updated);
      expect(cubit.state.tasks.first.title, 'New');

      await cubit.deleteTask('t1');
      expect(cubit.state.tasks, isEmpty);

      // replaceAll
      final t2 = Task(id: 't2', title: 'X');
      await cubit.replaceAll([t2]);
      expect(cubit.state.tasks.length, 1);
      expect(cubit.state.tasks.first.id, 't2');
    },
  );
}
