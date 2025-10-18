import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../cubits/shopping_cubit.dart';
import '../models/shopping_item.dart';

class ShoppingPage extends StatelessWidget {
  const ShoppingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShoppingCubit, ShoppingState>(
      builder: (context, state) {
        return Scaffold(
          body: state.items.isEmpty
              ? const Center(child: Text('No shopping items'))
              : ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, idx) {
                    final it = state.items[idx];
                    return Dismissible(
                      key: ValueKey(it.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        context.read<ShoppingCubit>().deleteItem(it.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted "${it.name}"'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () {
                                context.read<ShoppingCubit>().addItem(it);
                              },
                            ),
                          ),
                        );
                      },
                      child: ListTile(
                        title: Text(it.name),
                        subtitle: it.category != null
                            ? Text(it.category!)
                            : null,
                        leading: Checkbox(
                          value: it.inCart,
                          onChanged: (v) => context
                              .read<ShoppingCubit>()
                              .updateItem(it.copyWith(inCart: v ?? false)),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () =>
                              context.read<ShoppingCubit>().deleteItem(it.id),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtl = TextEditingController();
    final catCtl = TextEditingController();
    showDialog(
      context: context,
      // Use a different name for the builder context so we don't shadow the
      // outer `context` parameter. The outer context contains the
      // BlocProvider<ShoppingCubit>, so we must keep it available when
      // calling `context.read<ShoppingCubit>()`.
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            bool canAdd() => nameCtl.text.trim().isNotEmpty;
            nameCtl.addListener(() => setState(() {}));
            return AlertDialog(
              title: const Text('New Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: catCtl,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canAdd()
                      ? () {
                          final id = const Uuid().v4();
                          final item = ShoppingItem(
                            id: id,
                            name: nameCtl.text.trim(),
                            category: catCtl.text.isEmpty ? null : catCtl.text,
                          );
                          // Use the outer `context` (the page's context) to access
                          // the ShoppingCubit provider that was provided above
                          // the page. The dialog's context does not include the
                          // provider and would throw ProviderNotFoundException.
                          context.read<ShoppingCubit>().addItem(item);
                          Navigator.pop(dialogContext);
                        }
                      : null,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
