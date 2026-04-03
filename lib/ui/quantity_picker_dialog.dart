import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a dialog for picking a quantity with +/- buttons.
/// Returns the selected quantity, or null if cancelled.
Future<int?> showQuantityPickerDialog(
  BuildContext context, {
  required int currentQuantity,
  int min = 1,
  int max = 99,
}) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return _QuantityPickerDialog(
        initialQuantity: currentQuantity,
        min: min,
        max: max,
      );
    },
  );
}

class _QuantityPickerDialog extends StatefulWidget {
  final int initialQuantity;
  final int min;
  final int max;

  const _QuantityPickerDialog({
    required this.initialQuantity,
    required this.min,
    required this.max,
  });

  @override
  State<_QuantityPickerDialog> createState() => _QuantityPickerDialogState();
}

class _QuantityPickerDialogState extends State<_QuantityPickerDialog> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity.clamp(widget.min, widget.max);
  }

  void _increment() {
    if (_quantity < widget.max) {
      HapticFeedback.lightImpact();
      setState(() => _quantity++);
    }
  }

  void _decrement() {
    if (_quantity > widget.min) {
      HapticFeedback.lightImpact();
      setState(() => _quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Set Quantity'),
      content: Row(
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
                _quantity.toString(),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _quantity),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
