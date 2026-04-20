import 'package:flutter/material.dart';
import '../../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final IconData icon;
  final bool isCompleted;
  final Widget subtitle;
  final VoidCallback onToggleComplete;
  final VoidCallback? onPutOff;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool enableDismiss;
  final bool isRetrying;
  final EdgeInsetsGeometry margin;
  final double? elevation;
  final Color? color;
  final bool? isThreeLine;
  final bool isInactive;
  final String putOffLabel;
  final IconData putOffIcon;
  final bool showDoneAction;

  const TaskCard({
    super.key,
    required this.task,
    required this.icon,
    required this.isCompleted,
    required this.subtitle,
    required this.onToggleComplete,
    this.onPutOff,
    this.onLongPress,
    this.onDelete,
    this.enableDismiss = false,
    this.isRetrying = false,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.elevation,
    this.color,
    this.isThreeLine,
    this.isInactive = false,
    this.putOffLabel = 'Put Off',
    this.putOffIcon = Icons.schedule,
    this.showDoneAction = true,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      subtitle,
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(
                  builder: (context) {
                    if (!showDoneAction) {
                      return const SizedBox.shrink();
                    }
                    return Expanded(
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text(
                            'Done',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: isInactive || isRetrying
                              ? null
                              : onToggleComplete,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      icon: Icon(putOffIcon, size: 16),
                      label: Text(
                        putOffLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: isRetrying ? null : onPutOff,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final cardWithGesture = GestureDetector(
      onLongPress: onLongPress,
      child: card,
    );

    if (!enableDismiss || onDelete == null) return cardWithGesture;

    return Dismissible(
      key: ValueKey('dismiss_${task.id}'),
      direction: isRetrying
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Icon(Icons.delete, color: scheme.onError),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: cardWithGesture,
    );
  }
}
