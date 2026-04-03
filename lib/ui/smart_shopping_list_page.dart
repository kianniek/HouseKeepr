import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../cubits/shopping_cubit_v2.dart';
import '../models/grocery_item.dart';
import '../models/grocery_category.dart';
import '../services/shopping_products_service.dart';
import 'shopping_list_item_tile.dart';
import 'quantity_picker_dialog.dart';

class SmartShoppingListPage extends StatefulWidget {
  const SmartShoppingListPage({super.key});

  @override
  State<SmartShoppingListPage> createState() => _SmartShoppingListPageState();
}

class _SmartShoppingListPageState extends State<SmartShoppingListPage> {
  final TextEditingController _itemController = TextEditingController();
  final FocusNode _itemFocusNode = FocusNode();
  GroceryCategory _selectedCategory = GroceryCategory.other;
  bool _manualCategoryOverride = false;
  bool _showCategoryChips = false;
  String _manualOverrideText = '';
  String? _suggestedText;
  double _suggestionConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    _itemController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final rawText = _itemController.text;
    if (_manualCategoryOverride && rawText != _manualOverrideText) {
      _manualCategoryOverride = false;
    }
    if (_manualCategoryOverride) return;

    final text = rawText.trim();
    if (text.isEmpty) {
      if (_selectedCategory != GroceryCategory.other ||
          _suggestedText != null) {
        setState(() {
          _selectedCategory = GroceryCategory.other;
          _suggestedText = null;
          _suggestionConfidence = 0.0;
        });
      }
      return;
    }

    final suggestion = ShoppingProductsService.instance.getProductSuggestion(
      text,
    );
    final nextSuggestedText = suggestion?.product;
    final nextSuggestionConfidence = suggestion?.confidence ?? 0.0;

