import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/task.dart';

void main() {
  test('Task toMap/fromMap roundtrip preserves sync fields and isRetrying', () {
    final now = DateTime.now().toUtc();

    final t = Task(
      id: 'id1',
      title: 'Roundtrip',
      description: 'desc',
      assignedToId: 'u1',
      assignedToName: 'User',
      subTasks: const [],
      priority: TaskPriority.high,
      completed: false,
      photoPath: null,
      deadline: now,
      isRepeating: false,
      repeatRule: null,
      repeatDays: null,
      completedDates: null,
      isHouseholdTask: true,
      syncStatus: SyncStatus.failed,
      lastSyncError: 'boom',
      lastSyncedAt: now,
      localVersion: 3,
      serverVersion: 5,
      isRetrying: true,
    );

    final map = t.toMap();
    // Simulate JSON encoding/decoding roundtrip
    final recovered = Task.fromMap(Map<String, dynamic>.from(map));

    expect(recovered.id, t.id);
    expect(recovered.title, t.title);
    expect(recovered.description, t.description);
    expect(recovered.assignedToId, t.assignedToId);
    expect(recovered.assignedToName, t.assignedToName);
    expect(recovered.priority, t.priority);
    expect(recovered.completed, t.completed);
    // Compare dates via ISO strings to avoid microsecond issues
    expect(
      recovered.deadline?.toUtc().toIso8601String(),
      t.deadline?.toUtc().toIso8601String(),
    );
    expect(recovered.syncStatus, t.syncStatus);
    expect(recovered.lastSyncError, t.lastSyncError);
    expect(
      recovered.lastSyncedAt?.toUtc().toIso8601String(),
      t.lastSyncedAt?.toUtc().toIso8601String(),
    );
    expect(recovered.localVersion, t.localVersion);
    expect(recovered.serverVersion, t.serverVersion);
    expect(recovered.isRetrying, t.isRetrying);
  });
}
