import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/extensions.dart';
import '../../../../core/grocery_parser.dart';
import '../../../../core/quantity_unit_formatter.dart';
import '../../../../cubits/shopping_cubit.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../models/grocery_category.dart';
import '../../../../models/grocery_item.dart';
import '../../../../services/firestore_sync_service.dart';
import '../../../../services/recipe_import_service.dart';
import '../../../../services/shopping_products_service.dart';
import '../../../common/widgets/bulk_import_confirmation_dialog.dart';
import '../../../common/widgets/bulk_import_dialog.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/quantity_picker_dialog.dart';
import '../../../common/widgets/undo_toast.dart';
import '../widgets/recipe_import_dialog.dart';
import '../widgets/recipe_shopping_list_tile.dart';
import '../widgets/shopping_add_product_dialog.dart';
import '../widgets/shopping_edit_item_dialog.dart';
import '../widgets/shopping_list_item_tile.dart';
import 'recently_deleted_page.dart';

class SmartShoppingListPage extends StatefulWidget {
  const SmartShoppingListPage({super.key});

  @override
  State<SmartShoppingListPage> createState() => _SmartShoppingListPageState();
}

class _SmartShoppingListPageState extends State<SmartShoppingListPage> {
  static const String _completedExpandedKey = 'shopping_completed_expanded_v1';

  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _ghostController = TextEditingController();
  final FocusNode _itemFocusNode = FocusNode();
  bool _showCategoryChips = false;
  bool _completedExpanded = true;
  bool _hasToggledCompletedExpanded = false;
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
    if (context.read<ShoppingCubit>().state.aisleModeEnabled) {
      WakelockPlus.enable();
    }
    _loadCompletedExpandedPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFabVisibility());
  }

  Future<void> _loadCompletedExpandedPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || _hasToggledCompletedExpanded) return;
      final saved = prefs.getBool(_completedExpandedKey);
      if (saved != null && saved != _completedExpanded) {
        setState(() => _completedExpanded = saved);
      }
    } catch (_) {}
  }

  Future<void> _toggleCompletedExpanded() async {
    final nextValue = !_completedExpanded;
    setState(() {
      _hasToggledCompletedExpanded = true;
      _completedExpanded = nextValue;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_completedExpandedKey, nextValue);
    } catch (_) {}
  }

  void _onTextChanged() {
    context.read<ShoppingCubit>().updateDraftText(_itemController.text);
  }

  @override
  void dispose() {
    _itemController.removeListener(_onTextChanged);
    _itemController.dispose();
    _ghostController.dispose();
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
    final rawText = _itemController.text.trim();
    if (rawText.isEmpty) return;

    if (RecipeImportService.isRecipeUrl(rawText)) {
      _importRecipe(context, initialUrl: rawText);
      return;
    }

    final cubit = context.read<ShoppingCubit>();
    final parsed = GroceryParser.parseLine(rawText);
    if (parsed.name.isEmpty) return;

    final category = cubit.state.manualCategoryOverride
        ? cubit.state.selectedCategory
        : parsed.category;

    cubit.addItem(
      parsed.name,
      note: parsed.note,
      quantity: parsed.hasExplicitQuantity ? parsed.quantity : null,
      unit: parsed.hasExplicitQuantity ? parsed.unit : null,
      category: category,
    );

    _itemController.clear();
    _itemFocusNode.requestFocus();
  }

  Future<void> _importRecipe(BuildContext context, {String? initialUrl}) async {
    final cubit = context.read<ShoppingCubit>();
    final result = await showRecipeImportDialog(
      context,
      initialUrl: initialUrl,
    );
    if (result == null || !mounted) return;

    await cubit.addRecipe(
      title: result.title,
      url: result.url,
      sourceName: result.sourceName,
      servings: result.servings,
      imageUrl: result.imageUrl,
      ingredients: result.ingredients,
    );

    if (initialUrl != null) {
      _itemController.clear();
    }
  }

  Future<void> _editItem(BuildContext context, GroceryItem item) async {
    final cubit = context.read<ShoppingCubit>();
    final result = await showShoppingEditItemDialog(context, item: item);
    if (result == null || !mounted) return;
    await cubit.updateItemDetails(
      item.id,
      name: result.name,
      note: result.note,
      quantity: result.quantity,
      unit: result.unit,
      category: result.category,
    );
  }

  Future<void> _uncheckAllWithUndo(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ShoppingCubit>();
    final ids = await cubit.uncheckAllCompleted();
    if (ids.isEmpty || !mounted) return;
    showUndoToast(
      this.context,
      icon: Icons.undo,
      message: ids.length == 1
          ? l10n.oneItemUnchecked
          : l10n.itemsUnchecked(ids.length),
      onUndo: () => cubit.recheckItems(ids),
    );
  }

  void _shareList(BuildContext context, ShoppingState state) {
    final l10n = AppLocalizations.of(context);
    final unchecked = state.items.where((i) => !i.checked).toList();
    if (unchecked.isEmpty) return;

    String formatItemLine(GroceryItem item) {
      final qtyStr = item.quantity % 1 == 0
          ? item.quantity.toInt().toString()
          : item.quantity.toTrimmedFixed(2);
      final unitLabel = formatQuantityUnit(item.unit, item.quantity);
      final qtyPart = unitLabel != null && unitLabel.isNotEmpty
          ? '$qtyStr $unitLabel'
          : (item.quantity == 1.0 ? '' : '${qtyStr}x');
      final prefix = qtyPart.isNotEmpty ? '- $qtyPart ' : '- ';
      final notePart = (item.note != null && item.note!.isNotEmpty)
          ? ' (${item.note})'
          : '';
      return '$prefix${item.name}$notePart';
    }

    final buffer = StringBuffer('${l10n.shoppingList}\n');
    if (state.flatViewEnabled) {
      for (final item in unchecked) {
        buffer.writeln(formatItemLine(item));
      }
    } else {
      final grouped = <GroceryCategory, List<GroceryItem>>{};
      for (final item in unchecked) {
        grouped.putIfAbsent(item.category, () => []).add(item);
      }
      for (final entry in grouped.entries) {
        buffer.writeln('\n${entry.key.emoji} ${entry.key.displayName}');
        for (final item in entry.value) {
          buffer.writeln(formatItemLine(item));
        }
      }
    }

    SharePlus.instance.share(ShareParams(text: buffer.toString().trim()));
  }

  /// Soft-delete an item and offer an undo toast.
  Future<void> _deleteWithUndo(BuildContext context, String id) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ShoppingCubit>();
    final deleted = await cubit.deleteItem(id);
    if (deleted == null || !mounted) return;
    showUndoToast(
      this.context,
      icon: Icons.delete_outline,
      message: deleted.name.isEmpty
          ? l10n.itemDeleted
          : l10n.namedItemDeleted(deleted.name),
      onUndo: () => cubit.restoreItems([id]),
    );
  }

  /// Soft-delete a recipe parent container and all of its child ingredients,
  /// offering an undo toast that restores the whole group.
  Future<void> _deleteRecipeWithUndo(
    BuildContext context,
    GroceryItem recipe,
  ) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ShoppingCubit>();
    final deleted = await cubit.deleteRecipeWithChildren(recipe.id);
    if (deleted.isEmpty || !mounted) return;
    final ids = deleted.map((i) => i.id).toList();
    showUndoToast(
      this.context,
      icon: Icons.delete_outline,
      message: l10n.recipeDeleted(recipe.name),
      onUndo: () => cubit.restoreItems(ids),
    );
  }

  /// Clear all checked items and offer an undo toast.
  Future<void> _clearCheckedWithUndo(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ShoppingCubit>();
    final ids = await cubit.clearCheckedItems();
    if (ids.isEmpty || !mounted) return;
    showUndoToast(
      this.context,
      icon: Icons.playlist_remove,
      message: ids.length == 1
          ? l10n.oneItemCleared
          : l10n.itemsCleared(ids.length),
      onUndo: () => cubit.restoreItems(ids),
    );
  }

  Future<void> _openAddProductDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final service = ShoppingProductsService.instance;
    await service.init(prefs);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ShoppingAddProductDialog(productsService: service),
    );
  }

  void _openRecentlyDeleted(BuildContext context) {
    final cubit = context.read<ShoppingCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const RecentlyDeletedPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final l10n = AppLocalizations.of(context);

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
          title: Text(l10n.shoppingList),
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
              builder: (context, state) {
                final hasChecked = state.items.any((i) => i.checked);
                final hasUnchecked = state.items.any((i) => !i.checked);
                return PopupMenuButton(
                  onSelected: (value) async {
                    if (value == 'clear') {
                      _clearCheckedWithUndo(context);
                    } else if (value == 'share') {
                      _shareList(context, state);
                    } else if (value == 'recentlyDeleted') {
                      _openRecentlyDeleted(context);
                    } else if (value == 'addProduct') {
                      _openAddProductDialog(context);
                    } else if (value == 'mode') {
                      context.read<ShoppingCubit>().toggleAisleMode();
                    } else if (value == 'flat') {
                      context.read<ShoppingCubit>().toggleFlatView();
                    } else if (value == 'refresh') {
                      final messenger = ScaffoldMessenger.of(context);
                      final syncService =
                          RepositoryProvider.of<FirestoreSyncService>(context);
                      final cubit = context.read<ShoppingCubit>();
                      try {
                        await cubit.reloadItemsFromServer(syncService);
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.shoppingListReloaded)),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.failedToReload('$e'))),
                        );
                      }
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
                                ? l10n.aisleModeOn
                                : l10n.aisleModeOff,
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
                                ? l10n.flatViewOn
                                : l10n.flatViewOff,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          const Icon(Icons.refresh, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.forceReload),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      enabled: hasUnchecked,
                      child: Row(
                        children: [
                          const Icon(Icons.share, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.shareList),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clear',
                      enabled: hasChecked,
                      child: Row(
                        children: [
                          const Icon(Icons.clear_all, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.clearCheckedItems),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'recentlyDeleted',
                      child: Row(
                        children: [
                          const Icon(Icons.restore_from_trash, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.recentlyDeleted),
                          if (state.recentlyDeleted.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Badge(
                              label: Text('${state.recentlyDeleted.length}'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'addProduct',
                      child: Row(
                        children: [
                          const Icon(Icons.library_add, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.addProductToDatabase),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
                        return RefreshIndicator(
                          onRefresh: () async {
                            final syncService =
                                RepositoryProvider.of<FirestoreSyncService>(
                                  context,
                                );
                            await context
                                .read<ShoppingCubit>()
                                .reloadItemsFromServer(syncService);
                          },
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverFillRemaining(
                                child: EmptyStateWidget(
                                  icon: Icons.shopping_cart_outlined,
                                  message: l10n.noItemsYet,
                                  subMessage: l10n.noItemsSubMessage,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Partition recipe child ingredients from top-level items
                      final childrenByRecipeId = <String, List<GroceryItem>>{};
                      final topLevelItems = <GroceryItem>[];
                      for (final item in state.items) {
                        if (item.parentRecipeId != null) {
                          childrenByRecipeId
                              .putIfAbsent(item.parentRecipeId!, () => [])
                              .add(item);
                        } else {
                          topLevelItems.add(item);
                        }
                      }
                      for (final children in childrenByRecipeId.values) {
                        children.sort((a, b) {
                          if (a.checked != b.checked) {
                            return a.checked ? 1 : -1;
                          }
                          return a.createdAt.compareTo(b.createdAt);
                        });
                      }

                      final uncheckedItems = topLevelItems
                          .where((i) => !i.checked)
                          .toList();
                      final checkedItems = topLevelItems
                          .where((i) => i.checked)
                          .toList();

                      final uncheckedRecipes = uncheckedItems
                          .where((i) => i.isRecipe)
                          .toList();
                      final uncheckedStandalone = uncheckedItems
                          .where((i) => !i.isRecipe)
                          .toList();

                      final categories = <GroceryCategory, List<GroceryItem>>{};
                      for (final item in uncheckedStandalone) {
                        categories.putIfAbsent(item.category, () => []);
                        categories[item.category]!.add(item);
                      }

                      // For flat view: sort by creation time (newest first)
                      final flatSortedItems = List<GroceryItem>.from(
                        uncheckedItems,
                      )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                      return RefreshIndicator(
                        onRefresh: () async {
                          final syncService =
                              RepositoryProvider.of<FirestoreSyncService>(
                                context,
                              );
                          await context
                              .read<ShoppingCubit>()
                              .reloadItemsFromServer(syncService);
                        },
                        child: Stack(
                          children: [
                            NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification is ScrollStartNotification ||
                                    notification is UserScrollNotification) {
                                  FocusScope.of(context).unfocus();
                                }
                                return false;
                              },
                              child: CustomScrollView(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
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
                                        return _buildTileForItem(
                                          context,
                                          item,
                                          childrenByRecipeId,
                                          state.aisleModeEnabled,
                                        );
                                      }, childCount: flatSortedItems.length),
                                    )
                                  else ...[
                                    // Dedicated Recipes section at top in Category View
                                    if (uncheckedRecipes.isNotEmpty)
                                      _buildRecipesSection(
                                        context,
                                        uncheckedRecipes,
                                        childrenByRecipeId,
                                        state.aisleModeEnabled,
                                      ),
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
                                  ],

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
                                  if (checkedItems.isNotEmpty &&
                                      _completedExpanded)
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => _buildTileForItem(
                                          context,
                                          checkedItems[index],
                                          childrenByRecipeId,
                                          state.aisleModeEnabled,
                                          initiallyExpanded: false,
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
                                      setState(
                                        () => _showScrollDownFab = false,
                                      );
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
                              bottom: 16,
                              child: AnimatedSlide(
                                duration: _fabAnimDur,
                                offset: _showScrollUpFab
                                    ? Offset.zero
                                    : const Offset(0, 1),
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
    return BlocBuilder<ShoppingCubit, ShoppingState>(
      buildWhen: (prev, curr) =>
          prev.selectedCategory != curr.selectedCategory ||
          prev.suggestedText != curr.suggestedText ||
          prev.suggestionConfidence != curr.suggestionConfidence ||
          prev.manualCategoryOverride != curr.manualCategoryOverride,
      builder: (context, state) {
        final l10n = AppLocalizations.of(context);
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
              currentText + displaySuggestedText.substring(currentLower.length);
          if (_ghostController.text != displaySuggestedText) {
            _ghostController.text = displaySuggestedText;
          }
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
                        controller: _ghostController,
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
                              hintText: l10n.addItem,
                              suffixText: showGhost
                                  ? null
                                  : l10n.inCategory(
                                      state.selectedCategory.displayName,
                                    ),
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
                          onPressed: () => _importRecipe(context),
                          icon: const Icon(Icons.restaurant_menu),
                          tooltip: l10n.importRecipe,
                        ),
                        const SizedBox(width: 6),
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
                                await context.read<ShoppingCubit>().addItems(
                                  confirmedItems,
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.playlist_add),
                          tooltip: l10n.bulkAdd,
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

  Widget _buildTileForItem(
    BuildContext context,
    GroceryItem item,
    Map<String, List<GroceryItem>> childrenByRecipeId,
    bool aisleMode, {
    bool initiallyExpanded = true,
  }) {
    if (item.isRecipe) {
      return RecipeShoppingListTile(
        recipe: item,
        ingredients: childrenByRecipeId[item.id] ?? const [],
        aisleMode: aisleMode,
        initiallyExpanded: initiallyExpanded,
        onToggleRecipe: () => context.read<ShoppingCubit>().toggleItem(item.id),
        onDeleteRecipe: () => _deleteRecipeWithUndo(context, item),
        onToggleIngredient: (ing) =>
            context.read<ShoppingCubit>().toggleItem(ing.id),
        onDeleteIngredient: (ing) => _deleteWithUndo(context, ing.id),
        onIngredientQuantity: (ing) =>
            context.read<ShoppingCubit>().cycleQuantity(ing.id),
        onIngredientQuantityLongPress: (ing) async {
          final newQtyUnit = await showQuantityPickerDialog(
            context,
            currentQuantity: ing.quantity,
            currentUnit: ing.unit,
          );
          if (newQtyUnit != null && context.mounted) {
            context.read<ShoppingCubit>().updateQuantityAndUnit(
              ing.id,
              newQtyUnit.$1,
              newQtyUnit.$2,
            );
          }
        },
        onIngredientLongPress: (ing) => _editItem(context, ing),
      );
    }

    return ShoppingListItemTile(
      item: item,
      aisleMode: aisleMode,
      onCheck: () => context.read<ShoppingCubit>().toggleItem(item.id),
      onDelete: () => _deleteWithUndo(context, item.id),
      onQuantity: () => context.read<ShoppingCubit>().cycleQuantity(item.id),
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
      onLongPress: () => _editItem(context, item),
    );
  }

  Widget _buildRecipesSection(
    BuildContext context,
    List<GroceryItem> recipes,
    Map<String, List<GroceryItem>> childrenByRecipeId,
    bool aisleMode,
  ) {
    final l10n = AppLocalizations.of(context);
    return SliverMainAxisGroup(
      slivers: [
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
                    '🍳',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.recipesSectionTitle,
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
                      recipes.length.toString(),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return _buildTileForItem(
              context,
              recipes[index],
              childrenByRecipeId,
              aisleMode,
            );
          }, childCount: recipes.length),
        ),
      ],
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
              onDelete: () => _deleteWithUndo(context, item.id),
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
              onLongPress: () => _editItem(context, item),
            );
          }, childCount: items.length),
        ),
      ],
    );
  }

  Widget _buildCompletedHeader(int count) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: _toggleCompletedExpanded,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.completedCount(count),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _uncheckAllWithUndo(context),
                child: Text(l10n.uncheckAll),
              ),
              Icon(
                _completedExpanded ? Icons.expand_less : Icons.expand_more,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
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
