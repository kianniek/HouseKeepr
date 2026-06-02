import 'package:equatable/equatable.dart';
import '../models/grocery_category.dart';

class ParsedGroceryItem extends Equatable {
  final String name;
  final double quantity;
  final String? unit;
  final GroceryCategory category;

  const ParsedGroceryItem({
    required this.name,
    required this.quantity,
    this.unit,
    required this.category,
  });

  @override
  List<Object?> get props => [name, quantity, unit, category];

  ParsedGroceryItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    GroceryCategory? category,
  }) {
    return ParsedGroceryItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
    );
  }
}

class GroceryParser {
  static final RegExp _amountRegex = RegExp(
    r'^((?:\d+\.)?\d+)?\s*(g|kg|ml|l|el|tl|teen|stuks|pot|pak|blik|fles|zak|middelgrote)?\s*(.*)$',
    caseSensitive: false,
  );

  static ParsedGroceryItem parseLine(String line) {
    String processed = line.trim();

    // Replace fractions
    processed = processed.replaceAll('½', '1.5');
    processed = processed.replaceAll('¼', '0.25');
    processed = processed.replaceAll('¾', '0.75');
    processed = processed.replaceAll('⅓', '0.33');
    processed = processed.replaceAll('⅔', '0.67');

    final match = _amountRegex.firstMatch(processed);

    if (match != null) {
      final String? qtyStr = match.group(1);
      final String? unitStr = match.group(2);
      final String nameStr = match.group(3) ?? processed;

      double qty = 1.0;
      if (qtyStr != null && qtyStr.isNotEmpty) {
        qty = double.tryParse(qtyStr) ?? 1.0;
      }

      String? unit;
      if (unitStr != null && unitStr.isNotEmpty) {
        unit = unitStr.toLowerCase();
      }

      String name = nameStr.trim();
      if (name.isEmpty && unitStr != null) {
        // e.g. if the user just typed "10", without name or unit.
        name = unitStr;
        unit = null;
      }

      return ParsedGroceryItem(
        name: name,
        quantity: qty,
        unit: unit,
        category: _guessCategory(name),
      );
    }

    return ParsedGroceryItem(
      name: processed,
      quantity: 1.0,
      unit: null,
      category: _guessCategory(processed),
    );
  }

  static GroceryCategory _guessCategory(String name) {
    final lowerName = name.toLowerCase();

    if (lowerName.contains('melk') ||
        lowerName.contains('boter') ||
        lowerName.contains('parmigiano') ||
        lowerName.contains('kaas') ||
        lowerName.contains('yoghurt')) {
      return GroceryCategory.dairy;
    }
    if (lowerName.contains('ui') ||
        lowerName.contains('knoflook') ||
        lowerName.contains('winterpenen') ||
        lowerName.contains('bleekselderij') ||
        lowerName.contains('appel') ||
        lowerName.contains('banaan')) {
      return GroceryCategory.vegetables; // maps to produce
    }
    if (lowerName.contains('gehakt') ||
        lowerName.contains('spekreepjes') ||
        lowerName.contains('vlees') ||
        lowerName.contains('kip') ||
        lowerName.contains('vis')) {
      return GroceryCategory.meat;
    }
    if (lowerName.contains('brood')) {
      return GroceryCategory.bakery;
    }

    return GroceryCategory.other; // maps to pantry/other
  }
}
