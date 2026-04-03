enum GroceryCategory {
  fruit('Fruit', '🍎'),
  vegetables('Vegetables', '🥬'),
  herbsAndSpices('Herbs and Spices', '🌿'),
  coldCuts('Cold Cuts', '🥓'),
  meat('Meat and Fish', '🥩'),
  bakery('Bakery', '🥖'),
  canned('Canned & Jarred', '🥫'),
  international('International', '🌍'),
  baking('Baking', '🧁'),
  sauces('Sauces', '🍯'),
  dairy('Cheese and Dairy', '🥛'),
  breakfast('Breakfast', '🥣'),
  coffeeAndTea('Coffee and Tea', '☕'),
  household('Household', '🧼'),
  snacks('Candy and Snacks', '🍿'),
  personal('Personal Care', '🧴'),
  beverages('Soda and Juice', '🧃'),
  alcohol('Alcohol', '🍷'),
  frozen('Freezer', '❄️'),
  vegetarian('Vegetarian', '🥗'),
  baby('Baby', '👶'),
  pets('Pets', '🐾'),
  other('Other', '📦');

  final String displayName;
  final String emoji;

  const GroceryCategory(this.displayName, this.emoji);

  static GroceryCategory fromString(String? value) {
    if (value == null) return GroceryCategory.other;
    try {
      return GroceryCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => GroceryCategory.other,
      );
    } catch (_) {
      return GroceryCategory.other;
    }
  }
}
