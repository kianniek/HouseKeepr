import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../cubits/shopping_cubit.dart';
import '../../../../../home_screen.dart';
import '../../../../../models/grocery_item.dart';
import '../../../../../services/app_haptics.dart';
import '../../../common/widgets/undo_toast.dart';
import '../../shopping/pages/smart_shopping_list_page.dart';

class ShoppingListWidget extends StatelessWidget {
  const ShoppingListWidget({super.key});

  void _openShopping(BuildContext context) {
    final homeState = context.findAncestorStateOfType<HomeScreenState>();
    if (homeState != null) {
      homeState.selectTab(HomeTab.shopping);
      return;
    }

    final shoppingCubit = context.read<ShoppingCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: shoppingCubit,
          child: const SmartShoppingListPage(),
        ),
      ),
    );
  }

  Future<void> _toggleItem(BuildContext context, GroceryItem item) async {
    final cubit = context.read<ShoppingCubit>();
    AppHaptics.instance.confirm();
    await cubit.toggleItem(item.id);
    if (!context.mounted) return;
    showUndoToast(
      context,
      message: 'Checked off "${item.name}"',
      icon: Icons.shopping_cart_outlined,
      onUndo: () => cubit.toggleItem(item.id),
    );
  }

  String _formatQuantity(GroceryItem item) {
    final qty = item.quantity;
    final qtyStr = qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toString();
    final unit = item.unit?.trim();
    if (unit != null && unit.isNotEmpty) {
      return '$qtyStr $unit';
    }
    if (qty != 1.0) {
      return '×$qtyStr';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<ShoppingCubit, ShoppingState>(
      builder: (context, state) {
        final unbought = state.items
            .where((item) => !item.isDeleted && !item.checked && !item.isRecipe)
            .toList();
        final previewItems = unbought.take(3).toList();
        final remainingCount = unbought.length - previewItems.length;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openShopping(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              constraints: const BoxConstraints(minHeight: 180),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Shopping',
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unbought.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${unbought.length}',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (unbought.isEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All caught up',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to add items',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in previewItems)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => _toggleItem(context, item),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.radio_button_unchecked,
                                      size: 18,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_formatQuantity(item).isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatQuantity(item),
                                    style: textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (remainingCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '+$remainingCount more',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
