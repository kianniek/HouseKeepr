import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../models/task.dart';
import '../utils/task_date_utils.dart';

/// Interactive workload calendar card defaulting to a compact 1-week strip
/// (expandable to a full month grid) with 0–3 workload dots per day.
class WorkloadCalendarCard extends StatelessWidget {
  final List<Task> tasks;
  final DateTime focusedDate;
  final DateTime? selectedDate;
  final bool isMonthView;
  final ValueChanged<DateTime?> onDateSelected;
  final ValueChanged<DateTime> onFocusedDateChanged;
  final ValueChanged<bool> onViewModeChanged;

  const WorkloadCalendarCard({
    super.key,
    required this.tasks,
    required this.focusedDate,
    required this.selectedDate,
    required this.isMonthView,
    required this.onDateSelected,
    required this.onFocusedDateChanged,
    required this.onViewModeChanged,
  });

  static DateTime _dateOnly(DateTime dt) {
    final l = dt.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  String _priorityLabel(TaskPriority? priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return 'Urgent priority';
      case TaskPriority.high:
        return 'High priority';
      case TaskPriority.medium:
        return 'Medium priority';
      case TaskPriority.low:
        return 'Low priority';
      case null:
        return '';
    }
  }

  String _summaryText(DateTime day, WorkloadSummary summary) {
    final datePart = DateFormat('EEE, MMM d').format(day);
    if (summary.taskCount == 0) {
      return '$datePart · No tasks scheduled';
    }
    final taskWord = summary.taskCount == 1 ? 'task' : 'tasks';
    final prio = _priorityLabel(summary.highestPriority);
    return '$datePart · ${summary.taskCount} $taskWord ($prio)';
  }

