import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/task.dart';

void main() {
  test('Task Serialization Test', () {
    final deadline = DateTime.utc(2025, 1, 2, 3, 4, 5);
    final t = Task(
      id: 't1',
      title: 'Do things',
      description: 'A test task',
      assignedToId: 'u1',
      assignedToName: 'User One',
      subTasks: [SubTask(id: 's1', title: 'sub', completed: true)],
      priority: TaskPriority.high,
      completed: false,
      photoPath: '/tmp/x',
      deadline: deadline,
      isRepeating: true,
      repeatRule: 'weekly',
      repeatDays: [1, 3, 5],
      completedDates: ['2025-01-01'],
      isHouseholdTask: true,
      householdId: 'h1',
      archived: false,
      reminderEnabled: true,
      reminderOffsetMinutes: 30,
      syncStatus: SyncStatus.pending,
      lastSyncError: 'none',
      lastSyncedAt: DateTime.utc(2025, 1, 1),
      localVersion: 7,
      serverVersion: 9,
      isRetrying: false,
    );

    final map = t.toMap();
    final parsed = Task.fromMap(map);

    expect(parsed.id, t.id);
    expect(parsed.title, t.title);
    expect(parsed.description, t.description);
    expect(parsed.assignedToId, t.assignedToId);
    expect(parsed.assignedToName, t.assignedToName);
    expect(parsed.subTasks.length, 1);
    expect(parsed.priority, t.priority);
    expect(parsed.completed, t.completed);
    expect(parsed.photoPath, t.photoPath);
    expect(parsed.deadline, t.deadline!.toUtc());
    expect(parsed.isRepeating, true);
    expect(parsed.repeatRule, 'weekly');
    expect(parsed.repeatDays, [1, 3, 5]);
    expect(parsed.completedDates, ['2025-01-01']);
    expect(parsed.isHouseholdTask, true);
    expect(parsed.householdId, 'h1');
    expect(parsed.reminderEnabled, true);
    expect(parsed.reminderOffsetMinutes, 30);
    expect(parsed.syncStatus, SyncStatus.pending);
    expect(parsed.localVersion, 7);
    expect(parsed.serverVersion, 9);
  });
}
