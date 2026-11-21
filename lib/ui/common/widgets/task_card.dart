import 'package:flutter/material.dart';

import '../../../models/task.dart';
import '../../../services/app_haptics.dart';
import '../../features/tasks/utils/task_date_utils.dart';
import '../app_theme.dart';
import 'assignee_avatar.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final IconData icon;
  final bool isCompleted;
  final Widget subtitle;
  final VoidCallback onToggleComplete;
  final VoidCallback? onTap;
  final VoidCallback? onSnooze;
  final VoidCallback? onLongPress;
  final bool enableSnooze;
  final bool isRetrying;
  final EdgeInsetsGeometry margin;
  final double? elevation;
  final Color? color;
  final bool isInactive;

  const TaskCard({
    super.key,
    required this.task,
    required this.icon,
    required this.isCompleted,
    required this.subtitle,
    required this.onToggleComplete,
    this.onTap,
    this.onSnooze,
    this.onLongPress,
    this.enableSnooze = false,
    this.isRetrying = false,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.elevation,
    this.color,
    this.isInactive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayTitle = sanitizeTaskTitle(task.title);

    final card = Card(
      margin: margin,
      color: color ?? scheme.surfaceContainerLow,
      elevation: elevation ?? 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left-aligned circular checkbox matching ShoppingListItemTile (#5)
              Semantics(
                button: true,
                checked: isCompleted,
                label: isCompleted ? 'Mark incomplete' : 'Mark complete',
                child: InkResponse(
                  onTap: (isInactive || isRetrying) ? null : onToggleComplete,
                  radius: 24,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted
                                ? scheme.primary
                                : scheme.outline,
                            width: 2,
                          ),
                          color: isCompleted ? scheme.primary : scheme.surface,
                        ),
                        child: isCompleted
                            ? Icon(
                                Icons.check,
                                color: scheme.onPrimary,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Room/category icon (#4)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              // Compact 2-line content: title + single muted metadata line (#4)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayTitle,
                      softWrap: true,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: isCompleted
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    subtitle,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Top-right compact assignee avatar / household badge (#4)
              _buildAssigneeBadge(context),
            ],
          ),
        ),
      ),
    );

    if (!enableSnooze || onSnooze == null || isCompleted) {
      return card;
    }

    final semantic = AppSemanticColors.of(context);
    final snoozeBg = semantic.warningContainer;
    final snoozeFg = semantic.onWarningContainer;

    return Dismissible(
      key: ValueKey('dismiss_${task.id}'),
      direction: isRetrying
          ? DismissDirection.none
          : DismissDirection.endToStart,
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          AppHaptics.instance.gestureStart();
        }
      },
      confirmDismiss: (_) async {
        onSnooze?.call();
        return false;
      },
      background: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: snoozeBg,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Snooze',
              style: theme.textTheme.labelLarge?.copyWith(
                color: snoozeFg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.snooze, color: snoozeFg),
          ],
        ),
      ),
      child: card,
    );
  }

  Widget _buildAssigneeBadge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (task.isHouseholdTask) {
      return Tooltip(
        message: 'Household',
        child: CircleAvatar(
          radius: 13,
          backgroundColor: scheme.surfaceContainerHighest,
          child: Icon(
            Icons.group_outlined,
            size: 15,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (task.assignedToId != null || task.assignedToName != null) {
      return AssigneeAvatar(
        userId: task.assignedToId,
        displayName: task.assignedToName,
        radius: 13,
      );
    }
    return const SizedBox.shrink();
  }
}
