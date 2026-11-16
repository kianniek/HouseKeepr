import 'dart:math';

import '../models/task.dart';
import '../ui/features/tasks/utils/task_date_utils.dart';

/// Suggested reschedule target returned by [TaskRescheduler.suggestBestDate].
class RescheduleSuggestion {
  final DateTime targetDate;
  final String reason;
  final int existingTaskCount;

  const RescheduleSuggestion({
    required this.targetDate,
    required this.reason,
    required this.existingTaskCount,
  });
}

/// Pure scheduling service implementing load-balanced rescheduling,
/// horizon-proportional flexibility, anti-procrastination decay, and
/// recurrence collision guarding.
class TaskRescheduler {
  static DateTime _dateOnly(DateTime dt) {
    final l = dt.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  static int _priorityWeight(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return 1;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.high:
        return 3;
      case TaskPriority.urgent:
        return 4;
    }
  }

  /// Computes the allowed day-shift window based on distance from today
  /// and how many times the task has already been put off.
  static int computeFlexibilityWindow(Task task, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final due = effectiveDueDate(task, now: today);

    // Tasks with no due date ("Whenever") have maximum flexibility.
    if (due == null) return 14;

    final distanceFromToday = max(0, _dateOnly(due).difference(today).inDays);
    final baseWindow = (2 + (distanceFromToday * 0.5).floor()).clamp(2, 14);

    // Dampen window if the user keeps snoozing this task.
    final decay = pow(0.75, task.putOffCount);
    return max(1, (baseWindow * decay).floor());
  }

  /// Finds the least-overwhelming day within the task's flexibility window.
  static RescheduleSuggestion suggestBestDate(
    Task targetTask,
    List<Task> allTasks, {
    DateTime? now,
    int minOffsetDays = 1,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final window = computeFlexibilityWindow(targetTask, now: today);
    final maxOffset = max(minOffsetDays, window);

    // Build a map of daily cognitive/effort load across active tasks.
    final dailyWeight = <DateTime, double>{};
    final dailyCount = <DateTime, int>{};
    final dailyRooms = <DateTime, Set<String>>{};

    for (final t in allTasks) {
      if (t.id == targetTask.id || t.archived || t.completed) continue;
      final d = effectiveDueDate(t, now: today);
      if (d == null) continue;
      final day = _dateOnly(d);

      dailyWeight[day] = (dailyWeight[day] ?? 0) + _priorityWeight(t.priority);
      dailyCount[day] = (dailyCount[day] ?? 0) + 1;
      if (t.room != null && t.room!.isNotEmpty) {
        dailyRooms.putIfAbsent(day, () => <String>{}).add(t.room!);
      }
    }

    // Prevent repeating tasks from colliding with their next natural cycle.
    DateTime? hardCeiling;
    if (targetTask.isRepeating) {
      final (:interval, :unit) = parseRepeatRule(targetTask.repeatRule);
      final cycleDays = unit == 'month'
          ? interval * 28
          : (unit == 'week' ? interval * 7 : interval);
      if (cycleDays > 1) {
        hardCeiling = today.add(Duration(days: cycleDays - 1));
      }
    }

    DateTime bestDay = today.add(Duration(days: minOffsetDays));
    double bestScore = double.infinity;

    for (int offset = minOffsetDays; offset <= maxOffset; offset++) {
      final candidate = today.add(Duration(days: offset));
      if (hardCeiling != null && candidate.isAfter(hardCeiling)) break;

      final load = dailyWeight[candidate] ?? 0.0;

      // Slight preference (0.5 discount) for batching tasks in the same room.
      final sameRoomBonus =
          (targetTask.room != null &&
              (dailyRooms[candidate]?.contains(targetTask.room) ?? false))
          ? -0.5
          : 0.0;

      // Gentle bias toward earlier days when loads are tied so tasks don't drift unnecessarily.
      final distancePenalty = offset * 0.15;

      // Slight weekend preference for lower-priority tasks (<= medium).
      final isWeekend =
          candidate.weekday == DateTime.saturday ||
          candidate.weekday == DateTime.sunday;
      final weekendBonus =
          (isWeekend && targetTask.priority.index <= TaskPriority.medium.index)
          ? -0.3
          : 0.0;

      final score = load + sameRoomBonus + distancePenalty + weekendBonus;

      if (score < bestScore) {
        bestScore = score;
        bestDay = candidate;
      }
    }

    final count = dailyCount[bestDay] ?? 0;
    final reason = count == 0
        ? 'Free day with no other tasks'
        : 'Lightest load ($count ${count == 1 ? 'task' : 'tasks'} scheduled)';

    return RescheduleSuggestion(
      targetDate: DateTime(bestDay.year, bestDay.month, bestDay.day).toUtc(),
      reason: reason,
      existingTaskCount: count,
    );
  }

  /// Automatically spreads out a backlog of overdue tasks across upcoming days
  /// so the user isn't greeted by a wall of overdue badges.
  ///
  /// When [targetTaskIds] is provided, only overdue tasks whose IDs are in
  /// that set are rescheduled, while all active tasks in [allTasks] still
  /// contribute to daily load calculations.
  static Map<String, DateTime> rebalanceOverduePileup(
    List<Task> allTasks, {
    DateTime? now,
    int maxDailyTasks = 4,
    Set<String>? targetTaskIds,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final overdue = allTasks.where((t) {
      if (t.archived || t.completed) return false;
      if (targetTaskIds != null && !targetTaskIds.contains(t.id)) return false;
      final due = effectiveDueDate(t, now: today);
      return due != null && isOverdue(due, now: today);
    }).toList();

    // Sort highest priority first so urgent items land on today/tomorrow.
    overdue.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    final updates = <String, DateTime>{};
    final simulatedTasks = List<Task>.from(allTasks);

    // Keep up to `maxDailyTasks` on today; spread the overflow forward.
    int keptToday = allTasks.where((t) {
      if (t.archived || t.completed) return false;
      final due = effectiveDueDate(t, now: today);
      return due != null && _dateOnly(due).isAtSameMomentAs(today);
    }).length;

    for (final task in overdue) {
      if (keptToday < maxDailyTasks) {
        updates[task.id] = DateTime(today.year, today.month, today.day).toUtc();
        keptToday++;
        continue;
      }

      final suggestion = suggestBestDate(
        task,
        simulatedTasks,
        now: today,
        minOffsetDays: 1,
      );
      updates[task.id] = suggestion.targetDate;

      // Update simulated list so subsequent overdue tasks see the newly assigned load.
      final idx = simulatedTasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        simulatedTasks[idx] = task.copyWith(
          deadline: suggestion.targetDate,
          inactiveUntil: task.isRepeating ? suggestion.targetDate : null,
        );
      }
    }

    return updates;
  }
}

