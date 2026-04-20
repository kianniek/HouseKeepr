import 'package:flutter/material.dart';
import '../models/grocery_item.dart';
import '../models/grocery_category.dart';

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
          // Checkbox on the left
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

          // Item name and details
          title: Text(
            item.name,
            style: aisleMode
                ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : null,
                    color: item.checked ? scheme.onSurfaceVariant : null,
                  )
                : Theme.of(context).textTheme.bodyLarge?.copyWith(
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : null,
                    color: item.checked ? scheme.onSurfaceVariant : null,
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          subtitle: item.note != null || item.category != GroceryCategory.other
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.note != null)
                      Text(
                        item.note!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                )
              : null,

          // Quantity badge on the right
          trailing: GestureDetector(
            onTap: onQuantity,
            onLongPress: onQuantityLongPress,
            child: Container(
              width: aisleMode ? 56 : 48,
              height: aisleMode ? 56 : 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  item.quantity.toString(),
                  style:
                      (aisleMode
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.bodyLarge)
                          ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          onTap: onCheck,
          onLongPress: onLongPress,
        ),
      ),
    );
  }
}
