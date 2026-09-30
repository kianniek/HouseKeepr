import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../cubits/shopping_cubit.dart';
import '../../../../models/grocery_category.dart';

Future<void> showShoppingAddDialog(BuildContext context) {
  final nameCtl = TextEditingController();
  final catCtl = TextEditingController();
  return showDialog(
    context: context,
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
                  autofocus: true,
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
                        final name = nameCtl.text.trim();
                        final cat = catCtl.text.isEmpty
                            ? GroceryCategory.other
                            : GroceryCategory.fromString(catCtl.text.trim());

                        // Use the outer context to find the cubit
                        context.read<ShoppingCubit>().addItem(
                          name,
                          category: cat,
                        );
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
