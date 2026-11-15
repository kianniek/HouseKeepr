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
