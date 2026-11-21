import '../../../../models/task.dart';

/// Urgency-based time horizons for grouping tasks (#6).
enum TimeHorizon { dueSoon, upcoming, whenever }

/// Strips trailing periods and outer whitespace from a task title (#8).
String sanitizeTaskTitle(String raw) {
  return raw.trim().replaceAll(RegExp(r'\.+$'), '').trim();
}

/// Returns a local date-only [DateTime] (midnight) for day-level comparisons.
DateTime _dateOnly(DateTime dt) {
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Returns whether [date] is strictly before today (local calendar day).
bool isOverdue(DateTime date, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final target = _dateOnly(date);
  return target.isBefore(today);
}

/// Formats [date] as a humanized relative label (#6):
/// `Today`, `Tomorrow`, `In X days`, `1 day overdue`, `X days overdue`.
String formatRelativeDueDate(DateTime date, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final target = _dateOnly(date);
  final diff = target.difference(today).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff > 1) return 'In $diff days';
  final overdueDays = -diff;
  if (overdueDays == 1) return '1 day overdue';
  return '$overdueDays days overdue';
}

/// Parsed repeat rule with a positive [interval] and normalized [unit]
/// (`'day'`, `'week'`, or `'month'`).
({int interval, String unit}) parseRepeatRule(String? rawRule) {
  final raw = (rawRule ?? '').toLowerCase().trim();
  int interval = 1;
  String unit = 'day';
  if (raw.startsWith('every:')) {
    final parts = raw.split(':');
    if (parts.length >= 3) {
      interval = (int.tryParse(parts[1]) ?? 1).clamp(1, 3650);
      unit = parts[2];
    }
  } else if (raw == 'weekly' || raw == 'week') {
    unit = 'week';
  } else if (raw == 'monthly' || raw == 'month') {
    unit = 'month';
  }
  return (interval: interval, unit: unit);
}

/// Computes the next occurrence for a repeating [task] on or after today,
/// or returns `task.deadline` for non-repeating tasks.
DateTime? effectiveDueDate(Task task, {DateTime? now}) {
  final refNow = (now ?? DateTime.now()).toUtc();
  if (!task.isRepeating) return task.deadline;

  if (task.inactiveUntil != null && refNow.isBefore(task.inactiveUntil!)) {
    return task.inactiveUntil;
  }

  final (:interval, :unit) = parseRepeatRule(task.repeatRule);

  final deadline = (task.deadline ?? refNow).toUtc();
  final startDate = DateTime.utc(deadline.year, deadline.month, deadline.day);
  final today = DateTime.utc(refNow.year, refNow.month, refNow.day);
  final todayStr = today.toIso8601String().split('T')[0];
  final completedToday = (task.completedDates ?? []).contains(todayStr);

  if (unit == 'day') {
    final diffDays = today.difference(startDate).inDays;
    if (diffDays < 0) return startDate;
    final remainder = diffDays % interval;
    final offset = remainder == 0 ? 0 : interval - remainder;
    final candidate = today.add(Duration(days: offset));
    if (completedToday && candidate.isAtSameMomentAs(today)) {
      return candidate.add(Duration(days: interval));
    }
    return candidate;
  }

  if (unit == 'week') {
    final days = (task.repeatDays?.isNotEmpty ?? false)
        ? task.repeatDays!
        : <int>[startDate.weekday];
    for (int offset = 0; offset <= 366; offset++) {
      final check = today.add(Duration(days: offset));
      if (completedToday && offset == 0) continue;
      if (!days.contains(check.weekday)) continue;
      final diff = check.difference(startDate).inDays;
      if (diff < 0) continue;
      final weekIndex = diff ~/ 7;
      if (weekIndex % interval != 0) continue;
      return check;
    }
    return task.deadline;
  }

  if (unit == 'month') {
    final days = (task.repeatDays?.isNotEmpty ?? false)
        ? task.repeatDays!
        : <int>[startDate.day];
    for (int m = 0; m <= 24; m++) {
      final monthCandidate = DateTime.utc(today.year, today.month + m, 1);
      final monthDiff =
          (monthCandidate.year - startDate.year) * 12 +
          (monthCandidate.month - startDate.month);
      if (monthDiff < 0 || monthDiff % interval != 0) continue;
      for (final d in days) {
        try {
          final candidate = DateTime.utc(
            monthCandidate.year,
            monthCandidate.month,
            d,
          );
          if (completedToday && candidate.isAtSameMomentAs(today)) continue;
          if (!candidate.isBefore(today)) return candidate;
        } catch (_) {}
      }
    }
  }

  return task.deadline;
}

/// Classifies an incomplete [task] into [TimeHorizon.dueSoon],
/// [TimeHorizon.upcoming], or [TimeHorizon.whenever].
TimeHorizon classifyTimeHorizon(Task task, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final due = effectiveDueDate(task, now: ref);
  if (due == null) return TimeHorizon.whenever;

  final diffDays = _dateOnly(due).difference(_dateOnly(ref)).inDays;
  if (diffDays <= 3) return TimeHorizon.dueSoon;
  return TimeHorizon.upcoming;
}

