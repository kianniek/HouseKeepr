import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/ui/features/tasks/utils/task_date_utils.dart';

void main() {
  group('sanitizeTaskTitle', () {
    test('strips single and multiple trailing periods and trims whitespace', () {
      expect(
        sanitizeTaskTitle('  Wipe down the walls.  '),
        'Wipe down the walls',
      );
      expect(sanitizeTaskTitle('Dust ceiling corners...'), 'Dust ceiling corners');
      expect(sanitizeTaskTitle('Refresh water filter'), 'Refresh water filter');
    });
  });

  group('formatRelativeDueDate & isOverdue', () {
    final now = DateTime(2026, 11, 15, 14, 0);

    test('formats Today, Tomorrow, future, and overdue labels', () {
      expect(
        formatRelativeDueDate(DateTime(2026, 11, 15, 9, 0), now: now),
        'Today',
      );
      expect(
        formatRelativeDueDate(DateTime(2026, 11, 16, 9, 0), now: now),
        'Tomorrow',
      );
      expect(
        formatRelativeDueDate(DateTime(2026, 11, 20, 9, 0), now: now),
        'In 5 days',
      );
      expect(
        formatRelativeDueDate(DateTime(2026, 11, 14, 9, 0), now: now),
        '1 day overdue',
      );
      expect(
        formatRelativeDueDate(DateTime(2026, 11, 12, 9, 0), now: now),
        '3 days overdue',
      );
    });

    test('isOverdue returns true only for past calendar days', () {
      expect(isOverdue(DateTime(2026, 11, 14, 23, 59), now: now), isTrue);
      expect(isOverdue(DateTime(2026, 11, 15, 8, 0), now: now), isFalse);
      expect(isOverdue(DateTime(2026, 11, 16, 8, 0), now: now), isFalse);
    });
  });

  group('classifyTimeHorizon', () {
    final now = DateTime(2026, 11, 15, 10, 0);

    test('groups overdue, today, and <= 3 days into dueSoon', () {
      final overdue = Task(
        id: '1',
        title: 'Overdue task',
        deadline: DateTime(2026, 11, 13),
      );
      final dueIn3Days = Task(
        id: '2',
        title: 'In 3 days',
        deadline: DateTime(2026, 11, 18),
      );
      expect(classifyTimeHorizon(overdue, now: now), TimeHorizon.dueSoon);
      expect(classifyTimeHorizon(dueIn3Days, now: now), TimeHorizon.dueSoon);
    });

    test('groups > 3 days into upcoming', () {
      final upcoming = Task(
        id: '3',
        title: 'Next week',
        deadline: DateTime(2026, 11, 22),
      );
      expect(classifyTimeHorizon(upcoming, now: now), TimeHorizon.upcoming);
    });

    test('groups tasks without deadline or repeat into whenever', () {
      const whenever = Task(id: '4', title: 'Organize closet');
      expect(classifyTimeHorizon(whenever, now: now), TimeHorizon.whenever);
    });
  });

  group('repeatFrequencyLabel', () {
    test('formats daily, weekly, monthly, and multi-unit rules', () {
      expect(
        repeatFrequencyLabel(
          const Task(id: '1', title: 'A', isRepeating: true, repeatRule: 'every:1:day'),
        ),
        'Daily',
      );
      expect(
        repeatFrequencyLabel(
          const Task(id: '2', title: 'B', isRepeating: true, repeatRule: 'every:1:week'),
        ),
        'Weekly',
      );
      expect(
        repeatFrequencyLabel(
          const Task(id: '3', title: 'C', isRepeating: true, repeatRule: 'every:2:month'),
        ),
        'Every 2 months',
      );
    });
  });
}
