import 'package:flutter/foundation.dart';

/// Scaled nutritional values for a specific serving size in grams.
@immutable
class NutritionMacros {
  const NutritionMacros({
    required this.servingGrams,
    required this.kcal,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  static const NutritionMacros zero = NutritionMacros(
    servingGrams: 0.0,
    kcal: 0.0,
    proteinGrams: 0.0,
    carbsGrams: 0.0,
    fatGrams: 0.0,
  );

  final double servingGrams;
  final double kcal;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NutritionMacros &&
        other.servingGrams == servingGrams &&
        other.kcal == kcal &&
        other.proteinGrams == proteinGrams &&
        other.carbsGrams == carbsGrams &&
        other.fatGrams == fatGrams;
  }

  @override
  int get hashCode => Object.hash(
        servingGrams,
        kcal,
        proteinGrams,
        carbsGrams,
        fatGrams,
      );
}

/// A bundled food or prepared dish nutrition profile (per 100g).
@immutable
class NutritionFood {
  const NutritionFood({
    required this.id,
    required this.name,
    required this.category,
    this.aliases = const <String>[],
    this.keywords = const <String>[],
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.defaultServingGrams,
    required this.servingLabel,
  });

  factory NutritionFood.fromJson(Map<String, dynamic> json) {
    final parsedServing = _readDouble(
      json['defaultServingGrams'],
      fallback: 100.0,
    );
    final defaultServingGrams =
        (parsedServing.isFinite && parsedServing > 0) ? parsedServing : 100.0;
    final rawServingLabel = json['servingLabel'];
    final trimmedServingLabel =
        rawServingLabel is String ? rawServingLabel.trim() : null;
    final servingLabel =
        (trimmedServingLabel != null && trimmedServingLabel.isNotEmpty)
            ? trimmedServingLabel
            : '${defaultServingGrams.round()}g';
    final rawId = json['id'];
    final rawName = json['name'];
    final rawCategory = json['category'];

    return NutritionFood(
      id: (rawId is String ? rawId : '').trim(),
      name: (rawName is String ? rawName : '').trim(),
      category: (rawCategory is String ? rawCategory : 'mixed').trim(),
      aliases: _readStringList(json['aliases']),
      keywords: _readStringList(json['keywords']),
      kcalPer100g: _readNonNegativeDouble(
        json['kcalPer100g'] ?? json['kcal'],
      ),
      proteinPer100g: _readNonNegativeDouble(
        json['proteinPer100g'] ?? json['protein'],
      ),
      carbsPer100g: _readNonNegativeDouble(
        json['carbsPer100g'] ?? json['carbs'],
      ),
      fatPer100g: _readNonNegativeDouble(
        json['fatPer100g'] ?? json['fat'],
      ),
      defaultServingGrams: defaultServingGrams,
      servingLabel: servingLabel,
    );
  }

  final String id;
  final String name;
  final String category;
  final List<String> aliases;
  final List<String> keywords;
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double defaultServingGrams;
  final String servingLabel;

  /// Alias getter for [proteinPer100g].
  double get protein => proteinPer100g;

  /// Alias getter for [carbsPer100g].
  double get carbs => carbsPer100g;

  /// Alias getter for [fatPer100g].
  double get fat => fatPer100g;

  /// Scales nutritional macros proportionally for [servingGrams].
  NutritionMacros macrosForGrams(double servingGrams) {
    if (!servingGrams.isFinite || servingGrams <= 0) {
      return NutritionMacros.zero;
    }
    final factor = servingGrams / 100.0;
    return NutritionMacros(
      servingGrams: servingGrams,
      kcal: _clampFiniteNonNegative(kcalPer100g * factor),
      proteinGrams: _clampFiniteNonNegative(proteinPer100g * factor),
      carbsGrams: _clampFiniteNonNegative(carbsPer100g * factor),
      fatGrams: _clampFiniteNonNegative(fatPer100g * factor),
    );
  }

  static double _clampFiniteNonNegative(double value) {
    if (value.isNaN || value <= 0) return 0.0;
    return value.isFinite ? value : double.maxFinite;
  }

  /// Alias for [macrosForGrams].
  NutritionMacros forServing(double servingGrams) =>
      macrosForGrams(servingGrams);

  /// Scaled macros for [defaultServingGrams].
  NutritionMacros get defaultServingMacros =>
      macrosForGrams(defaultServingGrams);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category,
        'aliases': aliases,
        if (keywords.isNotEmpty) 'keywords': keywords,
        'kcalPer100g': kcalPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
        'defaultServingGrams': defaultServingGrams,
        'servingLabel': servingLabel,
      };

  static double _readDouble(Object? raw, {double fallback = 0.0}) {
    if (raw is num) {
      final value = raw.toDouble();
      return value.isFinite ? value : fallback;
    }
    if (raw is String) {
      final parsed = double.tryParse(raw);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return fallback;
  }

  static double _readNonNegativeDouble(Object? raw) {
    final value = _readDouble(raw, fallback: 0.0);
    return value < 0 ? 0.0 : value;
  }

  static List<String> _readStringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return List<String>.unmodifiable(
      raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NutritionFood &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        listEquals(other.aliases, aliases) &&
        listEquals(other.keywords, keywords) &&
        other.kcalPer100g == kcalPer100g &&
        other.proteinPer100g == proteinPer100g &&
        other.carbsPer100g == carbsPer100g &&
        other.fatPer100g == fatPer100g &&
        other.defaultServingGrams == defaultServingGrams &&
        other.servingLabel == servingLabel;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        category,
        Object.hashAll(aliases),
        Object.hashAll(keywords),
        kcalPer100g,
        proteinPer100g,
        carbsPer100g,
        fatPer100g,
        defaultServingGrams,
        servingLabel,
      );
}
