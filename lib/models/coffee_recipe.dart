import 'dart:convert';

import 'package:flutter/material.dart';

class CoffeeIngredient {
  final String id;
  final String name;
  final int color;
  final double partsRatio;
  final String unitLabel;

  static final List<Color> coffeePalette = [
    // --- Coffee & Espresso Bases ---
    Colors.black, // Ristretto / Black Coffee
    Colors.brown.shade900, // Dark Roast Espresso
    Colors.brown.shade700, // Standard Espresso / Americano
    Colors.brown.shade500, // Medium Roast / Brewed Coffee
    Colors.brown.shade300, // Light Roast / Café au Lait
    Colors.amber.shade900, // Rich Crema
    // --- Milks & Creams ---
    Colors.white, // Pure Milk Foam / Microfoam
    Colors.amber.shade50, // Whole Milk / Heavy Cream
    Colors.orange.shade50, // Steamed Cream / Warm Ivory
    Colors.brown.shade100, // Oat Milk / Almond Milk Beige
    // --- Syrups, Sweets & Toppings ---
    Colors.brown.shade800, // Chocolate / Mocha Ganache
    Colors.orange.shade800, // Deep Caramel Drizzle
    Colors.amber.shade700, // Honey / Golden Syrup
    Colors.deepOrange.shade400, // Cinnamon / Cocoa Dusting
    Colors.brown.shade400, // Nutmeg / Spiced Blend
    // --- Specialty / Flavor Layers ---
    Colors.green.shade700, // Traditional Matcha Green Tea
    Colors.green.shade300, // Light Matcha Latte / Mint
    Colors.pink.shade200, // Strawberry / Raspberry Syrup
    Colors.purple.shade200, // Lavender Syrup / Taro
    Colors.blue.shade100, // Ice Water / Cold Brew Ice Layer
  ];

  const CoffeeIngredient({
    required this.id,
    required this.name,
    required this.color,
    required this.partsRatio,
    required this.unitLabel,
  });

  factory CoffeeIngredient.fromMap(Map<String, dynamic> map) =>
      CoffeeIngredient(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        color: (map['color'] as num?)?.toInt() ?? 0xFF9E9E9E,
        partsRatio:
            (map['partsRatio'] as num?)?.toDouble() ??
            (map['ratio'] as num?)?.toDouble() ??
            1,
        unitLabel:
            map['unitLabel'] as String? ??
            map['unit'] as String? ??
            map['name'] as String? ??
            '',
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'color': color,
    'partsRatio': partsRatio,
    'unitLabel': unitLabel,
  };
}

class BrewStep {
  final int index;
  final String title;
  final String description;
  final int? durationSeconds;
  final int? targetTemperatureCelsius;

  const BrewStep({
    required this.index,
    required this.title,
    required this.description,
    this.durationSeconds,
    this.targetTemperatureCelsius,
  });

  factory BrewStep.fromMap(Map<String, dynamic> map) => BrewStep(
    index: (map['index'] as num?)?.toInt() ?? 1,
    title: map['title'] as String? ?? '',
    description: map['description'] as String? ?? '',
    durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
    targetTemperatureCelsius: (map['targetTemperatureCelsius'] as num?)
        ?.toInt(),
  );

  Map<String, dynamic> toMap() => {
    'index': index,
    'title': title,
    'description': description,
    'durationSeconds': durationSeconds,
    'targetTemperatureCelsius': targetTemperatureCelsius,
  };
}

class CoffeeRecipe {
  final String id;
  final String displayName;
  final String description;
  final List<CoffeeIngredient> layers;
  final List<BrewStep> brewSteps;
  final int defaultYieldMl;

  const CoffeeRecipe({
    required this.id,
    required this.displayName,
    required this.description,
    required this.layers,
    required this.brewSteps,
    this.defaultYieldMl = 240,
  });

