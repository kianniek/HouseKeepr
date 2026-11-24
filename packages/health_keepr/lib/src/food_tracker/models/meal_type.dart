/// Meal category for logged food entries.
enum MealType {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snack');

  const MealType(this.label);

  /// Human-readable display label.
  final String label;

  /// Parses a persisted or user-supplied string into a [MealType].
  static MealType fromString(
    String? value, {
    MealType fallback = MealType.snack,
  }) {
    if (value == null) return fallback;
    final normalized = value.trim().toLowerCase();
    for (final mealType in MealType.values) {
      if (mealType.name == normalized) {
        return mealType;
      }
    }
    return fallback;
  }

  /// Suggests a default [MealType] based on a local wall-clock [DateTime].
  static MealType defaultForLocalTime(DateTime localTime) {
    final hour = localTime.hour;
    if (hour < 11) return MealType.breakfast;
    if (hour < 15) return MealType.lunch;
    if (hour < 21) return MealType.dinner;
    return MealType.snack;
  }
}
