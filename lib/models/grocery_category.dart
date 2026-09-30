enum GroceryCategory {
  fruit('Fruit', '🍎'),
  vegetables('Vegetables', '🥬'),
  herbsAndSpices('Herbs and Spices', '🌿'),
  vegetarian('Vegetarian', '🥗'),
  meat('Meat and Fish', '🥩'),
  coldCuts('Cold Cuts', '🥓'),
  dairy('Cheese and Dairy', '🥛'),
  bakery('Bakery', '🥖'),
  international('International', '🌍'),
  canned('Canned & Jarred', '🥫'),
  sauces('Sauces', '🍯'),
  baking('Baking', '🧁'),
  breakfast('Breakfast', '🥣'),
  coffeeAndTea('Coffee and Tea', '☕'),
  baby('Baby', '👶'),
  personal('Personal Care', '🧴'),
  household('Household', '🧼'),
  pets('Pets', '🐾'),
  snacks('Candy and Snacks', '🍿'),
  beverages('Soda and Juice', '🧃'),
  alcohol('Alcohol', '🍷'),
  frozen('Freezer', '❄️'),
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