  void _stepPeriod(int delta) {
    if (isMonthView) {
      final next = DateTime(focusedDate.year, focusedDate.month + delta, 1);
      onFocusedDateChanged(next);
    } else {
      final next = DateTime(
        focusedDate.year,
        focusedDate.month,
        focusedDate.day + (7 * delta),
      );
      onFocusedDateChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = _dateOnly(DateTime.now());
    final focused = _dateOnly(focusedDate);

    final DateTime rangeStart;
    final DateTime rangeEnd;
    final List<DateTime?> cells = <DateTime?>[];

    if (!isMonthView) {
      rangeStart = focused;
      rangeEnd = DateTime(
        rangeStart.year,
        rangeStart.month,
        rangeStart.day + 6,
      );
      for (int i = 0; i < 7; i++) {
        cells.add(
          DateTime(rangeStart.year, rangeStart.month, rangeStart.day + i),
        );
      }
    } else {
      final firstOfMonth = DateTime(focused.year, focused.month, 1);
      final daysInMonth = DateUtils.getDaysInMonth(focused.year, focused.month);
      rangeStart = firstOfMonth;
      rangeEnd = DateTime(focused.year, focused.month, daysInMonth);
      final leadingBlanks = firstOfMonth.weekday - 1; // Mon=1 -> 0 blanks
      for (int b = 0; b < leadingBlanks; b++) {
        cells.add(null);
      }
      for (int d = 1; d <= daysInMonth; d++) {
        cells.add(DateTime(focused.year, focused.month, d));
      }
    }

    final workloadMap = computeCalendarWorkload(
      tasks,
      rangeStart,
      rangeEnd,
      now: today,
    );

    final summaryDay = selectedDate != null ? _dateOnly(selectedDate!) : today;
    final summaryInfo =
        workloadMap[summaryDay] ??
        computeCalendarWorkload(
          tasks,
          summaryDay,
          summaryDay,
          now: today,
        )[summaryDay] ??
        WorkloadSummary.empty;

    final monthLabel = DateFormat('MMMM yyyy').format(
      isMonthView
          ? DateTime(focused.year, focused.month, 1)
          : (selectedDate != null &&
                    !selectedDate!.isBefore(rangeStart) &&
                    !selectedDate!.isAfter(rangeEnd)
                ? selectedDate!
                : rangeStart),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Calendar Header
          Row(
            children: [
              Text(
                monthLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: isMonthView ? 'Previous month' : 'Previous week',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: scheme.onSurfaceVariant,
                onPressed: () => _stepPeriod(-1),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: isMonthView ? 'Next month' : 'Next week',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: scheme.onSurfaceVariant,
                onPressed: () => _stepPeriod(1),
              ),
              const Spacer(),
              InkWell(
                onTap: () => onViewModeChanged(!isMonthView),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMonthView
                            ? Icons.view_week_outlined
                            : Icons.calendar_month,
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMonthView ? 'Week' : 'Month',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Weekday Labels
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Row(
              key: ValueKey('weekdays_${isMonthView}_${rangeStart.weekday}'),
              children: (isMonthView
                      ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      : List.generate(
                          7,
                          (i) => DateFormat('E').format(
                            DateTime(
                              rangeStart.year,
                              rangeStart.month,
                              rangeStart.day + i,
                            ),
                          ),
                        ))
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Calendar Days Grid
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                );
              },
              child: GridView.builder(
                key: ValueKey('grid_${isMonthView}_${rangeStart.year}_${rangeStart.month}_${rangeStart.day}'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  mainAxisExtent: 44,
                ),
                itemBuilder: (context, index) {
                  final day = cells[index];
                  if (day == null) return const SizedBox.shrink();

                  final isSelected =
                      selectedDate != null && _dateOnly(selectedDate!) == day;
                  final isToday = day == today;
                  final summary = workloadMap[day] ?? WorkloadSummary.empty;
                  final dots = summary.level.dots;

                  final Color bgColor;
                  final Color textColor;
                  if (isSelected) {
                    bgColor = scheme.primaryContainer;
                    textColor = scheme.onPrimaryContainer;
                  } else if (isToday) {
                    bgColor = scheme.surfaceContainerHigh;
                    textColor = scheme.primary;
                  } else {
                    bgColor = Colors.transparent;
                    textColor = scheme.onSurface;
                  }

                  final Color dotColor;
                  if (isSelected) {
                    dotColor = scheme.onPrimaryContainer;
                  } else if (summary.level == WorkloadLevel.heavy) {
                    dotColor = scheme.tertiary;
                  } else {
                    dotColor = scheme.primary;
                  }

                  return Material(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (isSelected) {
                          onDateSelected(null);
                        } else {
                          onDateSelected(day);
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textColor,
                              fontWeight: (isSelected || isToday)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            height: 6,
                            child: dots == 0
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      dots,
                                      (i) => Container(
                                        width: 5,
                                        height: 5,
                                        margin: EdgeInsets.only(
                                          right: i < dots - 1 ? 2 : 0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: dotColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 8),

          // Footer: Selected day summary + 1-3 dot scale legend
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _summaryText(summaryDay, summaryInfo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (selectedDate != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => onDateSelected(null),
                        child: Text(
                          'Clear',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _LegendDotGroup(
                dots: 1,
                label: 'Light',
                color: scheme.primary,
                textColor: scheme.outline,
              ),
              const SizedBox(width: 8),
              _LegendDotGroup(
                dots: 2,
                label: 'Med',
                color: scheme.primary,
                textColor: scheme.outline,
              ),
              const SizedBox(width: 8),
              _LegendDotGroup(
                dots: 3,
                label: 'Heavy',
                color: scheme.tertiary,
                textColor: scheme.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDotGroup extends StatelessWidget {
  final int dots;
  final String label;
  final Color color;
  final Color textColor;

  const _LegendDotGroup({
    required this.dots,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(
          dots,
          (i) => Container(
            width: 5,
            height: 5,
            margin: EdgeInsets.only(right: i < dots - 1 ? 2 : 3),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: textColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
