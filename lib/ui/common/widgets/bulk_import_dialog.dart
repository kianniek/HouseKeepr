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
    return input
        .split(RegExp(r'[\n,]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((line) => GroceryParser.parseLine(line))
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
            hintText: 'e.g. 1 middelgrote ui\n1 teenknoflook\n...',
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
