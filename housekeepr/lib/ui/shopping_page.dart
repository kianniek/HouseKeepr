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
                    return ListTile(
                      title: Text(it.name),
                      subtitle: it.category != null ? Text(it.category!) : null,
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
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final id = const Uuid().v4();
                final item = ShoppingItem(
                  id: id,
                  name: nameCtl.text,
                  category: catCtl.text.isEmpty ? null : catCtl.text,
                );
                context.read<ShoppingCubit>().addItem(item);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
