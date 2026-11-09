import 'package:equatable/equatable.dart';
import '../models/grocery_category.dart';
import '../services/shopping_products_service.dart';

class ParsedGroceryItem extends Equatable {
  final String name;
  final double quantity;
  final String? unit;
  final GroceryCategory category;
  final String? note;

  const ParsedGroceryItem({
    required this.name,
    required this.quantity,
    this.unit,
    required this.category,
    this.note,
  });

  @override
  List<Object?> get props => [name, quantity, unit, category, note];

  ParsedGroceryItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    GroceryCategory? category,
    String? note,
  }) {
    return ParsedGroceryItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      note: note ?? this.note,
    );
  }
}

class GroceryParser {
  static const Map<String, String> _unitMap = {
    // Mass
    'kilogrammen': 'kg',
    'kilogram': 'kg',
    'kilo\'s': 'kg',
    'kilos': 'kg',
    'kilo': 'kg',
    'kg': 'kg',
    'grammen': 'g',
    'gram': 'g',
    'grams': 'g',
    'gr.': 'g',
    'gr': 'g',
    'g': 'g',
    'milligrammen': 'mg',
    'milligram': 'mg',
    'milligrams': 'mg',
    'mg': 'mg',
    'pond': 'pond',
    'ons': 'ons',

    // Volume
    'milliliters': 'ml',
    'milliliter': 'ml',
    'ml': 'ml',
    'centiliters': 'cl',
    'centiliter': 'cl',
    'cl': 'cl',
    'deciliters': 'dl',
    'deciliter': 'dl',
    'dl': 'dl',
    'liters': 'l',
    'liter': 'l',
    'litres': 'l',
    'litre': 'l',
    'ltr': 'l',
    'l': 'l',

    // Kitchen
    'eetlepels': 'el',
    'eetlepel': 'el',
    'tablespoons': 'el',
    'tablespoon': 'el',
    'tbsp': 'el',
    'tbs': 'el',
    'el': 'el',
    'theelepels': 'tl',
    'theelepel': 'tl',
    'teaspoons': 'tl',
    'teaspoon': 'tl',
    'tsp': 'tl',
    'tl': 'tl',
    'mespuntjes': 'snufje',
    'mespuntje': 'snufje',
    'mespunt': 'snufje',
    'snufjes': 'snufje',
    'snufje': 'snufje',
    'snuf': 'snufje',
    'pinches': 'snufje',
    'pinch': 'snufje',
    'kopjes': 'kopje',
    'kopje': 'kopje',
    'koppen': 'kopje',
    'kop': 'kopje',
    'cups': 'kopje',
    'cup': 'kopje',

    // Packaging & containers
    'pakken': 'pak',
    'pakje': 'pak',
    'pakjes': 'pak',
    'packages': 'pak',
    'package': 'pak',
    'packets': 'pak',
    'packet': 'pak',
    'packs': 'pak',
    'pack': 'pak',
    'pak': 'pak',

    'flessen': 'fles',
    'flesje': 'fles',
    'flesjes': 'fles',
    'bottles': 'fles',
    'bottle': 'fles',
    'fles': 'fles',

    'blikken': 'blik',
    'blikje': 'blik',
    'blikjes': 'blik',
    'cans': 'blik',
    'can': 'blik',
    'tins': 'blik',
    'tin': 'blik',
    'blik': 'blik',

    'potten': 'pot',
    'potje': 'pot',
    'potjes': 'pot',
    'jars': 'pot',
    'jar': 'pot',
    'pot': 'pot',

    'zakken': 'zak',
    'zakje': 'zak',
    'zakjes': 'zak',
    'bags': 'zak',
    'bag': 'zak',
    'zak': 'zak',

    'dozen': 'doos',
    'doosje': 'doos',
    'doosjes': 'doos',
    'boxes': 'doos',
    'box': 'doos',
    'doos': 'doos',

    'bakjes': 'bakje',
    'bakje': 'bakje',
    'bakken': 'bakje',
    'bak': 'bakje',
    'tubs': 'bakje',
    'tub': 'bakje',
    'containers': 'bakje',
    'container': 'bakje',

    'rollen': 'rol',
    'rolletje': 'rol',
    'rolletjes': 'rol',
    'rolls': 'rol',
    'roll': 'rol',
    'rol': 'rol',

    'repen': 'reep',
    'reepje': 'reep',
    'reepjes': 'reep',
    'bars': 'reep',
    'bar': 'reep',
    'reep': 'reep',

    'vellen': 'vel',
    'velletje': 'vel',
    'velletjes': 'vel',
    'sheets': 'vel',
    'sheet': 'vel',
    'vel': 'vel',

    'kuipjes': 'kuipje',
    'kuipje': 'kuipje',

    // Countables
    'teentjes': 'teen',
    'teentje': 'teen',
    'tenen': 'teen',
    'teen': 'teen',
    'cloves': 'teen',
    'clove': 'teen',

    'stuks': 'stuk',
    'stuk': 'stuk',
    'st.': 'stuk',
    'st': 'stuk',
    'pieces': 'stuk',
    'piece': 'stuk',
    'pcs': 'stuk',
    'pc': 'stuk',

    'plakken': 'plak',
    'plakjes': 'plak',
    'plakje': 'plak',
    'plak': 'plak',
    'sneden': 'plak',
    'sneetjes': 'plak',
    'sneetje': 'plak',
    'snee': 'plak',
    'slices': 'plak',
    'slice': 'plak',

    'bossen': 'bosje',
    'bosjes': 'bosje',
    'bosje': 'bosje',
    'bos': 'bosje',
    'bunches': 'bosje',
    'bunch': 'bosje',

    'kroppen': 'krop',
    'krop': 'krop',
    'heads': 'krop',
    'head': 'krop',

    'stengels': 'stengel',
    'stengel': 'stengel',
    'stalks': 'stengel',
    'stalk': 'stengel',

    'trossen': 'tros',
    'tros': 'tros',
  };