  factory CoffeeRecipe.fromMap(
    Map<String, dynamic> map, [
    String? documentId,
  ]) => CoffeeRecipe(
    id: documentId ?? map['id'] as String? ?? '',
    displayName: map['displayName'] as String? ?? map['name'] as String? ?? '',
    description: map['description'] as String? ?? '',
    layers: (map['layers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map(
          (layer) => CoffeeIngredient.fromMap(Map<String, dynamic>.from(layer)),
        )
        .toList(),
    brewSteps: (map['brewSteps'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((step) => BrewStep.fromMap(Map<String, dynamic>.from(step)))
        .toList(),
    defaultYieldMl: (map['defaultYieldMl'] as num?)?.toInt() ?? 240,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'displayName': displayName,
    'description': description,
    'layers': layers.map((layer) => layer.toMap()).toList(),
    'brewSteps': brewSteps.map((step) => step.toMap()).toList(),
    'defaultYieldMl': defaultYieldMl,
  };
}

class CoffeeRegistry {
  static const recipes = <CoffeeRecipe>[
    CoffeeRecipe(
      id: 'latte',
      displayName: 'Latte',
      description:
          'A smooth espresso drink with steamed milk and a thin layer of microfoam.',
      layers: [
        CoffeeIngredient(
          id: 'espresso',
          name: 'Espresso',
          color: 0xFF3E2723,
          partsRatio: 1,
          unitLabel: '1x Espresso',
        ),
        CoffeeIngredient(
          id: 'milk',
          name: 'Milk',
          color: 0xFFFFF3E0,
          partsRatio: 3,
          unitLabel: '3x Milk',
        ),
        CoffeeIngredient(
          id: 'foam',
          name: 'Foam',
          color: 0xFFECEFF1,
          partsRatio: .5,
          unitLabel: '0.5x Foam',
        ),
      ],
      brewSteps: [
        BrewStep(
          index: 1,
          title: 'Grind beans',
          description: 'Grind 18g of fine espresso-grade coffee beans.',
          durationSeconds: 15,
        ),
        BrewStep(
          index: 2,
          title: 'Pull espresso',
          description: 'Extract a 36ml double shot.',
          durationSeconds: 30,
        ),
        BrewStep(
          index: 3,
          title: 'Steam milk',
          description: 'Steam milk to 65 C with silky microfoam.',
          durationSeconds: 45,
          targetTemperatureCelsius: 65,
        ),
        BrewStep(
          index: 4,
          title: 'Pour and serve',
          description: 'Pour milk over the espresso and finish with foam.',
        ),
      ],
    ),
    CoffeeRecipe(
      id: 'cappuccino',
      displayName: 'Cappuccino',
      description: 'Equal parts espresso, steamed milk, and rich foam.',
      layers: [
        CoffeeIngredient(
          id: 'espresso',
          name: 'Espresso',
          color: 0xFF3E2723,
          partsRatio: 1,
          unitLabel: '1x Espresso',
        ),
        CoffeeIngredient(
          id: 'milk',
          name: 'Milk',
          color: 0xFFFFF3E0,
          partsRatio: 1,
          unitLabel: '1x Milk',
        ),
        CoffeeIngredient(
          id: 'foam',
          name: 'Foam',
          color: 0xFFECEFF1,
          partsRatio: 1,
          unitLabel: '1x Foam',
        ),
      ],
      brewSteps: [
        BrewStep(
          index: 1,
          title: 'Pull espresso',
          description: 'Extract a double shot into a small cup.',
          durationSeconds: 30,
        ),
        BrewStep(
          index: 2,
          title: 'Steam milk',
          description: 'Steam an equal amount of milk to about 60-65 C.',
          durationSeconds: 30,
          targetTemperatureCelsius: 62,
        ),
        BrewStep(
          index: 3,
          title: 'Finish with foam',
          description:
              'Pour the milk and spoon a generous layer of foam on top.',
        ),
      ],
    ),
    CoffeeRecipe(
      id: 'espresso',
      displayName: 'Espresso',
      description:
          'A concentrated shot for when you want coffee with no milk or extras.',
      defaultYieldMl: 36,
      layers: [
        CoffeeIngredient(
          id: 'espresso',
          name: 'Espresso',
          color: 0xFF3E2723,
          partsRatio: 1,
          unitLabel: '1x Espresso',
        ),
      ],
      brewSteps: [
        BrewStep(
          index: 1,
          title: 'Grind beans',
          description: 'Grind a fine espresso dose, around 18g.',
          durationSeconds: 15,
        ),
        BrewStep(
          index: 2,
          title: 'Pull the shot',
          description: 'Extract around 36ml into a warmed cup.',
          durationSeconds: 30,
        ),
      ],
    ),
    CoffeeRecipe(
      id: 'cortado',
      displayName: 'Cortado',
      description:
          'A short, balanced drink with equal parts espresso and warm milk.',
      defaultYieldMl: 120,
      layers: [
        CoffeeIngredient(
          id: 'espresso',
          name: 'Espresso',
          color: 0xFF3E2723,
          partsRatio: 1,
          unitLabel: '1x Espresso',
        ),
        CoffeeIngredient(
          id: 'warm_milk',
          name: 'Warm milk',
          color: 0xFFFFF3E0,
          partsRatio: 1,
          unitLabel: '1x Milk',
        ),
      ],
      brewSteps: [
        BrewStep(
          index: 1,
          title: 'Pull espresso',
          description: 'Extract a double shot into a small glass.',
          durationSeconds: 30,
        ),
        BrewStep(
          index: 2,
          title: 'Warm milk',
          description:
              'Steam or warm an equal volume of milk to about 55-60 C.',
          durationSeconds: 30,
          targetTemperatureCelsius: 58,
        ),
        BrewStep(
          index: 3,
          title: 'Combine',
          description: 'Pour the warm milk into the espresso.',
        ),
      ],
    ),
    CoffeeRecipe(
      id: 'mocha',
      displayName: 'Mocha',
      description:
          'Espresso and steamed milk with cocoa for a chocolate-forward cup.',
      defaultYieldMl: 240,
      layers: [
        CoffeeIngredient(
          id: 'espresso',
          name: 'Espresso',
          color: 0xFF3E2723,
          partsRatio: 1,
          unitLabel: '1x Espresso',
        ),
        CoffeeIngredient(
          id: 'cocoa',
          name: 'Cocoa',
          color: 0xFF6D4C41,
          partsRatio: .25,
          unitLabel: '0.25x Cocoa',
        ),
        CoffeeIngredient(
          id: 'milk',
          name: 'Milk',
          color: 0xFFFFF3E0,
          partsRatio: 3,
          unitLabel: '3x Milk',
        ),
        CoffeeIngredient(
          id: 'foam',
          name: 'Foam',
          color: 0xFFECEFF1,
          partsRatio: .5,
          unitLabel: '0.5x Foam',
        ),
      ],
      brewSteps: [
        BrewStep(
          index: 1,
          title: 'Make cocoa paste',
          description:
              'Stir cocoa powder with a splash of hot water until smooth.',
        ),
        BrewStep(
          index: 2,
          title: 'Pull espresso',
          description: 'Extract a double shot over the cocoa paste.',
          durationSeconds: 30,
        ),
        BrewStep(
          index: 3,
          title: 'Steam milk',
          description: 'Steam milk to 65 C with a small amount of foam.',
          durationSeconds: 45,
          targetTemperatureCelsius: 65,
        ),
        BrewStep(
          index: 4,
          title: 'Pour and serve',
          description: 'Add the milk, stir, and finish with foam.',
        ),
      ],
    ),
    CoffeeRecipe(
      id: 'cocoa-latte',
      displayName: 'Cocoa Latte',
      description: 'A gentle latte with cocoa mixed into the espresso base.',
      layers: [
        CoffeeIngredient(
          id: 'espresso',
          name: 'Espresso',
          color: 0xFF3E2723,
          partsRatio: 1,
          unitLabel: '1x Espresso',
        ),
        CoffeeIngredient(
          id: 'cocoa',
          name: 'Cocoa',
          color: 0xFF8D6E63,
          partsRatio: .2,
          unitLabel: '0.2x Cocoa',
        ),
        CoffeeIngredient(
          id: 'milk',
          name: 'Milk',
          color: 0xFFFFF3E0,
          partsRatio: 3,
          unitLabel: '3x Milk',
        ),
      ],
      brewSteps: [
        BrewStep(
          index: 1,
          title: 'Mix cocoa',
          description: 'Stir cocoa powder into the freshly pulled espresso.',
          durationSeconds: 30,
        ),
        BrewStep(
          index: 2,
          title: 'Steam milk',
          description: 'Steam milk to 65 C with silky microfoam.',
          durationSeconds: 45,
          targetTemperatureCelsius: 65,
        ),
        BrewStep(
          index: 3,
          title: 'Pour and serve',
          description: 'Pour the milk slowly into the cocoa espresso.',
        ),
      ],
    ),
  ];

  static CoffeeRecipe byId(String id) => recipes.firstWhere(
    (recipe) => recipe.id.toLowerCase() == id.toLowerCase(),
    orElse: () => recipes.first,
  );

  static String encode(CoffeeRecipe recipe) => jsonEncode(recipe.toMap());

  static String encodeForWidget(
    CoffeeRecipe selected,
    Iterable<CoffeeRecipe> available,
  ) => jsonEncode({
    ...selected.toMap(),
    'recipes': available.map((recipe) => recipe.toMap()).toList(),
  });
}

class CoffeeColorMapper {
  static final Map<String, Color> _associations = {
    // --- Coffee & Espresso Bases ---
    'ristretto': CoffeeIngredient.coffeePalette[0], // Colors.black
    'espresso': CoffeeIngredient.coffeePalette[1], // Colors.brown.shade900
    'americano': CoffeeIngredient.coffeePalette[2], // Colors.brown.shade700
    'coffee': CoffeeIngredient.coffeePalette[3], // Colors.brown.shade500
    'brew': CoffeeIngredient.coffeePalette[3], // Colors.brown.shade500
    'crema': CoffeeIngredient.coffeePalette[5], // Colors.amber.shade900
    // --- Milks & Creams ---
    'foam': CoffeeIngredient.coffeePalette[6], // Colors.white
    'microfoam': CoffeeIngredient.coffeePalette[6], // Colors.white
    'milk': CoffeeIngredient.coffeePalette[6], // Colors.white
    'cream': CoffeeIngredient.coffeePalette[7], // Colors.amber.shade50
    'half': CoffeeIngredient.coffeePalette[8], // Colors.orange.shade50
    'oat': CoffeeIngredient.coffeePalette[9], // Colors.brown.shade100
    'almond': CoffeeIngredient.coffeePalette[9], // Colors.brown.shade100
    'soy': CoffeeIngredient.coffeePalette[7], // Colors.amber.shade50
    'coconut': CoffeeIngredient.coffeePalette[6], // Colors.white
    // --- Syrups, Sweets & Toppings ---
    'chocolate': CoffeeIngredient.coffeePalette[10], // Colors.brown.shade800
    'mocha': CoffeeIngredient.coffeePalette[10], // Colors.brown.shade800
    'caramel': CoffeeIngredient.coffeePalette[11], // Colors.orange.shade800
    'honey': CoffeeIngredient.coffeePalette[12], // Colors.amber.shade700
    'syrup': CoffeeIngredient.coffeePalette[12], // Colors.amber.shade700
    'cinnamon':
        CoffeeIngredient.coffeePalette[13], // Colors.deepOrange.shade400
    'cocoa': CoffeeIngredient.coffeePalette[13], // Colors.deepOrange.shade400
    'vanilla': CoffeeIngredient.coffeePalette[9], // Colors.brown.shade100
    'nutmeg': CoffeeIngredient.coffeePalette[14], // Colors.brown.shade400
    // --- Specialty / Other Layers ---
    'matcha': CoffeeIngredient.coffeePalette[15], // Colors.green.shade700
    'tea': CoffeeIngredient.coffeePalette[15], // Colors.green.shade700
    'strawberry': CoffeeIngredient.coffeePalette[17], // Colors.pink.shade200
    'raspberry': CoffeeIngredient.coffeePalette[17], // Colors.pink.shade200
    'lavender': CoffeeIngredient.coffeePalette[18], // Colors.purple.shade200
    'taro': CoffeeIngredient.coffeePalette[18], // Colors.purple.shade200
    'water': CoffeeIngredient.coffeePalette[19], // Colors.blue.shade100
    'ice': CoffeeIngredient.coffeePalette[19], // Colors.blue.shade100
  };

  static Color getColorForName(String name, {Color? defaultColor}) {
    final query = name.toLowerCase().trim();
    if (query.isEmpty) {
      return defaultColor ?? CoffeeIngredient.coffeePalette[4];
    }

    // Tier 1: Exact Match
    if (_associations.containsKey(query)) {
      return _associations[query]!;
    }

    // Tier 2: Partial Match (Substring check both ways)
    for (final entry in _associations.entries) {
      if (query.contains(entry.key) || entry.key.contains(query)) {
        return entry.value;
      }
    }

    // Tier 3: Ranked Fuzzy Match (Longest Common Subsequence for ordered letter overlap)
    String? bestKey;
    int maxScore = -1;

    for (final key in _associations.keys) {
      final score = _calculateLcsLength(query, key);
      if (score > maxScore) {
        maxScore = score;
        bestKey = key;
      }
    }

    // Return the best ranked match if there is a meaningful overlap (score > 1)
    if (bestKey != null && maxScore > 1) {
      return _associations[bestKey]!;
    }

    return defaultColor ?? CoffeeIngredient.coffeePalette[4];
  }

  /// Helper algorithm to find the length of the Longest Common Subsequence
  /// (matching letters in the correct relative order).
  static int _calculateLcsLength(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    List<int> prev = List<int>.filled(b.length + 1, 0);
    List<int> curr = List<int>.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        if (a[i - 1] == b[j - 1]) {
          curr[j] = prev[j - 1] + 1;
        } else {
          curr[j] = curr[j - 1] > prev[j] ? curr[j - 1] : prev[j];
        }
      }
      prev = List<int>.from(curr);
    }
    return curr[b.length];
  }
}
