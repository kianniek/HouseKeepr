import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../generated/app_localizations.dart';
import '../../../../models/grocery_item.dart';
import '../../../../services/app_haptics.dart';
import 'shopping_list_item_tile.dart';

/// An expandable parent container tile representing an imported recipe and all
/// of its nested [ingredients] on the shopping list.
class RecipeShoppingListTile extends StatefulWidget {
  final GroceryItem recipe;
  final List<GroceryItem> ingredients;
  final bool aisleMode;
  final bool initiallyExpanded;
  final VoidCallback onToggleRecipe;
  final VoidCallback onDeleteRecipe;
  final ValueChanged<GroceryItem> onToggleIngredient;
  final ValueChanged<GroceryItem> onDeleteIngredient;
  final ValueChanged<GroceryItem> onIngredientQuantity;
  final ValueChanged<GroceryItem>? onIngredientQuantityLongPress;
  final ValueChanged<GroceryItem>? onIngredientLongPress;

  const RecipeShoppingListTile({
    super.key,
    required this.recipe,
    required this.ingredients,
    required this.aisleMode,
    this.initiallyExpanded = true,
    required this.onToggleRecipe,
    required this.onDeleteRecipe,
    required this.onToggleIngredient,
    required this.onDeleteIngredient,
    required this.onIngredientQuantity,
    this.onIngredientQuantityLongPress,
    this.onIngredientLongPress,
  });

  @override
  State<RecipeShoppingListTile> createState() => _RecipeShoppingListTileState();
}

class _RecipeShoppingListTileState extends State<RecipeShoppingListTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  Future<void> _openRecipeUrl() async {
    final rawUrl = widget.recipe.recipeUrl;
    if (rawUrl == null || rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final totalCount = widget.ingredients.length;
    final checkedCount = widget.ingredients.where((i) => i.checked).length;
    final allChecked =
        widget.recipe.checked || (totalCount > 0 && checkedCount == totalCount);
    final someChecked = !allChecked && checkedCount > 0;

    final double circleSize = widget.aisleMode ? 52 : 48;
    final titleStyle =
        (widget.aisleMode
                ? theme.textTheme.headlineSmall
                : theme.textTheme.titleMedium)
            ?.copyWith(
              fontWeight: FontWeight.w700,
              decoration: allChecked ? TextDecoration.lineThrough : null,
              color: allChecked ? scheme.onSurfaceVariant : scheme.onSurface,
            );

    final metaParts = <String>[
      if (widget.recipe.recipeSource != null &&
          widget.recipe.recipeSource!.isNotEmpty)
        widget.recipe.recipeSource!,
      if (widget.recipe.recipeServings != null)
        l10n.servingsCount(widget.recipe.recipeServings!),
    ];

    return Dismissible(
      key: ValueKey('recipe_${widget.recipe.id}'),
      direction: DismissDirection.endToStart,
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          AppHaptics.instance.gestureStart();
        }
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: scheme.onError),
      ),
      onDismissed: (_) {
        AppHaptics.instance.confirm();
        widget.onDeleteRecipe();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: allChecked
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.25)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: allChecked
                ? scheme.outlineVariant.withValues(alpha: 0.35)
                : scheme.primary.withValues(alpha: 0.28),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recipe Parent Header
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.aisleMode ? 18 : 14,
                  vertical: widget.aisleMode ? 14 : 10,
                ),
                child: Row(
                  children: [
                    InkResponse(
                      key: ValueKey('recipe_toggle_${widget.recipe.id}'),
                      onTap: () {
                        if (allChecked) {
                          AppHaptics.instance.toggleOff();
                        } else {
                          AppHaptics.instance.toggleOn();
                        }
                        widget.onToggleRecipe();
                      },
                      radius: circleSize / 2,
                      child: Container(
                        width: circleSize,
                        height: circleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (allChecked || someChecked)
                                ? scheme.primary
                                : scheme.outline,
                            width: 2,
                          ),
                          color: allChecked ? scheme.primary : scheme.surface,
                        ),
                        child: allChecked
                            ? Icon(
                                Icons.check,
                                color: scheme.onPrimary,
                                size: widget.aisleMode ? 26 : 22,
                              )
                            : someChecked
                            ? Center(
                                child: Container(
                                  width: circleSize * 0.38,
                                  height: circleSize * 0.38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: scheme.primary,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.restaurant_menu,
                                size: widget.aisleMode ? 22 : 18,
                                color: scheme.primary,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.recipe.name,
                            style: titleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (metaParts.isNotEmpty)
                                Text(
                                  metaParts.join(' • '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              if (totalCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: allChecked
                                        ? scheme.primary.withValues(alpha: 0.18)
                                        : scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    l10n.recipeIngredientsProgress(
                                      checkedCount,
                                      totalCount,
                                    ),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: allChecked
                                          ? scheme.primary
                                          : scheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.recipe.recipeUrl != null &&
                        widget.recipe.recipeUrl!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 20),
                        tooltip: l10n.openRecipeLink,
                        onPressed: _openRecipeUrl,
                        visualDensity: VisualDensity.compact,
                      ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Nested Ingredients Container
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: widget.ingredients.isEmpty
                  ? const SizedBox.shrink()
                  : Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(left: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: scheme.primary.withValues(alpha: 0.3),
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Column(
                          children: widget.ingredients.map((ingredient) {
                            return ShoppingListItemTile(
                              item: ingredient,
                              aisleMode: widget.aisleMode,
                              onCheck: () =>
                                  widget.onToggleIngredient(ingredient),
                              onDelete: () =>
                                  widget.onDeleteIngredient(ingredient),
                              onQuantity: () =>
                                  widget.onIngredientQuantity(ingredient),
                              onQuantityLongPress:
                                  widget.onIngredientQuantityLongPress != null
                                  ? () => widget.onIngredientQuantityLongPress!(
                                      ingredient,
                                    )
                                  : null,
                              onLongPress: widget.onIngredientLongPress != null
                                  ? () => widget.onIngredientLongPress!(
                                      ingredient,
                                    )
                                  : null,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
