import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskRepository', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('create and load paginated tasks', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = TaskRepository(prefs);
      // create 5 tasks
      for (int i = 0; i < 5; i++) {
        await repo.createTaskObject(Task(id: 't$i', title: 'Task $i'));
      }
      final page1 = repo.loadTasksPage(offset: 0, limit: 3);
      expect(page1.length, 3);
      final page2 = repo.loadTasksPage(offset: 3, limit: 3);
      expect(page2.length, 2);
    });

    test('archived tasks are filterable', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = TaskRepository(prefs);
      await repo.createTaskObject(Task(id: 'a', title: 'Active'));
      await repo.createTaskObject(
        Task(id: 'b', title: 'Archived', archived: true),
      );
      final all = repo.loadTasks();
      expect(all.length, 2);
      final page = repo.loadTasksPage(
        offset: 0,
        limit: 10,
        includeArchived: false,
      );
      expect(page.any((t) => t.archived), false);
      expect(page.length, 1);
    });
  });
}
