import 'package:flutter/material.dart';
import 'package:housekeepr/core/extensions.dart';
import '../../../core/grocery_parser.dart';
import '../../../models/grocery_category.dart';

Future<List<ParsedGroceryItem>?> showBulkImportConfirmationDialog(
  BuildContext context,
  List<ParsedGroceryItem> items,
) {
  return showDialog<List<ParsedGroceryItem>>(
    context: context,
    builder: (context) => _BulkImportConfirmationDialog(items: items),
  );
}

class _BulkImportConfirmationDialog extends StatefulWidget {
  final List<ParsedGroceryItem> items;

  const _BulkImportConfirmationDialog({required this.items});

  @override
  State<_BulkImportConfirmationDialog> createState() =>
      _BulkImportConfirmationDialogState();
}

class _BulkImportConfirmationDialogState
    extends State<_BulkImportConfirmationDialog> {
  late List<ParsedGroceryItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  void _updateCategory(int index, GroceryCategory newCategory) {
    setState(() {
      _items[index] = _items[index].copyWith(category: newCategory);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review Items'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _items.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final item = _items[index];
            final qtyStr = item.quantity == item.quantity.floorToDouble()
                ? item.quantity.toInt().toString()
                : item.quantity.toTrimmedFixed(1);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              subtitle: Text('$qtyStr ${item.unit ?? ''}'.trim()),
              trailing: DropdownButton<GroceryCategory>(
                value: item.category,
                underline: const SizedBox(),
                items: GroceryCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat.name.split('.').last),
                  );
                }).toList(),
                onChanged: (cat) {
                  if (cat != null) {
                    _updateCategory(index, cat);
                  }
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _items),
          child: const Text('Add All'),
        ),
      ],
    );
  }
}
