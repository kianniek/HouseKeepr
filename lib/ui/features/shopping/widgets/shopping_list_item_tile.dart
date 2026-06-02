import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:marquee/marquee.dart';

import '../../../../core/quantity_unit_formatter.dart';
import '../../../../models/grocery_category.dart';
import '../../../../models/grocery_item.dart';

class ShoppingListItemTile extends StatelessWidget {
  final GroceryItem item;
  final bool aisleMode;
  final VoidCallback onCheck;
  final VoidCallback onDelete;
  final VoidCallback onQuantity;
  final VoidCallback? onQuantityLongPress;
  final VoidCallback? onLongPress;

  const ShoppingListItemTile({
    super.key,
    required this.item,
    required this.aisleMode,
    required this.onCheck,
    required this.onDelete,
    required this.onQuantity,
    this.onQuantityLongPress,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unitLabel = formatQuantityUnit(item.unit, item.quantity);
    final hasNote = item.note != null && item.note!.isNotEmpty;

    final TextStyle baseTextStyle =
        (aisleMode
            ? theme.textTheme.headlineSmall
            : theme.textTheme.bodyLarge) ??
        const TextStyle();

    final titleStyle = baseTextStyle.copyWith(
      decoration: item.checked ? TextDecoration.lineThrough : null,
      color: item.checked ? scheme.onSurfaceVariant : null,
    );

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: scheme.error,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Icon(Icons.delete, color: scheme.onError),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        color: item.checked
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.2)
            : scheme.surface.withAlpha(0),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: aisleMode ? 24 : 16,
            vertical: aisleMode ? 12 : 8,
          ),
          leading: GestureDetector(
            onTap: onCheck,
            child: Container(
              width: aisleMode ? 56 : 48,
              height: aisleMode ? 56 : 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: item.checked ? scheme.primary : scheme.outline,
                  width: 2,
                ),
                color: item.checked ? scheme.primary : scheme.surface,
              ),
              child: item.checked
                  ? Icon(
                      Icons.check,
                      color: scheme.onPrimary,
                      size: aisleMode ? 28 : 24,
                    )
                  : null,
            ),
          ),

          title: LayoutBuilder(
            builder: (context, constraints) {
              double parentWidth = constraints.maxWidth;
              bool useMarquee = hasNote;

              if (!useMarquee) {
                final textPainter = TextPainter(
                  text: TextSpan(text: item.name, style: titleStyle),
                  textDirection: TextDirection.ltr,
                  maxLines: 2,
                )..layout(maxWidth: parentWidth);

                if (textPainter.didExceedMaxLines) {
                  useMarquee = true;
                }
              }

              if (useMarquee) {
                return SizedBox(
                  height: aisleMode ? 32.0 : 24.0,
                  child: Marquee(
                    text: item.name,
                    style: titleStyle,
                    startAfter: const Duration(seconds: 3),
                    pauseAfterRound: Duration(seconds: item.name.length),
                    blankSpace: parentWidth,
                    velocity: 25,
                    accelerationCurve: Curves.linear,
                    accelerationDuration: const Duration(seconds: 1),
                    decelerationDuration: const Duration(seconds: 1),
                    decelerationCurve: Curves.linear,
                  ),
                );
              }

              return Text(
                item.name,
                style: titleStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),

          subtitle: hasNote || item.category != GroceryCategory.other
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasNote)
                      SizedBox(
                        height: 20.0,
                        child: Marquee(
                          text: item.note!,
                          style: theme.textTheme.bodySmall,
                          startAfter: const Duration(seconds: 3),
                          pauseAfterRound: Duration(seconds: item.note!.length),
                          blankSpace: 20,
                          velocity: 25,
                          accelerationCurve: Curves.linear,
                          accelerationDuration: const Duration(seconds: 1),
                          decelerationDuration: const Duration(seconds: 1),
                          decelerationCurve: Curves.linear,
                        ),
                      ),
                  ],
                )
              : null,

          trailing: GestureDetector(
            onTap: onQuantity,
            onLongPress: onQuantityLongPress,
            child: () {
              final hasUnit = unitLabel != null && unitLabel.isNotEmpty;
              final double targetSize = aisleMode ? 56 : 48;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                // If there's no unit, force it to be a perfect square using fixed width and height
                width: hasUnit ? null : targetSize,
                height: targetSize,
                constraints: hasUnit
                    ? BoxConstraints(
                        minHeight: targetSize,
                        minWidth: targetSize,
                      )
                    : null,
                padding: EdgeInsets.symmetric(
                  // Remove horizontal padding when it's a square so the text is perfectly centered
                  horizontal: hasUnit ? (aisleMode ? 16 : 12) : 0,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(targetSize / 2),
                  color: scheme.primary.withValues(alpha: 0.15),
                ),
                child: IntrinsicWidth(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.quantity % 1 == 0
                              ? item.quantity.toInt().toString()
                              : item.quantity.toString(),
                          style:
                              (aisleMode
                                      ? theme.textTheme.headlineSmall
                                      : theme.textTheme.bodyLarge)
                                  ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (hasUnit) ...[
                          const SizedBox(width: 6),
                          Text(
                            unitLabel,
                            style:
                                (aisleMode
                                        ? theme.textTheme.headlineSmall
                                        : theme.textTheme.bodyLarge)
                                    ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }(),
          ),

          onTap: onCheck,
          onLongPress: onLongPress,
        ),
      ),
    );
  }
}
