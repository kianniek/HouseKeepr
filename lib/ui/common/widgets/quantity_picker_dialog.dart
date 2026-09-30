import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:housekeepr/core/extensions.dart';

/// Shows a dialog for picking a quantity with +/- buttons and a unit selection.
/// Returns a record with the selected quantity and unit, or null if cancelled.
Future<(double, String?)?> showQuantityPickerDialog(
  BuildContext context, {
  required double currentQuantity,
  String? currentUnit,
  double min = 0.5,
  double max = double.maxFinite,
}) {
  return showDialog<(double, String?)>(
    context: context,
    builder: (dialogContext) {
      return _QuantityPickerDialog(
        initialQuantity: currentQuantity,
        initialUnit: currentUnit,
        min: min,
        max: max,
      );
    },
  );
}

const List<String> commonUnits = [
  'g',
  'kg',
  'ml',
  'L',
  'el',
  'tl',
  'stuks',
  'pot',
  'pak',
  'blik',
  'fles',
  'zak',
];

class _QuantityPickerDialog extends StatefulWidget {
  final double initialQuantity;
  final String? initialUnit;
  final double min;
  final double max;

  const _QuantityPickerDialog({
    required this.initialQuantity,
    this.initialUnit,
    required this.min,
    required this.max,
  });

  @override
  State<_QuantityPickerDialog> createState() => _QuantityPickerDialogState();
}

class _QuantityPickerDialogState extends State<_QuantityPickerDialog> {
  late double _quantity;
  String? _unit;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity.clamp(widget.min, widget.max);
    _unit = widget.initialUnit;
    if (_unit != null && _unit!.trim().isEmpty) {
      _unit = null;
    }
  }

  void _increment() {
    if (_quantity < widget.max) {
      HapticFeedback.lightImpact();
      setState(() => _quantity += 1);
    }
  }

  void _decrement() {
    if (_quantity > widget.min) {
      HapticFeedback.lightImpact();
      setState(() => _quantity -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If there's a custom unit not in commonUnits, add it.
    final dropdownItems = <String?>[null, ...commonUnits];
    if (_unit != null && !commonUnits.contains(_unit)) {
      dropdownItems.add(_unit);
    }

    return AlertDialog(
      title: const Text('Set Quantity & Unit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Decrement button
              IconButton.filled(
                onPressed: _quantity > widget.min ? _decrement : null,
                icon: const Icon(Icons.remove),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  disabledBackgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 24),
              // Quantity display
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer,
                ),
                child: Center(
                  child: Text(
                    _quantity == _quantity.floorToDouble()
                        ? _quantity.toInt().toString()
                        : _quantity.toTrimmedFixed(1),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Increment button
              IconButton.filled(
                onPressed: _quantity < widget.max ? _increment : null,
                icon: const Icon(Icons.add),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  disabledBackgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String?>(
            initialValue: _unit,
            decoration: const InputDecoration(
              labelText: 'Unit',
              border: OutlineInputBorder(),
            ),
            items: dropdownItems.map((unitStr) {
              return DropdownMenuItem<String?>(
                value: unitStr,
                child: Text(unitStr ?? 'None'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _unit = val;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_quantity, _unit)),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
