import 'package:flutter/material.dart';
import '../../../core/grocery_parser.dart';

Future<List<ParsedGroceryItem>?> showBulkImportDialog(BuildContext context) {
  return showDialog<List<ParsedGroceryItem>>(
    context: context,
    builder: (context) => const _BulkImportDialog(),
  );
}

class _BulkImportDialog extends StatefulWidget {
  const _BulkImportDialog();

  @override
  State<_BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<_BulkImportDialog> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onNext() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    final parsedItems = _parseInput(text);
    if (parsedItems.isEmpty) return;

    Navigator.pop(context, parsedItems);
  }

  List<ParsedGroceryItem> _parseInput(String input) {
    final lines = input.split(RegExp(r'\r?\n'));
    final rawItems = <String>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // If the entire input is on a single line and has comma separation:
      if (lines.length == 1 && line.contains(',')) {
        // Split by commas not preceded or followed by digits to preserve decimals like 1,5 kg
        final parts = line.split(RegExp(r'(?<!\d),(?!\d)'));
        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty) rawItems.add(trimmed);
        }
      } else {
        rawItems.add(line);
      }
    }

    return rawItems
        .map((line) => GroceryParser.parseLine(line))
        .where((item) => item.name.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bulk Import Groceries'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _textController,
          maxLines: 10,
          minLines: 5,
          decoration: const InputDecoration(
            hintText:
                'e.g.\n2 pakken melk\n1,5 kg appels\n2 tenen knoflook\n500g gehakt',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _onNext, child: const Text('Next')),
      ],
    );
  }
}
