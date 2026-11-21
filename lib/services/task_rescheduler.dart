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

  /// Returns unfinished tasks that are overdue (or due today when
  /// [includeToday] is `true`).
  static List<Task> getEligibleRebalanceTasks(
    List<Task> tasks, {
    DateTime? now,
    bool includeToday = true,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    return tasks.where((t) {
      if (t.archived || t.completed) return false;
      final due = effectiveDueDate(t, now: today);
      if (due == null) return false;
      final dueDay = _dateOnly(due);
      if (dueDay.isBefore(today)) return true;
      return includeToday && dueDay.isAtSameMomentAs(today);
    }).toList();
  }

  /// Computes a full rebalance preview mapping task IDs to their suggested
  /// [RescheduleSuggestion] (target date + reason).
  ///
  /// When [includeToday] is `true`, unfinished tasks due today are also
  /// eligible to be redistributed. When [keepTodayCapacity] is `true`, up to
  /// [maxDailyTasks] highest-priority tasks remain on today; when `false`, all
  /// eligible tasks are pushed to tomorrow or later.
  ///
  /// Tasks whose proposed date is already their current due date are omitted
  /// from the returned map.
  static Map<String, RescheduleSuggestion> previewRebalance(
    List<Task> allTasks, {
    DateTime? now,
    int maxDailyTasks = 4,
    Set<String>? targetTaskIds,
    bool includeToday = true,
    bool keepTodayCapacity = true,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final todayUtc = DateTime(today.year, today.month, today.day).toUtc();

    final eligible = allTasks.where((t) {
      if (t.archived || t.completed) return false;
      if (targetTaskIds != null && !targetTaskIds.contains(t.id)) return false;
      final due = effectiveDueDate(t, now: today);
      if (due == null) return false;
      final dueDay = _dateOnly(due);
      if (dueDay.isBefore(today)) return true;
      return includeToday && dueDay.isAtSameMomentAs(today);
    }).toList();

    if (eligible.isEmpty) return const {};

    // Sort highest priority first so urgent items land on today/tomorrow.
    eligible.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    final suggestions = <String, RescheduleSuggestion>{};
    final simulatedTasks = List<Task>.from(allTasks);

    // Count tasks already due today that are NOT being rebalanced so we don't
    // exceed maxDailyTasks on today.
    final eligibleIds = eligible.map((t) => t.id).toSet();
    int keptToday = keepTodayCapacity
        ? allTasks.where((t) {
            if (t.archived || t.completed) return false;
            if (eligibleIds.contains(t.id)) return false;
            final due = effectiveDueDate(t, now: today);
            return due != null && _dateOnly(due).isAtSameMomentAs(today);
          }).length
        : maxDailyTasks;

    for (final task in eligible) {
      final currentDue = effectiveDueDate(task, now: today);
      final isAlreadyToday =
          currentDue != null && _dateOnly(currentDue).isAtSameMomentAs(today);

      if (keepTodayCapacity && keptToday < maxDailyTasks) {
        keptToday++;
        if (!isAlreadyToday) {
          suggestions[task.id] = RescheduleSuggestion(
            targetDate: todayUtc,
            reason: 'Kept for today (top priority)',
            existingTaskCount: keptToday - 1,
          );
          final idx = simulatedTasks.indexWhere((t) => t.id == task.id);
          if (idx != -1) {
            simulatedTasks[idx] = task.copyWith(
              deadline: todayUtc,
              inactiveUntil: task.isRepeating ? todayUtc : null,
            );
          }
        }
        continue;
      }

      final suggestion = suggestBestDate(
        task,
        simulatedTasks,
        now: today,
        minOffsetDays: 1,
      );
      suggestions[task.id] = suggestion;

      // Update simulated list so subsequent tasks see the newly assigned load.
      final idx = simulatedTasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        simulatedTasks[idx] = task.copyWith(
          deadline: suggestion.targetDate,
          inactiveUntil: task.isRepeating ? suggestion.targetDate : null,
        );
      }
    }

    return suggestions;
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
    final preview = previewRebalance(
      allTasks,
      now: now,
      maxDailyTasks: maxDailyTasks,
      targetTaskIds: targetTaskIds,
      includeToday: false,
      keepTodayCapacity: true,
    );
    return preview.map((id, s) => MapEntry(id, s.targetDate));
  }
}