  static final String _unitPattern = () {
    final keys = _unitMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return keys.map(RegExp.escape).join('|');
  }();

  static final String _wordUnitsPattern = () {
    const excluded = {
      'kg',
      'mg',
      'ml',
      'cl',
      'dl',
      'el',
      'tl',
      'st',
      'pc',
      'gr',
      'g',
      'l',
      'ons',
      'pond',
    };
    final keys =
        _unitMap.keys
            .where((k) => k.length >= 3 && !excluded.contains(k))
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    return keys.map(RegExp.escape).join('|');
  }();

  static final RegExp _leadBulletRegex = RegExp(
    r'^(?:[-*•+]|\d+[\.\)]|\[[ xX]?\])\s+',
  );

  static double _parseNum(String? str) {
    if (str == null || str.isEmpty) return 1.0;
    final normalized = str.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 1.0;
  }

  static String _normalizeFractions(String input) {
    var s = input;

    // Mixed unicode fractions (e.g. "1 ½" -> "1.5")
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*½'), (m) => '${m[1]}.5');
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*¼'), (m) => '${m[1]}.25');
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*¾'), (m) => '${m[1]}.75');
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*⅓'), (m) => '${m[1]}.33');
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*⅔'), (m) => '${m[1]}.67');
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*⅛'), (m) => '${m[1]}.125');
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*⅜'), (m) => '${m[1]}.375');
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*⅝'), (m) => '${m[1]}.625');
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*⅞'), (m) => '${m[1]}.875');

    // Standalone unicode fractions
    s = s.replaceAll('½', '0.5');
    s = s.replaceAll('¼', '0.25');
    s = s.replaceAll('¾', '0.75');
    s = s.replaceAll('⅓', '0.33');
    s = s.replaceAll('⅔', '0.67');
    s = s.replaceAll('⅛', '0.125');
    s = s.replaceAll('⅜', '0.375');
    s = s.replaceAll('⅝', '0.625');
    s = s.replaceAll('⅞', '0.875');

    // Mixed slash fractions at start (e.g. "1 1/2" -> "1.5")
    s = s.replaceAllMapped(RegExp(r'^(\d+)\s+(\d+)\s*/\s*(\d+)\b'), (m) {
      final whole = double.tryParse(m[1]!) ?? 0;
      final num = double.tryParse(m[2]!) ?? 0;
      final den = double.tryParse(m[3]!) ?? 1;
      final val = den != 0 ? whole + (num / den) : whole;
      return val.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    });

    // Standalone slash fractions at start (e.g. "1/2" -> "0.5")
    s = s.replaceAllMapped(RegExp(r'^(\d+)\s*/\s*(\d+)\b'), (m) {
      final num = double.tryParse(m[1]!) ?? 0;
      final den = double.tryParse(m[2]!) ?? 1;
      final val = den != 0 ? num / den : 0.0;
      return val.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    });

    return s;
  }