    final learned = ShoppingProductsService.instance.getCategoryForProduct(
      text,
    );
    final nextCategory = learned ?? _selectedCategory;
    if (nextCategory != _selectedCategory ||
        nextSuggestedText != _suggestedText ||
        nextSuggestionConfidence != _suggestionConfidence) {
      setState(() {
        if (learned != null) {
          _selectedCategory = learned;
        }
        _suggestedText = nextSuggestedText;
        _suggestionConfidence = nextSuggestionConfidence;
      });
    }
  }

  @override
  void dispose() {
    _itemController.removeListener(_onTextChanged);
    _itemController.dispose();
    _itemFocusNode.dispose();
    // Disable wake lock when leaving the page
    WakelockPlus.disable();
    super.dispose();
  }

  void _addItem() {
    final text = _toPascalCase(_itemController.text);
    if (text.isEmpty) return;

    context.read<ShoppingCubit>().addItem(text, category: _selectedCategory);

    _itemController.clear();
    _selectedCategory = GroceryCategory.other;
    _manualCategoryOverride = false;
    _manualOverrideText = '';
    _suggestedText = null;
    _suggestionConfidence = 0.0;
    _itemFocusNode.requestFocus();
  }

  String _toPascalCase(String input) {
    final collapsed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return '';
    return collapsed
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) => word.length == 1
              ? word.toUpperCase()
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return BlocListener<ShoppingCubit, ShoppingState>(
      listenWhen: (prev, curr) =>
          prev.aisleModeEnabled != curr.aisleModeEnabled,
      listener: (context, state) {
        if (state.aisleModeEnabled) {
          WakelockPlus.enable();
        } else {
          WakelockPlus.disable();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shopping List'),
          elevation: 0,
          actions: [
            BlocBuilder<ShoppingCubit, ShoppingState>(
              builder: (context, state) {
                final checkedCount = state.items.where((i) => i.checked).length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      '${state.items.length - checkedCount}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                );
              },
            ),
            BlocBuilder<ShoppingCubit, ShoppingState>(
              builder: (context, state) => PopupMenuButton(
                onSelected: (value) {
                  if (value == 'clear') {
                    context.read<ShoppingCubit>().clearCheckedItems();
                  } else if (value == 'mode') {
                    context.read<ShoppingCubit>().toggleAisleMode();
                  } else if (value == 'flat') {
                    context.read<ShoppingCubit>().toggleFlatView();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'mode',
                    child: Row(
                      children: [
                        Icon(
                          state.aisleModeEnabled
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.aisleModeEnabled
                              ? 'Aisle Mode: On'
                              : 'Aisle Mode: Off',
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'flat',
                    child: Row(
                      children: [
                        Icon(
                          state.flatViewEnabled
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.flatViewEnabled
                              ? 'Flat View: On'
                              : 'Flat View: Off',
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Text('Clear Checked Items'),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: Column(
              children: [
                // Quick Add Section
                _buildQuickAddSection(context, isMobile),
                const SizedBox(height: 8),

                // Shopping List
                Expanded(
                  child: BlocBuilder<ShoppingCubit, ShoppingState>(
                    builder: (context, state) {
                      if (state.items.isEmpty) {
                        return const Center(
                          child: Text('No items yet. Start adding!'),
                        );
                      }

                      // Group items by category (for unchecked items)
                      final uncheckedItems = state.items
                          .where((i) => !i.checked)
                          .toList();
                      final checkedItems = state.items
                          .where((i) => i.checked)
                          .toList();

                      final categories = <GroceryCategory, List<GroceryItem>>{};
                      for (final item in uncheckedItems) {
                        categories.putIfAbsent(item.category, () => []);
                        categories[item.category]!.add(item);
                      }

                      // For flat view: sort by creation time (newest first)
                      final flatSortedItems = List<GroceryItem>.from(
                        uncheckedItems,
                      )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                      return NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollStartNotification ||
                              notification is UserScrollNotification) {
                            FocusScope.of(context).unfocus();
                          }
                          return false;
                        },
                        child: CustomScrollView(
                          slivers: [
                            // Unchecked items - flat or grouped
                            if (state.flatViewEnabled)
                              // Flat view: single list without category headers
                              SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final item = flatSortedItems[index];
                                  return ShoppingListItemTile(
                                    item: item,
                                    aisleMode: state.aisleModeEnabled,
                                    onCheck: () => context
                                        .read<ShoppingCubit>()
                                        .toggleItem(item.id),
                                    onDelete: () => context
                                        .read<ShoppingCubit>()
                                        .deleteItem(item.id),
                                    onQuantity: () => context
                                        .read<ShoppingCubit>()
                                        .cycleQuantity(item.id),
                                    onQuantityLongPress: () async {
                                      final newQty =
                                          await showQuantityPickerDialog(
                                            context,
                                            currentQuantity: item.quantity,
                                          );
                                      if (newQty != null && context.mounted) {
                                        context
                                            .read<ShoppingCubit>()
                                            .updateQuantity(item.id, newQty);
                                      }
                                    },
                                  );
                                }, childCount: flatSortedItems.length),
                              )
                            else
                              // Grouped by category
                              ...categories.entries.map((entry) {
                                final category = entry.key;
                                final items = entry.value;
                                return _buildCategorySection(
                                  context,
                                  category,
                                  items,
                                  state.aisleModeEnabled,
                                );
                              }),

                            // Checked items section
                            if (checkedItems.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: _buildCompletedHeader(
                                    checkedItems.length,
                                  ),
                                ),
                              ),
                            if (checkedItems.isNotEmpty)
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => ShoppingListItemTile(
                                    item: checkedItems[index],
                                    aisleMode: state.aisleModeEnabled,
                                    onCheck: () => context
                                        .read<ShoppingCubit>()
                                        .toggleItem(checkedItems[index].id),
                                    onDelete: () => context
                                        .read<ShoppingCubit>()
                                        .deleteItem(checkedItems[index].id),
                                    onQuantity: () => context
                                        .read<ShoppingCubit>()
                                        .cycleQuantity(checkedItems[index].id),
                                    onQuantityLongPress: () async {
                                      final newQty =
                                          await showQuantityPickerDialog(
                                            context,
                                            currentQuantity:
                                                checkedItems[index].quantity,
                                          );
                                      if (newQty != null && context.mounted) {
                                        context
                                            .read<ShoppingCubit>()
                                            .updateQuantity(
                                              checkedItems[index].id,
                                              newQty,
                                            );
                                      }
                                    },
                                  ),
                                  childCount: checkedItems.length,
                                ),
                              ),
                            const SliverSafeArea(
                              sliver: SliverToBoxAdapter(
                                child: SizedBox(height: 16),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddSection(BuildContext context, bool isMobile) {
    const inputPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    final inputTextStyle = Theme.of(context).textTheme.bodyLarge;
    final currentText = _itemController.text;
    final suggestionLower = _suggestedText?.toLowerCase();
    final currentLower = currentText.trim().toLowerCase();
    final showGhost =
        _suggestedText != null &&
        currentLower.isNotEmpty &&
        suggestionLower != null &&
        suggestionLower.startsWith(currentLower);
    final ghostRemainder = showGhost
        ? _suggestedText!.substring(currentLower.length)
        : '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input row
          Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (_showCategoryChips != hasFocus) {
                      setState(() => _showCategoryChips = hasFocus);
                    }
                  },
                  child: Stack(
                    children: [
                      if (showGhost)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Padding(
                              padding: inputPadding,
                              child: RichText(
                                text: TextSpan(
                                  style: inputTextStyle,
                                  children: [
                                    TextSpan(
                                      text: currentText,
                                      style: inputTextStyle?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface.withAlpha(0),
                                      ),
                                    ),
                                    TextSpan(
                                      text: ghostRemainder,
                                      style: inputTextStyle?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).hintColor.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      TextField(
                        controller: _itemController,
                        focusNode: _itemFocusNode,
                        style: inputTextStyle,
                        onTap: () {
                          final current = _itemController.text.trim();
                          if (_suggestedText != null &&
                              current.isNotEmpty &&
                              current.toLowerCase() !=
                                  _suggestedText!.toLowerCase()) {
                            _manualCategoryOverride = false;
                            _itemController.text = _suggestedText!;
                            _itemController
                                .selection = TextSelection.fromPosition(
                              TextPosition(offset: _itemController.text.length),
                            );
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Add item...',
                          suffixText:
                              'in category ${_selectedCategory.displayName}',
                          suffixStyle: Theme.of(context).textTheme.labelSmall,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: inputPadding,
                        ),
                        onSubmitted: (_) => _addItem(),
                        autofocus: false,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Category chips - selected first with animation
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            ),
            child: _showCategoryChips
                ? _buildCategoryHexGrid(context)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHexGrid(BuildContext context) {
    const chipSize = 44.0;
    const hSpacing = 0.0;
    const vSpacing = 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final baseColumns = ((maxWidth + hSpacing) / (chipSize + hSpacing))
            .floor()
            .clamp(1, GroceryCategory.values.length);

        final rows = <Widget>[];
        var index = 0;
        var rowIndex = 0;

        while (index < GroceryCategory.values.length) {
          final isOffsetRow = rowIndex.isOdd && baseColumns > 1;
          final columns = isOffsetRow ? baseColumns - 1 : baseColumns;
          final rowItems = <Widget>[];

          if (isOffsetRow) {
            rowItems.add(SizedBox(width: (chipSize + hSpacing) / 2));
          }

          for (
            var col = 0;
            col < columns && index < GroceryCategory.values.length;
            col++
          ) {
            final cat = GroceryCategory.values[index];
            rowItems.add(_buildCategoryChip(context, cat, chipSize));
            if (col < columns - 1) {
              rowItems.add(const SizedBox(width: hSpacing));
            }
            index++;
          }

          rows.add(Row(children: rowItems));
          if (index < GroceryCategory.values.length) {
            rows.add(const SizedBox(height: vSpacing));
          }
          rowIndex++;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    GroceryCategory cat,
    double size,
  ) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: _selectedCategory == cat ? 1.05 : 1.0),
        duration: const Duration(milliseconds: 200),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Tooltip(
          message: cat.displayName,
          triggerMode: TooltipTriggerMode.tap,
          child: FilterChip(
            label: Text(cat.emoji),
            selected: _selectedCategory == cat,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.all(0),
            shape: const CircleBorder(),
            onSelected: (_) {
              setState(() {
                _selectedCategory = cat;
                _manualCategoryOverride = true;
                _manualOverrideText = _itemController.text.trim();
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    GroceryCategory category,
    List<GroceryItem> items,
    bool aisleMode,
  ) {
    return SliverMainAxisGroup(
      slivers: [
        // Sticky header
        SliverPersistentHeader(
          pinned: true,
          delegate: _SectionHeaderDelegate(
            height: 48,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    category.emoji,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      items.length.toString(),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Items in category
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = items[index];
            return ShoppingListItemTile(
              item: item,
              aisleMode: aisleMode,
              onCheck: () => context.read<ShoppingCubit>().toggleItem(item.id),
              onDelete: () => context.read<ShoppingCubit>().deleteItem(item.id),
              onQuantity: () =>
                  context.read<ShoppingCubit>().cycleQuantity(item.id),
              onQuantityLongPress: () async {
                final newQty = await showQuantityPickerDialog(
                  context,
                  currentQuantity: item.quantity,
                );
                if (newQty != null && context.mounted) {
                  context.read<ShoppingCubit>().updateQuantity(item.id, newQty);
                }
              },
            );
          }, childCount: items.length),
        ),
      ],
    );
  }

  Widget _buildCompletedHeader(int count) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Completed ($count)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _SectionHeaderDelegate({required this.height, required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
