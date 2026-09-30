import 'dart:convert';

class CoffeeIngredient {
  final String id;
  final String name;
  final int color;
  final double partsRatio;
  final String unitLabel;

  const CoffeeIngredient({
    required this.id,
    required this.name,
    required this.color,
    required this.partsRatio,
    required this.unitLabel,
  });

  Map<String, Object> toMap() => {
    'id': id,
    'name': name,
    'color': color,
    'ratio': partsRatio,
    'unit': unitLabel,
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

  Map<String, Object> toMap() => {
    'id': id,
    'name': displayName,
    'layers': layers.map((layer) => layer.toMap()).toList(),
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
      brewSteps: [],
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
}