  static ParsedGroceryItem parseLine(String line) {
    var processed = line.trim();
    if (processed.isEmpty) {
      return const ParsedGroceryItem(
        name: '',
        quantity: 1.0,
        unit: null,
        category: GroceryCategory.other,
      );
    }

    processed = processed.replaceFirst(_leadBulletRegex, '').trim();
    processed = _normalizeFractions(processed);

    double qty = 1.0;
    String? unit;
    String rawName = processed;
    String? note;

    // Check compound garlic: "1 teenknoflook", "2 tenen knoflook", "1 knoflookteen"
    final garlicCompoundMatch = RegExp(
      r'^(\d+(?:[\.,]\d+)?)\s*(?:x\s*)?(?:teen|tenen|teentjes?)\s*knoflook$',
      caseSensitive: false,
    ).firstMatch(processed);

    final garlicReverseMatch = RegExp(
      r'^(\d+(?:[\.,]\d+)?)\s*(?:x\s*)?knoflook\s*(?:teen|tenen|teentjes?)$',
      caseSensitive: false,
    ).firstMatch(processed);

    final startWithUnitRegex = RegExp(
      r'^(\d+(?:[\.,]\d+)?)\s*(?:x\s*)?(' +
          _unitPattern +
          r')(?:\b|\s+|$)\s*(?:van\s+|of\s+)?(.*)$',
      caseSensitive: false,
    );

    final startQtyOnlyRegex = RegExp(
      r'^(\d+(?:[\.,]\d+)?)\s*(?:x\s*)?\s*(.*)$',
      caseSensitive: false,
    );

    final endWithUnitRegex = RegExp(
      r'^(.*?)\s+(\d+(?:[\.,]\d+)?)\s*(' + _unitPattern + r')(?:\b|$)$',
      caseSensitive: false,
    );

    final endQtyOnlyRegex = RegExp(
      r'^(.*?)\s+(\d+(?:[\.,]\d+)?)\s*(?:x)?$',
      caseSensitive: false,
    );

    final standaloneWordUnitRegex = RegExp(
      r'^(' + _wordUnitsPattern + r')\s+(?:van\s+|of\s+)?(.*)$',
      caseSensitive: false,
    );

    if (garlicCompoundMatch != null) {
      qty = _parseNum(garlicCompoundMatch.group(1));
      unit = 'teen';
      rawName = 'Knoflook';
    } else if (garlicReverseMatch != null) {
      qty = _parseNum(garlicReverseMatch.group(1));
      unit = 'teen';
      rawName = 'Knoflook';
    } else {
      final unitMatch = startWithUnitRegex.firstMatch(processed);
      if (unitMatch != null) {
        qty = _parseNum(unitMatch.group(1));
        final u = unitMatch.group(2)!.toLowerCase();
        unit = _unitMap[u] ?? u;
        rawName = unitMatch.group(3) ?? '';
      } else {
        final qtyMatch = startQtyOnlyRegex.firstMatch(processed);
        if (qtyMatch != null && qtyMatch.group(1) != null) {
          qty = _parseNum(qtyMatch.group(1));
          unit = null;
          rawName = qtyMatch.group(2) ?? '';
        } else {
          final endUnitMatch = endWithUnitRegex.firstMatch(processed);
          if (endUnitMatch != null) {
            rawName = endUnitMatch.group(1) ?? '';
            qty = _parseNum(endUnitMatch.group(2));
            final u = endUnitMatch.group(3)!.toLowerCase();
            unit = _unitMap[u] ?? u;
          } else {
            final endQtyMatch = endQtyOnlyRegex.firstMatch(processed);
            if (endQtyMatch != null && endQtyMatch.group(2) != null) {
              rawName = endQtyMatch.group(1) ?? '';
              qty = _parseNum(endQtyMatch.group(2));
              unit = null;
            } else {
              final standaloneMatch = standaloneWordUnitRegex.firstMatch(
                processed,
              );
              if (standaloneMatch != null) {
                qty = 1.0;
                final u = standaloneMatch.group(1)!.toLowerCase();
                unit = _unitMap[u] ?? u;
                rawName = standaloneMatch.group(2) ?? '';
              } else {
                qty = 1.0;
                unit = null;
                rawName = processed;
              }
            }
          }
        }
      }
    }

    // Extract notes if present (parentheses or comma)
    var cleanName = rawName.trim();

    // Check parentheses for note: "tomatenblokjes (400g)"
    final parenMatch = RegExp(r'\((.*?)\)').firstMatch(cleanName);
    if (parenMatch != null) {
      note = parenMatch.group(1)?.trim();
      cleanName = cleanName.replaceAll(parenMatch.group(0)!, '').trim();
    }

    // Check comma for preparation / note: "1 ui, gesnipperd"
    final commaIdx = cleanName.indexOf(',');
    if (commaIdx != -1) {
      final trailingNote = cleanName.substring(commaIdx + 1).trim();
      if (trailingNote.isNotEmpty) {
        note = note != null ? '$note, $trailingNote' : trailingNote;
      }
      cleanName = cleanName.substring(0, commaIdx).trim();
    }

    // Fallback if cleanName ended up empty
    if (cleanName.isEmpty) {
      if (unit != null) {
        cleanName = unit;
        unit = null;
      } else {
        cleanName = processed;
      }
    }

    // Capitalize first letter of item name
    if (cleanName.isNotEmpty) {
      cleanName = cleanName[0].toUpperCase() + cleanName.substring(1);
    }

    return ParsedGroceryItem(
      name: cleanName,
      quantity: qty,
      unit: unit,
      category: _guessCategory(cleanName),
      note: note,
    );
  }

