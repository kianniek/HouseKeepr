import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../cubits/shopping_cubit.dart';
import '../../../../models/grocery_category.dart';
import '../../../../models/grocery_item.dart';
import '../../../common/widgets/bulk_import_confirmation_dialog.dart';
import '../../../common/widgets/bulk_import_dialog.dart';
import '../../../common/widgets/category_picker_dialog.dart';
import '../../../common/widgets/quantity_picker_dialog.dart';
import '../widgets/shopping_list_item_tile.dart';

class SmartShoppingListPage extends StatefulWidget {
  const SmartShoppingListPage({super.key});

  @override
  State<SmartShoppingListPage> createState() => _SmartShoppingListPageState();
}

class _SmartShoppingListPageState extends State<SmartShoppingListPage> {
  final TextEditingController _itemController = TextEditingController();
  final FocusNode _itemFocusNode = FocusNode();
  bool _showCategoryChips = false;
  // Scroll FAB state
  final ScrollController _scrollController = ScrollController();
  bool _showScrollDownFab = false;
  bool _showScrollUpFab = false;
  static const Duration _fabAnimDur = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _itemController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFabVisibility());
  }

  void _onTextChanged() {
    context.read<ShoppingCubit>().updateDraftText(_itemController.text);
  }

  @override
  void dispose() {
    _itemController.removeListener(_onTextChanged);
    _itemController.dispose();
    _itemFocusNode.dispose();
    _scrollController.dispose();
    // Disable wake lock when leaving the page
    WakelockPlus.disable();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;

    // If there's nothing to scroll, hide both
    if (max <= 0) {
      if (_showScrollDownFab || _showScrollUpFab) {
        setState(() {
          _showScrollDownFab = false;
          _showScrollUpFab = false;
        });
      }
      return;
    }

    final atBottom = offset >= (max - 24.0);

    if (atBottom) {
      if (!_showScrollUpFab || _showScrollDownFab) {
        setState(() {
          _showScrollUpFab = true;
          _showScrollDownFab = false;
        });
      }
    } else {
      if (!_showScrollDownFab || _showScrollUpFab) {
        setState(() {
          _showScrollDownFab = true;
          _showScrollUpFab = false;
        });
      }
    }
  }

  void _updateFabVisibility() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    if (max > 50 && offset < (max - 24.0)) {
      setState(() {
        _showScrollDownFab = true;
        _showScrollUpFab = false;
      });
    } else {
      setState(() {
        _showScrollDownFab = false;
        _showScrollUpFab = false;
      });
    }
  }

  void _addItem() {
    final text = _toPascalCase(_itemController.text);
    if (text.isEmpty) return;

    context.read<ShoppingCubit>().addItem(text);

    _itemController.clear();
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
        resizeToAvoidBottomInset: false,
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

                      return Stack(
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollStartNotification ||
                                  notification is UserScrollNotification) {
                                FocusScope.of(context).unfocus();
                                if (_showScrollDownFab || _showScrollUpFab) {
                                  setState(() {
                                    _showScrollDownFab = false;
                                    _showScrollUpFab = false;
                                  });
                                }
                              }
                              return false;
                            },
                            child: CustomScrollView(
                              controller: _scrollController,
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
                                          final newQtyUnit =
                                              await showQuantityPickerDialog(
                                                context,
                                                currentQuantity: item.quantity,
                                                currentUnit: item.unit,
                                              );
                                          if (newQtyUnit != null &&
                                              context.mounted) {
                                            context
                                                .read<ShoppingCubit>()
                                                .updateQuantityAndUnit(
                                                  item.id,
                                                  newQtyUnit.$1,
                                                  newQtyUnit.$2,
                                                );
                                          }
                                        },
                                        onLongPress: () async {
                                          final newCat =
                                              await showCategoryPickerDialog(
                                                context,
                                                currentCategory: item.category,
                                              );
                                          if (newCat != null &&
                                              context.mounted) {
                                            context
                                                .read<ShoppingCubit>()
                                                .updateCategory(
                                                  item.id,
                                                  newCat,
                                                );
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
                                            .cycleQuantity(
                                              checkedItems[index].id,
                                            ),
                                        onQuantityLongPress: () async {
                                          final newQtyUnit =
                                              await showQuantityPickerDialog(
                                                context,
                                                currentQuantity:
                                                    checkedItems[index]
                                                        .quantity,
                                                currentUnit:
                                                    checkedItems[index].unit,
                                              );
                                          if (newQtyUnit != null &&
                                              context.mounted) {
                                            context
                                                .read<ShoppingCubit>()
                                                .updateQuantityAndUnit(
                                                  checkedItems[index].id,
                                                  newQtyUnit.$1,
                                                  newQtyUnit.$2,
                                                );
                                          }
                                        },
                                        onLongPress: () async {
                                          final newCat =
                                              await showCategoryPickerDialog(
                                                context,
                                                currentCategory:
                                                    checkedItems[index]
                                                        .category,
                                              );
                                          if (newCat != null &&
                                              context.mounted) {
                                            context
                                                .read<ShoppingCubit>()
                                                .updateCategory(
                                                  checkedItems[index].id,
                                                  newCat,
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
                          ),

                          // Scroll Down FAB (appears when not at bottom)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: AnimatedSlide(
                              duration: _fabAnimDur,
                              offset: _showScrollDownFab
                                  ? Offset.zero
                                  : const Offset(0, 1),
                              child: AnimatedOpacity(
                                duration: _fabAnimDur,
                                opacity: _showScrollDownFab ? 1.0 : 0.0,
                                child: FloatingActionButton(
                                  heroTag: 'scrollDownFab',
                                  onPressed: () async {
                                    setState(() => _showScrollDownFab = false);
                                    await _scrollController.animateTo(
                                      _scrollController
                                          .position
                                          .maxScrollExtent,
                                      duration: const Duration(
                                        milliseconds: 420,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                    if (context.mounted) {
                                      setState(() {
                                        _showScrollUpFab = true;
                                        _showScrollDownFab = false;
                                      });
                                    }
                                  },
                                  child: const Icon(Icons.arrow_downward),
                                ),
                              ),
                            ),
                          ),

                          // Scroll Up FAB (appears when at bottom)
                          Positioned(
                            right: 16,
                            top: 16,
                            child: AnimatedSlide(
                              duration: _fabAnimDur,
                              offset: _showScrollUpFab
                                  ? Offset.zero
                                  : const Offset(0, -1),
                              child: AnimatedOpacity(
                                duration: _fabAnimDur,
                                opacity: _showScrollUpFab ? 1.0 : 0.0,
                                child: FloatingActionButton(
                                  heroTag: 'scrollUpFab',
                                  onPressed: () async {
                                    setState(() => _showScrollUpFab = false);
                                    await _scrollController.animateTo(
                                      0.0,
                                      duration: const Duration(
                                        milliseconds: 420,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                    if (context.mounted) {
                                      setState(() {
                                        _showScrollDownFab =
                                            _scrollController
                                                .position
                                                .maxScrollExtent >
                                            50;
                                        _showScrollUpFab = false;
                                      });
                                    }
                                  },
                                  child: const Icon(Icons.arrow_upward),
                                ),
                              ),
                            ),
                          ),
                        ],
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
    return BlocBuilder<ShoppingCubit, ShoppingState>(
      buildWhen: (prev, curr) =>
          prev.selectedCategory != curr.selectedCategory ||
          prev.suggestedText != curr.suggestedText ||
          prev.suggestionConfidence != curr.suggestionConfidence ||
          prev.manualCategoryOverride != curr.manualCategoryOverride,
      builder: (context, state) {
        const inputPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
        final inputTextStyle = Theme.of(context).textTheme.bodyLarge;

        final currentText = _itemController.text;
        var displaySuggestedText = state.suggestedText;
        final suggestionLower = displaySuggestedText?.toLowerCase();
        final currentLower = currentText.toLowerCase();

        final showGhost =
            displaySuggestedText != null &&
            currentLower.isNotEmpty &&
            suggestionLower != null &&
            suggestionLower.startsWith(currentLower);

        if (showGhost) {
          displaySuggestedText =
              currentText +
              displaySuggestedText!.substring(currentLower.length);
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  if (showGhost)
                    IgnorePointer(
                      child: TextField(
                        controller: TextEditingController(
                          text: displaySuggestedText,
                        ),
                        style: inputTextStyle?.copyWith(
                          color: Theme.of(
                            context,
                          ).hintColor.withValues(alpha: 0.5),
                        ),
                        decoration: InputDecoration(
                          // Match the decoration EXACTLY
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                          contentPadding: inputPadding,
                        ),
                      ),
                    ),

                  // ACTUAL INPUT LAYER
                  Focus(
                    onFocusChange: (hasFocus) {
                      if (_showCategoryChips != hasFocus) {
                        setState(() => _showCategoryChips = hasFocus);
                      }
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _itemController,
                            focusNode: _itemFocusNode,
                            style: inputTextStyle,
                            onTap: () {
                              if (showGhost &&
                                  currentText != displaySuggestedText) {
                                _itemController.text = displaySuggestedText!;
                                _itemController.selection =
                                    TextSelection.fromPosition(
                                      TextPosition(
                                        offset: _itemController.text.length,
                                      ),
                                    );
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Add item...',
                              suffixText: showGhost
                                  ? null
                                  : 'in ${state.selectedCategory.displayName}',
                              suffixStyle: Theme.of(
                                context,
                              ).textTheme.labelSmall,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: inputPadding,
                              // Important: Make background transparent so ghost shows through
                              filled: false,
                            ),
                            onSubmitted: (_) => _addItem(),
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () async {
                            final parsedItems = await showBulkImportDialog(
                              context,
                            );
                            if (parsedItems != null &&
                                parsedItems.isNotEmpty &&
                                context.mounted) {
                              final confirmedItems =
                                  await showBulkImportConfirmationDialog(
                                    context,
                                    parsedItems,
                                  );
                              if (confirmedItems != null && context.mounted) {
                                for (final item in confirmedItems) {
                                  context.read<ShoppingCubit>().addItem(
                                    item.name,
                                    category: item.category,
                                    quantity: item.quantity,
                                    unit: item.unit,
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.playlist_add),
                          tooltip: 'Bulk Add',
                        ),
                      ],
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
                    ? _buildCategoryHexGrid(context, state)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryHexGrid(BuildContext context, ShoppingState state) {
    const chipSize = 44.0;
    const hSpacing = chipSize * 0.1;
    const vSpacing = chipSize * 0.1;

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

          for (
            var col = 0;
            col < columns && index < GroceryCategory.values.length;
            col++
          ) {
            final cat = GroceryCategory.values[index];
            rowItems.add(_buildCategoryChip(context, cat, chipSize, state));

            if (col < columns - 1) {
              rowItems.add(const SizedBox(width: hSpacing));
            }
            index++;
          }

          rows.add(
            Row(
              // This is the magic line that centers the chips horizontally
              mainAxisAlignment: MainAxisAlignment.center,
              children: rowItems,
            ),
          );

          if (index < GroceryCategory.values.length) {
            rows.add(const SizedBox(height: vSpacing));
          }
          rowIndex++;
        }

        return Column(
          // Centers the entire block of rows if the container is wider than the grid
          crossAxisAlignment: CrossAxisAlignment.center,
          children: rows,
        );
      },
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    GroceryCategory cat,
    double size,
    ShoppingState state,
  ) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: 1.0,
          end: state.selectedCategory == cat ? 1.05 : 1.0,
        ),
        duration: const Duration(milliseconds: 200),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Tooltip(
          message: cat.displayName,
          triggerMode: TooltipTriggerMode.tap,
          child: FilterChip(
            label: Text(cat.emoji),
            selected: state.selectedCategory == cat,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.all(0),
            shape: const CircleBorder(),
            onSelected: (_) {
              context.read<ShoppingCubit>().setManualCategory(
                cat,
                _itemController.text.trim(),
              );
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
                      ).colorScheme.primary.withValues(alpha: 0.2),
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
                final newQtyUnit = await showQuantityPickerDialog(
                  context,
                  currentQuantity: item.quantity,
                  currentUnit: item.unit,
                );
                if (newQtyUnit != null && context.mounted) {
                  context.read<ShoppingCubit>().updateQuantityAndUnit(
                    item.id,
                    newQtyUnit.$1,
                    newQtyUnit.$2,
                  );
                }
              },
              onLongPress: () async {
                final newCat = await showCategoryPickerDialog(
                  context,
                  currentCategory: item.category,
                );
                if (newCat != null && context.mounted) {
                  context.read<ShoppingCubit>().updateCategory(item.id, newCat);
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
