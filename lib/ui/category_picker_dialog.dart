import 'package:flutter/material.dart';

import '../models/grocery_category.dart';

Future<GroceryCategory?> showCategoryPickerDialog(
  BuildContext context, {
  required GroceryCategory currentCategory,
}) {
  return showDialog<GroceryCategory>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Change category'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GroceryCategory.values.map((cat) {
                final selected = cat == currentCategory;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat.emoji),
                      const SizedBox(width: 8),
                      Text(
                        cat.displayName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  selected: selected,
                  onSelected: (sel) {
                    if (sel) Navigator.of(context).pop(cat);
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}
