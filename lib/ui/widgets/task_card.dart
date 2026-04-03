import 'package:flutter/material.dart';
import '../../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final IconData icon;
  final bool isCompleted;
  final Widget subtitle;
  final VoidCallback onToggleComplete;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool enableDismiss;
  final bool isRetrying;
  final EdgeInsetsGeometry margin;
  final double? elevation;
  final Color? color;
  final bool? isThreeLine;

  const TaskCard({
    super.key,
    required this.task,
    required this.icon,
    required this.isCompleted,
    required this.subtitle,
    required this.onToggleComplete,
    this.onLongPress,
    this.onDelete,
    this.enableDismiss = false,
    this.isRetrying = false,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.elevation,
    this.color,
    this.isThreeLine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final card = Card(
      margin: margin,
      color: color ?? scheme.surfaceContainerHighest,
      elevation: elevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onLongPress: onLongPress,
        isThreeLine: isThreeLine,
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24),
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: subtitle,
        trailing: GestureDetector(
          onTap: onToggleComplete,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? scheme.primary : scheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCompleted ? scheme.primary : scheme.outlineVariant,
                width: 2,
              ),
            ),
            child: isCompleted
                ? Icon(Icons.check, color: scheme.onPrimary, size: 20)
                : null,
          ),
        ),
      ),
    );

    if (!enableDismiss || onDelete == null) return card;

    return Dismissible(
      key: ValueKey('dismiss_${task.id}'),
      direction:
          isRetrying ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Icon(Icons.delete, color: scheme.onError),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: card,
    );
  }
}
