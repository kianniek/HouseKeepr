import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/task.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('Task toMap/fromMap roundtrip preserves assignedTo', () {
    final id = const Uuid().v4();
    final task = Task(
      id: id,
      title: 'Test Task',
      description: 'A description',
      assignedToId: 'uid-alice',
      assignedToName: 'Alice',
    );

    final map = task.toMap();
    // Simulate Firestore adding id field separately
    map['id'] = id;
    final restored = Task.fromMap(map);

    expect(restored.id, equals(task.id));
    expect(restored.title, equals(task.title));
    expect(restored.description, equals(task.description));
    expect(restored.assignedToId, equals(task.assignedToId));
    expect(restored.assignedToName, equals(task.assignedToName));
  });
}
