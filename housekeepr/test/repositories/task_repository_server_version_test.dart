import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskRepository server version persistence', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('save and load task with serverVersion and lastSyncedAt', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = TaskRepository(prefs);
      final now = DateTime.utc(2023, 10, 31, 12, 0, 0);
      final t = Task(
        id: 's1',
        title: 'ServerVersionTask',
        serverVersion: 42,
        lastSyncedAt: now,
      );
      await repo.createTaskObject(t);

      // Recreate repository to simulate app restart
      final repo2 = TaskRepository(prefs);
      final loaded = repo2.loadTasks();
      expect(loaded.length, 1);
      final lt = loaded.first;
      expect(lt.serverVersion, 42);
      expect(lt.lastSyncedAt, isNotNull);
      expect(lt.lastSyncedAt!.toUtc(), now);
    });
  });
}
