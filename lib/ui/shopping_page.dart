import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cubits/shopping_cubit_v2.dart';
import '../models/grocery_item.dart';
import '../models/grocery_category.dart';
import '../services/shopping_products_service.dart';
import 'shopping_add_product_dialog.dart';

/// Extension to handle "Pascal Case with spaces" formatting
extension StringFormatting on String {
  String toTitleCase() {
    if (isEmpty) return this;
    return split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  late ShoppingProductsService _productsService;
  bool _serviceInitialized = false;
  String? _initError;

  void _log(String message) {
    // ignore: avoid_print
    print('[ShoppingPage] $message');
  }

  @override
  void initState() {
    super.initState();
    _initializeProductsService();
  }

  Future<void> _initializeProductsService() async {
    setState(() {
      _serviceInitialized = false;
      _initError = null;
    });
    try {
      _log('Starting products service initialization...');
      final prefs = await SharedPreferences.getInstance();
      _productsService = ShoppingProductsService.instance;
      await _productsService.init(prefs);

      if (!mounted) return;
      setState(() {
        _serviceInitialized = true;
      });
      _log('Service initialization complete');
    } catch (e, st) {
      _log('Failed to initialize: $e');
      if (!mounted) return;
      setState(() {
        _serviceInitialized = true;
        _initError = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_serviceInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shopping List')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to initialize products service.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _initializeProductsService,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return BlocBuilder<ShoppingCubit, ShoppingState>(
      builder: (context, state) {
        final items = state.items;
        final pending = items.where((i) => !i.checked).toList();
        final completed = items.where((i) => i.checked).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Shopping List'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showManageProductsDialog(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pending.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'To Buy (${pending.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildPendingItemsSection(context, pending),
                ],
                if (completed.isNotEmpty) ...[
                  const Divider(),
                  ExpansionTile(
                    title: Text('Completed (${completed.length})'),
                    children: [_buildCompletedItemsSection(context, completed)],
                  ),
                ],
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No items yet. Press + to add.')),
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addNewItem(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildPendingItemsSection(BuildContext context, List<dynamic> items) {
    final grouped = <String, List<GroceryItem>>{};

    for (var item in items) {
      final shoppingItem = item as GroceryItem;
      // APPLY TITLE CASE HERE:
      final category = shoppingItem.category.displayName.toTitleCase();

      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(shoppingItem);
    }

    final sortedCategories = grouped.keys.toList()..sort();
    final children = <Widget>[];

    for (final category in sortedCategories) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              const Divider(height: 1),
            ],
          ),
        ),
      );

      final categoryItems = grouped[category]!;
      for (int i = 0; i < categoryItems.length; i++) {
        children.add(
          _buildShoppingItemTile(context, categoryItems[i], i, categoryItems),
        );
      }
    }

    return Column(children: children);
  }

  Widget _buildCompletedItemsSection(
    BuildContext context,
    List<dynamic> items,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _buildCompletedItemTile(context, items[index] as GroceryItem),
    );
  }

  Widget _buildShoppingItemTile(
    BuildContext context,
    GroceryItem item,
    int index,
    List<dynamic> allItems,
  ) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      onDismissed: (_) {
        context.read<ShoppingCubit>().deleteItem(item.id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.drag_handle, size: 20),
              ),
            ),
            Checkbox(
              value: item.checked,
              onChanged: (v) =>
                  context.read<ShoppingCubit>().toggleItem(item.id),
            ),
            Expanded(
              child: _ShoppingItemTextField(
                item: item,
                onChanged: (newName) {
                  if (newName.isNotEmpty) {
                    context.read<ShoppingCubit>().updateItemName(
                      item.id,
                      newName,
                    );
                  }
                },
                onReturn: () => _addNewItem(context),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () =>
                  context.read<ShoppingCubit>().deleteItem(item.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedItemTile(BuildContext context, GroceryItem item) {
    return ListTile(
      leading: Checkbox(
        value: true,
        onChanged: (v) => context.read<ShoppingCubit>().toggleItem(item.id),
      ),
      title: Text(
        item.name,
        style: const TextStyle(decoration: TextDecoration.lineThrough),
      ),
    );
  }

  void _addNewItem(BuildContext context) {
    context.read<ShoppingCubit>().addItem('');
  }

  void _showManageProductsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) =>
          ShoppingAddProductDialog(productsService: _productsService),
    );
  }
}

class _ShoppingItemTextField extends StatefulWidget {
  final GroceryItem item;
  final Function(String) onChanged;
  final Function() onReturn;

  const _ShoppingItemTextField({
    required this.item,
    required this.onChanged,
    required this.onReturn,
  });

  @override
  State<_ShoppingItemTextField> createState() => _ShoppingItemTextFieldState();
}

class _ShoppingItemTextFieldState extends State<_ShoppingItemTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.name);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      onSubmitted: (_) {
        _controller.clear();
        widget.onReturn();
        _focusNode.requestFocus();
      },
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: 'Item name...',
      ),
    );
  }
}
