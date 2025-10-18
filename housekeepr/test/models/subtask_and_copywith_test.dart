import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/task.dart';

void main() {
  test('SubTask toJson/fromJson roundtrip and copyWith', () {
    final s = SubTask(id: 's1', title: 'Sub', completed: true);
    final json = s.toJson();
    final restored = SubTask.fromJson(json);
    expect(restored, equals(s));

    final changed = s.copyWith(completed: false);
    expect(changed.completed, isFalse);
    expect(s.completed, isTrue);
  });

  test('Task copyWith single field change', () {
    final t = Task(id: 't1', title: 'Original', description: 'D');
    final t2 = t.copyWith(title: 'New');
    expect(t2.title, 'New');
    expect(t2.description, 'D');
  });
}
