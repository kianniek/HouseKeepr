import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/services/task_rescheduler.dart';

void main() {
  // Monday, 2026-11-16
  final monday = DateTime(2026, 11, 16);

  Task makeTask({
    required String id,
    DateTime? deadline,
    TaskPriority priority = TaskPriority.medium,
    String? room,
    int putOffCount = 0,
    bool isRepeating = false,
    String? repeatRule,
    bool completed = false,
    bool archived = false,
  }) {
    return Task(
      id: id,
      title: 'Task $id',
      deadline: deadline,
      priority: priority,
      room: room,
      putOffCount: putOffCount,
      isRepeating: isRepeating,
      repeatRule: repeatRule,
      completed: completed,
      archived: archived,
    );
  }

  group('TaskRescheduler.computeFlexibilityWindow', () {
    test('returns 2 for tasks due today or overdue', () {
      final dueToday = makeTask(id: '1', deadline: monday);
      final overdue = makeTask(
        id: '2',
        deadline: monday.subtract(const Duration(days: 3)),
      );

      expect(
        TaskRescheduler.computeFlexibilityWindow(dueToday, now: monday),
        2,
      );
      expect(
        TaskRescheduler.computeFlexibilityWindow(overdue, now: monday),
        2,
      );
    });

    test('scales proportionally with horizon and clamps to 14', () {
      final in6Days = makeTask(
        id: '1',
        deadline: monday.add(const Duration(days: 6)),
      );
      final in30Days = makeTask(
        id: '2',
        deadline: monday.add(const Duration(days: 30)),
      );
      final whenever = makeTask(id: '3', deadline: null);

      expect(
        TaskRescheduler.computeFlexibilityWindow(in6Days, now: monday),
        5,
      );
      expect(
        TaskRescheduler.computeFlexibilityWindow(in30Days, now: monday),
        14,
      );
      expect(
        TaskRescheduler.computeFlexibilityWindow(whenever, now: monday),
        14,
      );
    });

    test('decays window as putOffCount increases with floor of 1', () {
      final in10DaysFresh = makeTask(
        id: '1',
        deadline: monday.add(const Duration(days: 10)),
        putOffCount: 0,
      ); // baseWindow = 2 + 5 = 7
      final snoozedTwice = in10DaysFresh.copyWith(putOffCount: 2);
      final snoozedMany = in10DaysFresh.copyWith(putOffCount: 20);

      expect(
        TaskRescheduler.computeFlexibilityWindow(in10DaysFresh, now: monday),
        7,
      );
      // 7 * 0.75^2 = 3.9375 -> 3
      expect(
        TaskRescheduler.computeFlexibilityWindow(snoozedTwice, now: monday),
        3,
      );
      expect(
        TaskRescheduler.computeFlexibilityWindow(snoozedMany, now: monday),
        1,
      );
    });
  });

  group('TaskRescheduler.suggestBestDate', () {
    test('picks the lightest day within the flexibility window', () {
      final target = makeTask(
        id: 'target',
        deadline: monday.add(const Duration(days: 4)),
      ); // window = 4
      final tuesday = monday.add(const Duration(days: 1));
      final wednesday = monday.add(const Duration(days: 2));

      final tasks = [
        target,
        makeTask(id: 'a', deadline: tuesday, priority: TaskPriority.urgent),
        makeTask(id: 'b', deadline: tuesday, priority: TaskPriority.high),
      ];

      final suggestion = TaskRescheduler.suggestBestDate(
        target,
        tasks,
        now: monday,
      );

      expect(suggestion.targetDate.toLocal(), wednesday);
      expect(suggestion.existingTaskCount, 0);
      expect(suggestion.reason, 'Free day with no other tasks');
    });

    test('applies same-room batching bonus when loads are equal', () {
      final target = makeTask(
        id: 'target',
        deadline: monday.add(const Duration(days: 4)),
        room: 'Kitchen',
        priority: TaskPriority.high, // disable weekend bonus
      );
      final tuesday = monday.add(const Duration(days: 1));
      final wednesday = monday.add(const Duration(days: 2));
      final thursday = monday.add(const Duration(days: 3));
      final friday = monday.add(const Duration(days: 4));

      // Tuesday & Thursday have 1 Bathroom task (load=1.0),
      // Wednesday has 1 Kitchen task (load=1.0 - 0.5 room bonus = 0.5),
      // Friday is empty? Wait: empty day has load=0.0, so make Friday heavy too.
      final tasks = [
        target,
        makeTask(
          id: 'a',
          deadline: tuesday,
          room: 'Bathroom',
          priority: TaskPriority.low,
        ),
        makeTask(
          id: 'b',
          deadline: wednesday,
          room: 'Kitchen',
          priority: TaskPriority.low,
        ),
        makeTask(
          id: 'c',
          deadline: thursday,
          room: 'Bathroom',
          priority: TaskPriority.low,
        ),
        makeTask(
          id: 'd',
          deadline: friday,
          room: 'Bathroom',
          priority: TaskPriority.urgent,
        ),
      ];

      final suggestion = TaskRescheduler.suggestBestDate(
        target,
        tasks,
        now: monday,
      );

      // Tuesday: 1.0 + 0.15 = 1.15
      // Wednesday: 1.0 - 0.5 + 0.30 = 0.80 (best!)
      expect(suggestion.targetDate.toLocal(), wednesday);
      expect(suggestion.existingTaskCount, 1);
    });

    test('clamps repeating tasks before next natural cycle', () {
      final repeating = makeTask(
        id: 'rep',
        deadline: monday,
        isRepeating: true,
        repeatRule: 'every:2:day',
      );
      final tuesday = monday.add(const Duration(days: 1));
      final wednesday = monday.add(const Duration(days: 2));

      // Even if Tuesday is loaded, hardCeiling is cycleDays - 1 = 1 day (Tuesday),
      // so it must not push to Wednesday.
      final tasks = [
        repeating,
        makeTask(id: 'heavy', deadline: tuesday, priority: TaskPriority.urgent),
      ];

      final suggestion = TaskRescheduler.suggestBestDate(
        repeating,
        tasks,
        now: monday,
      );

      expect(suggestion.targetDate.toLocal(), tuesday);
      expect(suggestion.targetDate.toLocal().isBefore(wednesday), isTrue);
    });
  });

  group('TaskRescheduler.rebalanceOverduePileup', () {
    test('keeps up to maxDailyTasks on today (highest priority first) and spreads overflow', () {
      final yesterday = monday.subtract(const Duration(days: 1));
      final twoDaysAgo = monday.subtract(const Duration(days: 2));

      final tasks = [
        makeTask(id: 'low1', deadline: twoDaysAgo, priority: TaskPriority.low),
        makeTask(id: 'low2', deadline: yesterday, priority: TaskPriority.low),
        makeTask(
          id: 'urgent1',
          deadline: twoDaysAgo,
          priority: TaskPriority.urgent,
        ),
        makeTask(id: 'high1', deadline: yesterday, priority: TaskPriority.high),
        makeTask(
          id: 'med1',
          deadline: yesterday,
          priority: TaskPriority.medium,
        ),
      ];

      final updates = TaskRescheduler.rebalanceOverduePileup(
        tasks,
        now: monday,
        maxDailyTasks: 2,
      );

      expect(updates.length, 5);
      // Urgent and High stay on today (Monday)
      expect(updates['urgent1']?.toLocal(), monday);
      expect(updates['high1']?.toLocal(), monday);

      // Overflow tasks are pushed to Tuesday / Wednesday (not today)
      final tuesday = monday.add(const Duration(days: 1));
      final wednesday = monday.add(const Duration(days: 2));
      expect(updates['med1']?.toLocal(), tuesday);
      expect(updates['low1']?.toLocal(), wednesday);
      // low2 should land on Tuesday or Wednesday depending on load, not Monday
      expect(updates['low2']?.toLocal().isAfter(monday), isTrue);
    });
  });

  group('TaskRescheduler.previewRebalance', () {
    test('includes today tasks and omits tasks that stay on today', () {
      final yesterday = monday.subtract(const Duration(days: 1));
      final tasks = [
        makeTask(id: 'over1', deadline: yesterday, priority: TaskPriority.urgent),
        makeTask(id: 'today1', deadline: monday, priority: TaskPriority.high),
        makeTask(id: 'today2', deadline: monday, priority: TaskPriority.low),
      ];

      final preview = TaskRescheduler.previewRebalance(
        tasks,
        now: monday,
        maxDailyTasks: 2,
        includeToday: true,
        keepTodayCapacity: true,
      );

      // urgent overdue moves to today; high due-today stays on today (omitted);
      // low due-today overflows to tomorrow.
      expect(preview.containsKey('today1'), isFalse);
      expect(preview['over1']?.targetDate.toLocal(), monday);
      expect(preview['today2']?.targetDate.toLocal().isAfter(monday), isTrue);
    });

    test('pushes all eligible tasks to future days when keepTodayCapacity is false', () {
      final yesterday = monday.subtract(const Duration(days: 1));
      final tasks = [
        makeTask(id: 'over1', deadline: yesterday, priority: TaskPriority.urgent),
        makeTask(id: 'today1', deadline: monday, priority: TaskPriority.high),
      ];

      final preview = TaskRescheduler.previewRebalance(
        tasks,
        now: monday,
        includeToday: true,
        keepTodayCapacity: false,
      );

      expect(preview.length, 2);
      expect(preview['over1']?.targetDate.toLocal().isAfter(monday), isTrue);
      expect(preview['today1']?.targetDate.toLocal().isAfter(monday), isTrue);
    });

    test('getEligibleRebalanceTasks returns overdue and due-today unfinished tasks', () {
      final yesterday = monday.subtract(const Duration(days: 1));
      final tomorrow = monday.add(const Duration(days: 1));
      final tasks = [
        makeTask(id: 'over', deadline: yesterday),
        makeTask(id: 'today', deadline: monday),
        makeTask(id: 'tomorrow', deadline: tomorrow),
        makeTask(id: 'done', deadline: yesterday, completed: true),
      ];

      final eligible = TaskRescheduler.getEligibleRebalanceTasks(tasks, now: monday);
      expect(eligible.map((t) => t.id), ['over', 'today']);
    });
  });
}

