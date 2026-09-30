import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/services/recurrence_generator.dart';

void main() {
  test('Recurrence Generator Daily Test', () {
    final t = Task(
      id: 'r1',
      title: 'daily',
      isRepeating: true,
      repeatRule: 'daily',
      deadline: DateTime.utc(2025, 1, 1),
    );

    final from = DateTime.utc(2025, 1, 1);
    final to = DateTime.utc(2025, 1, 5);
    final occ = generateOccurrencesForTask(t, from, to);
    expect(occ.length, 5);
    expect(occ.first, DateTime.utc(2025, 1, 1));
    expect(occ.last, DateTime.utc(2025, 1, 5));
  });

  test('Recurrence Generator Weekly Test', () {
    final t = Task(
      id: 'r2',
      title: 'weekly',
      isRepeating: true,
      repeatRule: 'weekly',
      repeatDays: [1, 3], // Mon & Wed
      deadline: DateTime.utc(2025, 1, 1),
    );

    // window covering two weeks
    final from = DateTime.utc(2024, 12, 30); // Mon
    final to = DateTime.utc(2025, 1, 12);
    final occ = generateOccurrencesForTask(t, from, to);
    // Should include Mondays and Wednesdays in window
    for (final d in occ) {
      expect([1, 3], contains(d.weekday));
    }
  });

  test('Recurrence Generator Monthly Test (31st handling)', () {
    final t = Task(
      id: 'r3',
      title: 'monthly',
      isRepeating: true,
      repeatRule: 'monthly',
      repeatDays: [31],
      deadline: DateTime.utc(2025, 1, 31),
    );

    final from = DateTime.utc(2025, 1, 1);
    final to = DateTime.utc(2025, 4, 30);
    final occ = generateOccurrencesForTask(t, from, to);
    // 2025 has Jan(31), Mar(31) within range; Feb (no 31) is skipped; Apr 30 -> no 31
    final expected = [DateTime.utc(2025, 1, 31), DateTime.utc(2025, 3, 31)];
    // Ensure expected 31sts are present and that no 31st was generated for Feb
    expect(occ, containsAll(expected));
    // ensure none of the occurrences falls in February with day 31
    for (final d in occ) {
      if (d.month == 2) expect(d.day != 31, isTrue);
    }
  });
}
