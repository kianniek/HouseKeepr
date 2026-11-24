import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/nutrition_food.dart';
import 'food_asset_loader.dart';

/// Offline searchable catalog of bundled [NutritionFood] profiles.
class NutritionCatalog {
  NutritionCatalog._(List<NutritionFood> foods)
      : foods = List<NutritionFood>.unmodifiable(foods),
        _byId = <String, NutritionFood>{
          for (final food in foods)
            if (food.id.isNotEmpty) food.id: food,
        };

  static const String defaultAssetPath =
      'assets/nutrition/nutrition_foods.json';

  /// Loads the bundled nutrition catalog using dual-key asset resolution.
  static Future<NutritionCatalog> loadFromAsset({
    AssetBundle? bundle,
    String assetPath = defaultAssetPath,
  }) async {
    final rawJson = await loadFoodAssetString(assetPath, bundle: bundle);
    return NutritionCatalog.fromJsonString(rawJson);
  }

  /// Parses a JSON array string into a [NutritionCatalog].
  factory NutritionCatalog.fromJsonString(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    if (decoded is! List) {
      throw const FormatException(
        'nutrition_foods.json must contain a top-level JSON array.',
      );
    }
    final parsedFoods = <NutritionFood>[];
    for (final entry in decoded) {
      if (entry is Map<String, dynamic>) {
        parsedFoods.add(NutritionFood.fromJson(entry));
      } else if (entry is Map) {
        parsedFoods.add(NutritionFood.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return NutritionCatalog._(parsedFoods);
  }

  /// Wraps an in-memory list of [NutritionFood] profiles.
  factory NutritionCatalog.fromFoods(List<NutritionFood> foods) {
    return NutritionCatalog._(foods);
  }

  /// Returns a new [NutritionCatalog] with [extraFoods] prepended and
  /// deduplicated by [NutritionFood.id] (keeping [extraFoods] on collisions).
  NutritionCatalog mergeFoods(List<NutritionFood> extraFoods) {
    if (extraFoods.isEmpty) return this;
    final seenIds = <String>{};
    final merged = <NutritionFood>[];
    for (final food in extraFoods) {
      if (food.id.isNotEmpty && !seenIds.add(food.id)) continue;
      merged.add(food);
    }
    for (final food in foods) {
      if (food.id.isNotEmpty && !seenIds.add(food.id)) continue;
      merged.add(food);
    }
    return NutritionCatalog._(merged);
  }

  final List<NutritionFood> foods;
  final Map<String, NutritionFood> _byId;

  /// Looks up a food profile by exact [id], or `null` if absent.
  NutritionFood? findById(String id) => _byId[id];

  /// Distinct sorted category names present in this catalog.
  List<String> get categories {
    final unique = <String>{
      for (final food in foods)
        if (food.category.isNotEmpty) food.category,
    }.toList()
      ..sort();
    return List<String>.unmodifiable(unique);
  }

  /// Searches foods offline by [query] and optional [category] filter.
  List<NutritionFood> search(
    String query, {
    String? category,
    int limit = 50,
  }) {
    if (limit <= 0) return const <NutritionFood>[];

    final normalizedCategory = category?.trim().toLowerCase();
    final filteredByCategory = (normalizedCategory == null ||
            normalizedCategory.isEmpty)
        ? foods
        : foods
            .where((food) => food.category.toLowerCase() == normalizedCategory)
            .toList();

    final normalizedQuery = normalizeNutritionTerm(query);
    if (normalizedQuery.isEmpty) {
      final sorted = List<NutritionFood>.from(filteredByCategory)
        ..sort((a, b) => a.name.compareTo(b.name));
      return List<NutritionFood>.unmodifiable(sorted.take(limit));
    }

    final queryTokens = normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();
    final scored = <({NutritionFood food, int score})>[];

    for (final food in filteredByCategory) {
      final score = _scoreSearchCandidate(food, normalizedQuery, queryTokens);
      if (score > 0) {
        scored.add((food: food, score: score));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.food.name.compareTo(b.food.name);
    });

    return List<NutritionFood>.unmodifiable(
      scored.take(limit).map((entry) => entry.food),
    );
  }

  int _scoreSearchCandidate(
    NutritionFood food,
    String normalizedQuery,
    List<String> queryTokens,
  ) {
    final normName = normalizeNutritionTerm(food.name);
    if (normName == normalizedQuery) return 1000;
    if (normName.startsWith(normalizedQuery)) return 850;
    if (normName.contains(normalizedQuery)) return 700;

    for (final alias in food.aliases) {
      final normAlias = normalizeNutritionTerm(alias);
      if (normAlias == normalizedQuery) return 650;
      if (normAlias.startsWith(normalizedQuery)) return 550;
      if (normAlias.contains(normalizedQuery)) return 480;
    }

    for (final keyword in food.keywords) {
      final normKeyword = normalizeNutritionTerm(keyword);
      if (normKeyword == normalizedQuery) return 440;
      if (normKeyword.contains(normalizedQuery)) return 360;
    }

    final normCategory = normalizeNutritionTerm(food.category);
    if (normCategory == normalizedQuery || normCategory.contains(normalizedQuery)) {
      return 300;
    }

    if (queryTokens.length > 1) {
      final combined = <String>[
        normName,
        ...food.aliases.map(normalizeNutritionTerm),
        ...food.keywords.map(normalizeNutritionTerm),
        normCategory,
      ].join(' ');
      if (queryTokens.every(combined.contains)) {
        return 250;
      }
    }

    return 0;
  }
}

/// Normalizes food labels and search queries for case-insensitive,
/// punctuation-insensitive, diacritic-folded matching.
String normalizeNutritionTerm(String input) {
  if (input.isEmpty) return '';
  final folded = _foldLatinDiacritics(input.toLowerCase().trim());
  return folded
      .replaceAll(RegExp(r'''[-_/,'’‘"“”().:&+]'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _foldLatinDiacritics(String input) {
  const replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'ả': 'a',
    'ã': 'a',
    'ạ': 'a',
    'â': 'a',
    'ấ': 'a',
    'ầ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ậ': 'a',
    'ă': 'a',
    'ắ': 'a',
    'ằ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'ặ': 'a',
    'ä': 'a',
    'å': 'a',
    'ā': 'a',
    'ą': 'a',
    'æ': 'ae',
    'ç': 'c',
    'ć': 'c',
    'č': 'c',
    'ď': 'd',
    'đ': 'd',
    'é': 'e',
    'è': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ẹ': 'e',
    'ê': 'e',
    'ế': 'e',
    'ề': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ệ': 'e',
    'ë': 'e',
    'ē': 'e',
    'ė': 'e',
    'ę': 'e',
    'ě': 'e',
    'ğ': 'g',
    'í': 'i',
    'ì': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ị': 'i',
    'î': 'i',
    'ï': 'i',
    'ī': 'i',
    'į': 'i',
    'ı': 'i',
    'ł': 'l',
    'ñ': 'n',
    'ń': 'n',
    'ň': 'n',
    'ó': 'o',
    'ò': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ọ': 'o',
    'ô': 'o',
    'ố': 'o',
    'ồ': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ộ': 'o',
    'ơ': 'o',
    'ớ': 'o',
    'ờ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ợ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ō': 'o',
    'ő': 'o',
    'œ': 'oe',
    'ř': 'r',
    'ś': 's',
    'š': 's',
    'ş': 's',
    'ß': 'ss',
    'ť': 't',
    'ú': 'u',
    'ù': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ụ': 'u',
    'ư': 'u',
    'ứ': 'u',
    'ừ': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ự': 'u',
    'û': 'u',
    'ü': 'u',
    'ū': 'u',
    'ů': 'u',
    'ű': 'u',
    'ý': 'y',
    'ỳ': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'ỵ': 'y',
    'ÿ': 'y',
    'ź': 'z',
    'ż': 'z',
    'ž': 'z',
  };

  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    buffer.write(replacements[ch] ?? ch);
  }
  return buffer.toString().replaceAll(RegExp(r'[\u0300-\u036f]'), '');
}