/// Returns a concise recurrence label (e.g. `Daily`, `Weekly`, `Monthly`).
String repeatFrequencyLabel(Task task) {
  if (!task.isRepeating) return '';
  final (:interval, :unit) = parseRepeatRule(task.repeatRule);

  if (interval == 1) {
    switch (unit) {
      case 'day':
        return 'Daily';
      case 'week':
        return 'Weekly';
      case 'month':
        return 'Monthly';
    }
  }
  final plural = unit == 'day'
      ? 'days'
      : unit == 'week'
      ? 'weeks'
      : 'months';
  return 'Every $interval $plural';
}

/// Daily workload intensity represented by 0–3 dots on the calendar.
enum WorkloadLevel {
  none(0),
  light(1),
  moderate(2),
  heavy(3);

  final int dots;
  const WorkloadLevel(this.dots);
}

/// Aggregated workload metrics for a single calendar day.
class WorkloadSummary {
  final int taskCount;
  final int totalWeight;
  final TaskPriority? highestPriority;
  final WorkloadLevel level;

  const WorkloadSummary({
    required this.taskCount,
    required this.totalWeight,
    required this.highestPriority,
    required this.level,
  });

  static const empty = WorkloadSummary(
    taskCount: 0,
    totalWeight: 0,
    highestPriority: null,
    level: WorkloadLevel.none,
  );
}

/// Cognitive/effort weight for a task priority (aligned with TaskRescheduler).
int taskPriorityWeight(TaskPriority priority) {
  switch (priority) {
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

/// Formats a local calendar day as `YYYY-MM-DD` matching `completedDates`.
String toIsoDateString(DateTime localDay) {
  final y = localDay.year.toString().padLeft(4, '0');
  final m = localDay.month.toString().padLeft(2, '0');
  final d = localDay.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Returns whether [task] is completed for [localDay].
bool isTaskCompletedOnDate(Task task, DateTime localDay) {
  if (task.isRepeating) {
    return (task.completedDates ?? const []).contains(toIsoDateString(localDay));
  }
  return task.completed;
}

/// Returns whether [task] is scheduled to occur on [localDay] (local date).
bool doesTaskOccurOnDate(Task task, DateTime localDay, {DateTime? now}) {
  final target = _dateOnly(localDay);

  if (!task.isRepeating) {
    if (task.deadline == null) return false;
    return _dateOnly(task.deadline!) == target;
  }

  final refNow = now ?? DateTime.now();
  final startDate = _dateOnly(task.deadline ?? refNow);
  if (target.isBefore(startDate)) return false;

  if (task.inactiveUntil != null) {
    final inactiveDay = _dateOnly(task.inactiveUntil!);
    if (target.isBefore(inactiveDay)) return false;
  }

  final (:interval, :unit) = parseRepeatRule(task.repeatRule);

  if (unit == 'day') {
    final diffDays = target.difference(startDate).inDays;
    return diffDays >= 0 && diffDays % interval == 0;
  }

  if (unit == 'week') {
    final days = (task.repeatDays?.isNotEmpty ?? false)
        ? task.repeatDays!
        : <int>[startDate.weekday];
    if (!days.contains(target.weekday)) return false;
    final startMonday = startDate.subtract(Duration(days: startDate.weekday - 1));
    final targetMonday = target.subtract(Duration(days: target.weekday - 1));
    final weekDiff = targetMonday.difference(startMonday).inDays ~/ 7;
    return weekDiff >= 0 && weekDiff % interval == 0;
  }

  if (unit == 'month') {
    final days = (task.repeatDays?.isNotEmpty ?? false)
        ? task.repeatDays!
        : <int>[startDate.day];
    final monthDiff =
        (target.year - startDate.year) * 12 + (target.month - startDate.month);
    if (monthDiff < 0 || monthDiff % interval != 0) return false;
    return days.contains(target.day);
  }

  return false;
}

/// Computes daily workload summaries for every local day in `[rangeStart, rangeEnd]`.
Map<DateTime, WorkloadSummary> computeCalendarWorkload(
  List<Task> tasks,
  DateTime rangeStart,
  DateTime rangeEnd, {
  DateTime? now,
}) {
  final start = _dateOnly(rangeStart);
  final end = _dateOnly(rangeEnd);
  final result = <DateTime, WorkloadSummary>{};

  for (
    var day = start;
    !day.isAfter(end);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    int count = 0;
    int weight = 0;
    TaskPriority? highest;

    for (final t in tasks) {
      if (t.archived) continue;
      if (isTaskCompletedOnDate(t, day)) continue;
      if (!doesTaskOccurOnDate(t, day, now: now)) continue;

      count++;
      weight += taskPriorityWeight(t.priority);
      if (highest == null || t.priority.index > highest.index) {
        highest = t.priority;
      }
    }

    final WorkloadLevel level;
    if (count == 0) {
      level = WorkloadLevel.none;
    } else if (weight <= 3) {
      level = WorkloadLevel.light;
    } else if (weight <= 7) {
      level = WorkloadLevel.moderate;
    } else {
      level = WorkloadLevel.heavy;
    }

    result[day] = WorkloadSummary(
      taskCount: count,
      totalWeight: weight,
      highestPriority: highest,
      level: level,
    );
  }

  return result;
}
