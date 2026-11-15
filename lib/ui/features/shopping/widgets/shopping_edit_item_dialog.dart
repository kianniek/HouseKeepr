import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/extensions.dart';
import '../../../../core/quantity_unit_formatter.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../models/grocery_category.dart';
import '../../../../models/grocery_item.dart';
import '../../../common/widgets/quantity_picker_dialog.dart';

class ShoppingEditResult {
  final String name;
  final String? note;
  final double quantity;
  final String? unit;
  final GroceryCategory category;

  const ShoppingEditResult({
    required this.name,
    this.note,
    required this.quantity,
    this.unit,
    required this.category,
  });
}

Future<ShoppingEditResult?> showShoppingEditItemDialog(
  BuildContext context, {
  required GroceryItem item,
}) {
  return showDialog<ShoppingEditResult>(
    context: context,
    builder: (_) => _ShoppingEditItemDialog(item: item),
  );
}

class _ShoppingEditItemDialog extends StatefulWidget {
  final GroceryItem item;

  const _ShoppingEditItemDialog({required this.item});

  @override
  State<_ShoppingEditItemDialog> createState() =>
      _ShoppingEditItemDialogState();
}

class _ShoppingEditItemDialogState extends State<_ShoppingEditItemDialog> {
  static const double _minQty = 0.5;

  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late double _quantity;
  String? _unit;
  late GroceryCategory _category;
  bool _showNameError = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _noteController = TextEditingController(text: widget.item.note ?? '');
    _quantity = widget.item.quantity.clamp(_minQty, double.maxFinite);
    final rawUnit = widget.item.unit?.trim();
    _unit = (rawUnit == null || rawUnit.isEmpty) ? null : rawUnit;
    _category = widget.item.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _increment() {
    HapticFeedback.lightImpact();
    setState(() => _quantity += 1);
  }

  void _decrement() {
    if (_quantity > _minQty) {
      HapticFeedback.lightImpact();
      setState(() => _quantity = (_quantity - 1).clamp(_minQty, double.maxFinite));
    }
  }

  void _save() {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _showNameError = true);
      return;
    }
    final trimmedNote = _noteController.text.trim();
    Navigator.of(context).pop(
      ShoppingEditResult(
        name: trimmedName,
        note: trimmedNote.isEmpty ? null : trimmedNote,
        quantity: _quantity,
        unit: _unit,
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final unitItems = <String?>[null, ...commonUnits];
    if (_unit != null && !commonUnits.contains(_unit)) {
      unitItems.add(_unit);
    }

    return AlertDialog(
      title: Text(l10n.editItem),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.itemName,
                errorText: _showNameError ? l10n.itemNameRequired : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_showNameError) {
                  setState(() => _showNameError = false);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: l10n.noteOptional,
                hintText: l10n.noteHint,
                border: const OutlineInputBorder(),
                suffixIcon: _noteController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _noteController.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text(l10n.quantity, style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _quantity > _minQty ? _decrement : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _quantity == _quantity.floorToDouble()
                        ? _quantity.toInt().toString()
                        : _quantity.toTrimmedFixed(1),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _increment,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _unit,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.unit,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: unitItems.map((u) {
                      final label = u == null
                          ? l10n.none
                          : (formatQuantityUnit(u, _quantity) ?? u);
                      return DropdownMenuItem<String?>(
                        value: u,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _unit = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<GroceryCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.category,
                border: const OutlineInputBorder(),
              ),
              items: GroceryCategory.values
                  .map(
                    (cat) => DropdownMenuItem<GroceryCategory>(
                      value: cat,
                      child: Text('${cat.emoji} ${cat.displayName}'),
                    ),
                  )
                  .toList(),
              onChanged: (cat) {
                if (cat != null) {
                  setState(() => _category = cat);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