  static GroceryCategory _guessCategory(String name) {
    try {
      final learned = ShoppingProductsService.instance.getCategoryForProduct(
        name,
      );
      if (learned != null) return learned;
    } catch (_) {}

    final lowerName = name.toLowerCase();

    if (lowerName.contains('melk') ||
        lowerName.contains('boter') ||
        lowerName.contains('parmigiano') ||
        lowerName.contains('kaas') ||
        lowerName.contains('yoghurt') ||
        lowerName.contains('slagroom') ||
        lowerName.contains('zuivel') ||
        lowerName.contains('kwark') ||
        lowerName.contains('mozzarella') ||
        lowerName.contains('cheddar') ||
        lowerName.contains('feta')) {
      return GroceryCategory.dairy;
    }

    if (lowerName.contains('appel') ||
        lowerName.contains('banaan') ||
        lowerName.contains('bananen') ||
        lowerName.contains('peer') ||
        lowerName.contains('peren') ||
        lowerName.contains('citroen') ||
        lowerName.contains('limoen') ||
        lowerName.contains('sinaasappel') ||
        lowerName.contains('aardbei') ||
        lowerName.contains('aardbeien') ||
        lowerName.contains('druif') ||
        lowerName.contains('druiven') ||
        lowerName.contains('mango') ||
        lowerName.contains('bessen') ||
        lowerName.contains('kiwi') ||
        lowerName.contains('ananas')) {
      return GroceryCategory.fruit;
    }

    if (lowerName.contains('ui') ||
        lowerName.contains('uien') ||
        lowerName.contains('knoflook') ||
        lowerName.contains('winterpeen') ||
        lowerName.contains('winterpenen') ||
        lowerName.contains('bleekselderij') ||
        lowerName.contains('wortel') ||
        lowerName.contains('wortelen') ||
        lowerName.contains('sla') ||
        lowerName.contains('spinazie') ||
        lowerName.contains('tomaat') ||
        lowerName.contains('tomaten') ||
        lowerName.contains('komkommer') ||
        lowerName.contains('courgette') ||
        lowerName.contains('paprika') ||
        lowerName.contains('aubergine') ||
        lowerName.contains('broccoli') ||
        lowerName.contains('bloemkool') ||
        lowerName.contains('prei') ||
        lowerName.contains('champignon') ||
        lowerName.contains('champignons') ||
        lowerName.contains('avocado')) {
      return GroceryCategory.vegetables;
    }

    if (lowerName.contains('gehakt') ||
        lowerName.contains('spek') ||
        lowerName.contains('spekreepjes') ||
        lowerName.contains('vlees') ||
        lowerName.contains('kip') ||
        lowerName.contains('kipfilet') ||
        lowerName.contains('vis') ||
        lowerName.contains('zalm') ||
        lowerName.contains('tonijn') ||
        lowerName.contains('biefstuk') ||
        lowerName.contains('rundvlees') ||
        lowerName.contains('worst') ||
        lowerName.contains('kalkoen') ||
        lowerName.contains('garnalen')) {
      return GroceryCategory.meat;
    }

    if (lowerName.contains('brood') ||
        lowerName.contains('croissant') ||
        lowerName.contains('pistolet') ||
        lowerName.contains('stokbrood') ||
        lowerName.contains('pita') ||
        lowerName.contains('wrap') ||
        lowerName.contains('bolletjes')) {
      return GroceryCategory.bakery;
    }

    if (lowerName.contains('peterselie') ||
        lowerName.contains('basilicum') ||
        lowerName.contains('koriander') ||
        lowerName.contains('tijm') ||
        lowerName.contains('rozemarijn') ||
        lowerName.contains('oregano') ||
        lowerName.contains('peper') ||
        lowerName.contains('zout') ||
        lowerName.contains('kaneel')) {
      return GroceryCategory.herbsAndSpices;
    }

    if (lowerName.contains('koffie') || lowerName.contains('thee')) {
      return GroceryCategory.coffeeAndTea;
    }

    if (lowerName.contains('chips') ||
        lowerName.contains('chocola') ||
        lowerName.contains('chocolade') ||
        lowerName.contains('koek') ||
        lowerName.contains('koekjes') ||
        lowerName.contains('noten') ||
        lowerName.contains('snoep')) {
      return GroceryCategory.snacks;
    }

    return GroceryCategory.other;
  }
}
