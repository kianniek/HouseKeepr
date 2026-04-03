import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../cubits/shopping_cubit.dart';
import '../models/shopping_item.dart';

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
                        final id = const Uuid().v4();
                        final item = ShoppingItem(
                          id: id,
                          name: nameCtl.text.trim(),
                          category: catCtl.text.isEmpty ? null : catCtl.text,
                        );
                        // Use the outer context to find the cubit
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
