import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

import '../../../../core/extensions.dart';
import '../../../../core/quantity_unit_formatter.dart';
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
      child: Material(
        color: item.checked
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.2)
            : Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: aisleMode ? 24 : 16,
            vertical: aisleMode ? 12 : 8,
          ),
          leading: InkResponse(
            onTap: onCheck,
            radius: (aisleMode ? 56 : 48) / 2,
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

          title: _AutoMarqueeText(
            text: item.name,
            style: titleStyle,
            maxLines: 2,
            marqueeHeight: aisleMode ? 32.0 : 24.0,
          ),

          subtitle: hasNote
              ? _AutoMarqueeText(
                  text: item.note!,
                  style: theme.textTheme.bodySmall ?? const TextStyle(),
                  maxLines: 1,
                  marqueeHeight: 20.0,
                  blankSpace: 20.0,
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
                              : item.quantity.toTrimmedFixed(2),
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

class _AutoMarqueeText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final double marqueeHeight;
  final double? blankSpace;

  const _AutoMarqueeText({
    required this.text,
    required this.style,
    required this.maxLines,
    required this.marqueeHeight,
    this.blankSpace,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentWidth = constraints.maxWidth;
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: maxLines,
        )..layout(maxWidth: parentWidth);

        if (textPainter.didExceedMaxLines) {
          return SizedBox(
            height: marqueeHeight,
            child: Marquee(
              text: text,
              style: style,
              startAfter: const Duration(seconds: 3),
              pauseAfterRound: Duration(seconds: text.length),
              blankSpace: blankSpace ?? parentWidth,
              velocity: 25,
              accelerationCurve: Curves.linear,
              accelerationDuration: const Duration(seconds: 1),
              decelerationDuration: const Duration(seconds: 1),
              decelerationCurve: Curves.linear,
            ),
          );
        }

        return Text(
          text,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
