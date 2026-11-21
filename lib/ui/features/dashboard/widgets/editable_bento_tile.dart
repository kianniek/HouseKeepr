import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../cubits/shopping_cubit.dart';
import '../models/dashboard_layout_store.dart';

/// Greyscale color matrix used to desaturate hidden widgets in edit mode.
const ColorFilter _kGreyscaleFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// Wraps a dashboard Bento widget with long-press drag-to-reorder,
/// edit-mode jiggle animation, and a top-right remove (`×`) button.
class EditableBentoTile extends StatelessWidget {
  final DashboardWidgetId id;
  final int index;
  final double cardWidth;
  final bool isEditing;
  final Animation<double> jiggleAnimation;
  final VoidCallback onEnterEditMode;
  final VoidCallback onRemove;
  final void Function(DashboardWidgetId dragged, DashboardWidgetId target)
  onReorder;
  final Widget child;

  const EditableBentoTile({
    super.key,
    required this.id,
    required this.index,
    required this.cardWidth,
    required this.isEditing,
    required this.jiggleAnimation,
    required this.onEnterEditMode,
    required this.onRemove,
    required this.onReorder,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    Widget tileContent = IgnorePointer(ignoring: isEditing, child: child);

    if (isEditing && !disableAnimations) {
      tileContent = AnimatedBuilder(
        animation: jiggleAnimation,
        builder: (context, child) {
          final direction = index.isEven ? 1.0 : -1.0;
          final angle = (jiggleAnimation.value - 0.5) * 0.024 * direction;
          return Transform.rotate(angle: angle, child: child);
        },
        child: tileContent,
      );
    }

    if (isEditing) {
      tileContent = Stack(
        clipBehavior: Clip.none,
        children: [
          tileContent,
          Positioned(
            top: -8,
            right: -8,
            child: Material(
              color: scheme.errorContainer,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: scheme.onErrorContainer,
                    semanticLabel: 'Remove ${id.name} widget',
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return DragTarget<DashboardWidgetId>(
      onWillAcceptWithDetails: (details) => details.data != id,
      onAcceptWithDetails: (details) => onReorder(details.data, id),
      builder: (context, candidateData, rejectedData) {
        final isHoverTarget = candidateData.isNotEmpty;
        final decoratedTile = AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: isHoverTarget
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: scheme.primary, width: 2),
                )
              : null,
          child: tileContent,
        );

        ShoppingCubit? shoppingCubit;
        try {
          shoppingCubit = context.read<ShoppingCubit>();
        } catch (_) {
          shoppingCubit = null;
        }

        Widget feedbackContent = SizedBox(
          width: cardWidth,
          child: Opacity(opacity: 0.92, child: IgnorePointer(child: child)),
        );
        if (shoppingCubit != null) {
          feedbackContent = BlocProvider<ShoppingCubit>.value(
            value: shoppingCubit,
            child: feedbackContent,
          );
        }

        return LongPressDraggable<DashboardWidgetId>(
          data: id,
          onDragStarted: onEnterEditMode,
          feedback: Material(
            color: Colors.transparent,
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            child: feedbackContent,
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: tileContent),
          child: decoratedTile,
        );
      },
    );
  }
}

/// Renders a removed Bento widget in the bottom grayed-out restore tray
/// during edit mode. Tapping it restores it to the active dashboard.
class HiddenBentoTile extends StatelessWidget {
  final DashboardWidgetId id;
  final VoidCallback onRestore;
  final Widget child;

  const HiddenBentoTile({
    super.key,
    required this.id,
    required this.onRestore,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onRestore,
            borderRadius: BorderRadius.circular(20),
            child: ColorFiltered(
              colorFilter: _kGreyscaleFilter,
              child: Opacity(opacity: 0.45, child: IgnorePointer(child: child)),
            ),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: Material(
            color: scheme.primaryContainer,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              onTap: onRestore,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: scheme.onPrimaryContainer,
                  semanticLabel: 'Restore ${id.name} widget',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
