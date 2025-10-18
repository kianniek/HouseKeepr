import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/models/shopping_item.dart';

void main() {
  test('Task.fromMap handles missing optional fields and defaults', () {
    final map = {
      'id': 't123',
      'title': 'Edge',
      // no description, no assigned_to_id/name, no subTasks, no priority
    };

    final t = Task.fromMap(map);
    expect(t.id, 't123');
    expect(t.title, 'Edge');
    expect(t.description, isNull);
    expect(t.assignedToId, isNull);
    expect(t.subTasks, isEmpty);
    expect(t.priority, TaskPriority.medium); // default index 1
    expect(t.completed, isFalse);
  });

  test('SubTask.fromMap default completed false when missing', () {
    final map = {'id': 's1', 'title': 'Sub'};
    final s = SubTask.fromMap(map);
    expect(s.completed, isFalse);
  });

  test('ShoppingItem.fromMap handles missing fields and defaults', () {
    final map = {'id': 'i1', 'name': 'Item'};
    final it = ShoppingItem.fromMap(map);
    expect(it.id, 'i1');
    expect(it.name, 'Item');
    expect(it.note, isNull);
    expect(it.quantity, 1);
    expect(it.inCart, isFalse);
  });

  test('Roundtrip JSON with special characters', () {
    final t = Task(
      id: 'r1',
      title: 'T 💡 — special/çhars',
      description: 'Line1\nLine2 — emojis 👍',
    );
    final json = t.toJson();
    final restored = Task.fromJson(json);
    expect(restored.title, t.title);
    expect(restored.description, t.description);
  });

  test('Large subTasks list roundtrip', () {
    final subs = List.generate(500, (i) => SubTask(id: 's$i', title: 'sub $i'));
    final t = Task(id: 'big', title: 'Big', subTasks: subs);
    final map = t.toMap();
    final restored = Task.fromMap(map);
    expect(restored.subTasks.length, subs.length);
    expect(restored.subTasks.first.id, 's0');
    expect(restored.subTasks.last.id, 's499');
  });

  test('Defensive parsing: handles wrong types', () {
    final bad = {
      'id': 123, // number instead of string
      'title': 456,
      'priority': '2',
      'completed': 'true',
      'subTasks': [
        {'id': 1, 'title': 2, 'completed': 1},
        'invalid-json',
      ],
    };

    final t = Task.fromMap(bad);
    expect(t.id, '123');
    expect(t.title, '456');
    expect(t.priority, TaskPriority.values[2]);
    expect(t.completed, isTrue);
    // subTasks should parse the first and ignore the second
    expect(t.subTasks.length, 1);

    final badItem = {'id': 999, 'name': 100, 'quantity': '3', 'inCart': '1'};
    final it = ShoppingItem.fromMap(badItem);
    expect(it.id, '999');
    expect(it.name, '100');
    expect(it.quantity, 3);
    expect(it.inCart, isTrue);
  });
}
