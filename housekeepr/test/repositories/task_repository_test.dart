import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/repositories/task_repository.dart';

import '../test_utils.dart';

void main() {
  test('TaskRepository CRUD operations', () async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);

    // initially empty
    expect(repo.loadTasks(), isEmpty);

    final t1 = await repo.createTask(title: 'T1', description: 'd1');
    expect(t1.title, 'T1');

    var tasks = repo.loadTasks();
    expect(tasks.length, 1);

    final updated = t1.copyWith(title: 'T1-updated');
    await repo.updateTask(updated);
    tasks = repo.loadTasks();
    expect(tasks.first.title, 'T1-updated');

    await repo.deleteTask(t1.id);
    expect(repo.loadTasks(), isEmpty);
  });
}
