import 'package:flutter/material.dart';

/// Displays a floating bottom pill toast with optional Undo action, matching
/// `Plan/plan_routines_swipe_duplicate.png` and `plan_routines_new_routine_copy_starred.png`.
void showOpenGymUndoToast(
  BuildContext context, {
  required String message,
  VoidCallback? onUndo,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      content: Row(
        children: <Widget>[
          if (onUndo != null) ...<Widget>[
            GestureDetector(
              onTap: () => messenger.hideCurrentSnackBar(),
              child: Icon(
                Icons.close,
                size: 18,
                color: colorScheme.onInverseSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onInverseSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onUndo != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: colorScheme.inversePrimary,
              ),
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onUndo();
              },
              icon: const Icon(Icons.undo_rounded, size: 16),
              label: const Text(
                'Undo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    ),
  );
}
