import '../models/task.dart';

/// Generate occurrence dates for a repeating [Task] within [from]..[to].
/// Returns a list of DateTime (UTC) representing each occurrence's deadline.
///
/// Supported simple rules:
/// - 'daily' : every day
/// - 'weekly': weekly on specified weekdays via `repeatDays` (1..7)
/// - 'monthly': monthly on specified month-days via `repeatDays` (1..31)
///
List<DateTime> generateOccurrencesForTask(
  Task t,
  DateTime from,
  DateTime to, {
  int interval = 1,
}) {
  final out = <DateTime>[];
  if (!t.isRepeating) return out;

  // Determine start date: use task.deadline if set else today.
  final start = (t.deadline ?? DateTime.now()).toUtc();

  final windowStart = from.toUtc();
  final windowEnd = to.toUtc();

  // rule string
  final rawRule = (t.repeatRule ?? '').toLowerCase().trim();
  var unit = rawRule;
  var ruleInterval = interval;
  if (rawRule.startsWith('every:')) {
    final parts = rawRule.split(':');
    if (parts.length >= 3) {
      ruleInterval = int.tryParse(parts[1]) ?? interval;
      unit = parts[2];
    }
  }
  if (ruleInterval < 1) ruleInterval = 1;

  if (unit == 'daily' || unit == 'day' || unit.isEmpty) {
    // step by interval days
    DateTime cur = DateTime.utc(
      windowStart.year,
      windowStart.month,
      windowStart.day,
    );
    // ensure we don't start before the task's start
    if (cur.isBefore(start)) {
      cur = DateTime.utc(start.year, start.month, start.day);
    }
    while (!cur.isAfter(windowEnd)) {
      out.add(cur);
      cur = cur.add(Duration(days: ruleInterval));
    }
    return out;
  }

  if (unit == 'weekly' || unit == 'week') {
    final days = (t.repeatDays == null || t.repeatDays!.isEmpty)
        ? [start.weekday]
        : t.repeatDays!;

    // Walk through weeks by interval
    var weekStart = DateTime.utc(
      windowStart.year,
      windowStart.month,
      windowStart.day,
    );
    // align weekStart to the task start's week if task starts later
    if (weekStart.isBefore(start)) {
      weekStart = DateTime.utc(start.year, start.month, start.day);
    }

    // iterate week blocks
    while (!weekStart.isAfter(windowEnd)) {
      for (final wd in days) {
        // find the date in this week with weekday wd
        final candidate = weekStart.add(
          Duration(days: (wd - weekStart.weekday)),
        );
        // adjust if negative/positive offset
        final date = DateTime.utc(
          candidate.year,
          candidate.month,
          candidate.day,
        );
        if (!date.isBefore(windowStart) &&
            !date.isAfter(windowEnd) &&
            !date.isBefore(start)) {
          out.add(date);
        }
      }
      weekStart = weekStart.add(Duration(days: 7 * ruleInterval));
    }
    return out;
  }

  if (unit == 'monthly' || unit == 'month') {
    // repeatDays used as month day numbers (1..31). If absent, use start.day
    final days = (t.repeatDays == null || t.repeatDays!.isEmpty)
        ? [start.day]
        : t.repeatDays!;

    var cur = DateTime.utc(windowStart.year, windowStart.month, 1);
    if (cur.isBefore(start)) cur = DateTime.utc(start.year, start.month, 1);
    while (!cur.isAfter(windowEnd)) {
      for (final md in days) {
        try {
          final candidate = DateTime.utc(cur.year, cur.month, md);
          if (!candidate.isBefore(windowStart) &&
              !candidate.isAfter(windowEnd) &&
              !candidate.isBefore(start)) {
            out.add(candidate);
          }
        } catch (_) {
          // invalid day for month (e.g., Feb 30) -> skip
        }
      }
      // advance by interval months
      cur = DateTime.utc(cur.year, cur.month + ruleInterval, 1);
    }
    return out;
  }

  // Unknown rule: no occurrences
  return out;
}
