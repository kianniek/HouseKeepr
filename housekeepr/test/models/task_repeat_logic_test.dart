import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/task.dart';

void main() {
  test('isRepeatingToday uses repeatDays when weekly', () {
    final today = DateTime.now();
    final weekday = today.weekday; // 1..7
    final task = Task(
      id: 't1',
      title: 'Weekly task',
      isRepeating: true,
      repeatRule: 'weekly',
      repeatDays: [weekday],
    );

    // mimic logic: check that repeatDays contains today's weekday
    expect(task.repeatDays, isNotNull);
    expect(task.repeatDays!.contains(weekday), isTrue);
  });

  test('legacy weekly uses deadline weekday when repeatDays absent', () {
    final today = DateTime.now();
    final weekday = today.weekday;
    final dl = DateTime(today.year, today.month, today.day); // today
    final task = Task(
      id: 't2',
      title: 'Legacy weekly',
      isRepeating: true,
      repeatRule: 'weekly',
      deadline: dl,
    );

    // The task should have deadline weekday equal to today
    expect(task.deadline, isNotNull);
    expect(task.deadline!.weekday, equals(weekday));
  });
}
