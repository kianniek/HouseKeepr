import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grocery_category.dart';
import 'shopping_products_default_data.dart';

/// Represents a grocery product in the shopping database.
class ShoppingProduct {
  final String sectionNL;
  final String sectionEN;
  final String productNL;
  final String productEN;

  ShoppingProduct({
    required this.sectionNL,
    required this.sectionEN,
    required this.productNL,
    required this.productEN,
  });

  factory ShoppingProduct.fromCsvLine(String line) {
    final parts = _parseCsvLine(line);
    if (parts.length < 4) {
      throw FormatException('Invalid CSV line: $line');
    }
    return ShoppingProduct(
      sectionNL: parts[0],
      sectionEN: parts[1],
      productNL: parts[2],
      productEN: parts[3],
    );
  }

  String toCsvLine() =>
      _encodeCsvLine([sectionNL, sectionEN, productNL, productEN]);

  /// Parse a CSV line handling quoted fields.
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = '';
    var inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    result.add(current.trim());
    return result;
  }

  /// Encode a CSV line handling special characters.
  static String _encodeCsvLine(List<String> fields) {
    return fields
        .map((f) {
          if (f.contains(',') || f.contains('"') || f.contains('\n')) {
            return '"${f.replaceAll('"', '""')}"';
          }
          return f;
        })
        .join(',');
  }
}

class ShoppingProductsService {
  static const _kProductsKey = 'shopping_products_csv_v1';
  static const _kLearningBox = 'learning_products';
  static const double _minLearnedConfidence = 0.45;
  static const double _minCsvConfidence = 0.35;

  static final ShoppingProductsService _instance =
      ShoppingProductsService._internal();
  static ShoppingProductsService get instance => _instance;

  ShoppingProductsService._internal();

  SharedPreferences? _prefs;
  Box? _learningBox;
  final List<ShoppingProduct> _products = [];

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    await _loadProducts();
    if (!Hive.isBoxOpen(_kLearningBox)) {
      _learningBox = await Hive.openBox(_kLearningBox);
    } else {
      _learningBox = Hive.box(_kLearningBox);
    }
  }

  /// Suggested product result with confidence (0-1).
  ProductSuggestion? getProductSuggestion(String input) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;

    String? bestProduct;
    double bestScore = 0.0;

    for (final p in _products) {
      final names = [p.productEN, p.productNL];
      double bestProductScore = 0.0;
      String? bestProductName;

      for (final name in names) {
        final candidate = name.toLowerCase();
        for (final token in tokens) {
          final score = _prefixConfidence(token, candidate);
          if (score > bestProductScore) {
            bestProductScore = score;
            bestProductName = name;
          }
        }
      }

      if (bestProductScore > bestScore) {
        bestScore = bestProductScore;
        bestProduct = bestProductName ?? p.productEN;
      }
    }

    if (bestProduct == null) return null;

    // Require a minimum confidence to avoid noisy suggestions.
    if (bestScore < 0.35) return null;

    return ProductSuggestion(bestProduct, bestScore);
  }

  /// Learn or update a category for a product.
  Future<void> learnProduct(
    String productName,
    GroceryCategory category,
  ) async {
    if (_learningBox == null) return;
    final key = _normalizeText(productName);
    if (key.isEmpty) return;
    await _learningBox!.put(key, category.name);
  }

  /// Get a learned category or fallback to CSV data.
  GroceryCategory? getCategoryForProduct(String productName) {
    final normalized = _normalizeText(productName);
    if (normalized.isEmpty) return null;

    final learnedScores = _getLearnedCategoryConfidenceScores(normalized);
    final learnedBest = _bestCategoryForScores(learnedScores);
    if (learnedBest != null && learnedBest.value >= _minLearnedConfidence) {
      return learnedBest.key;
    }

    final csvScores = _getCsvCategoryConfidenceScores(normalized);
    return _bestCategoryForScores(csvScores)?.key;
  }

  /// Get confidence scores for categories based on per-letter prefix matches.
  Map<GroceryCategory, double> getCategoryConfidenceScores(String productName) {
    final normalized = _normalizeText(productName);
    final scores = <GroceryCategory, double>{};
    if (normalized.isEmpty) return scores;

    _mergeScores(scores, _getLearnedCategoryConfidenceScores(normalized));
    _mergeScores(scores, _getCsvCategoryConfidenceScores(normalized));

    return scores;
  }

  /// Pick the category with the highest confidence score.
  GroceryCategory? getBestCategoryForProduct(String productName) {
    final normalized = _normalizeText(productName);
    if (normalized.isEmpty) return null;

    final learnedScores = _getLearnedCategoryConfidenceScores(normalized);
    final learnedBest = _bestCategoryForScores(learnedScores);
    if (learnedBest != null && learnedBest.value >= _minLearnedConfidence) {
      return learnedBest.key;
    }

    final scores = _getCsvCategoryConfidenceScores(normalized);
    if (scores.isEmpty) return null;

    return _bestCategoryForScores(scores)?.key;
  }

  double _prefixConfidence(String token, String candidate) {
    if (token.isEmpty || candidate.isEmpty) return 0.0;
    if (!candidate.startsWith(token)) return 0.0;
    if (candidate == token) return 1.0;

    final denom = candidate.length;
    if (denom == 0) return 0.0;
    return token.length / denom;
  }

  String _normalizeText(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _tokenize(String input) {
    final normalized = _normalizeText(input);
    if (normalized.isEmpty) return const [];

    return normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  Map<GroceryCategory, double> _getLearnedCategoryConfidenceScores(
    String productName,
  ) {
    final scores = <GroceryCategory, double>{};
    if (_learningBox == null || !_learningBox!.isOpen) return scores;

    final normalized = _normalizeText(productName);
    if (normalized.isEmpty) return scores;

    for (final rawKey in _learningBox!.keys) {
      if (rawKey is! String) continue;
      final categoryName = _learningBox!.get(rawKey) as String?;
      final category = GroceryCategory.fromString(categoryName);
      final score = _learnedMatchConfidence(normalized, rawKey);
      if (score <= 0) continue;

      final existing = scores[category] ?? 0.0;
      if (score > existing) {
        scores[category] = score;
      }
    }

    return scores;
  }

  Map<GroceryCategory, double> _getCsvCategoryConfidenceScores(
    String productName,
  ) {
    final normalized = _normalizeText(productName);
    final scores = <GroceryCategory, double>{};
    if (normalized.isEmpty) return scores;

    final tokens = _tokenize(normalized);
    if (tokens.isEmpty) return scores;

    for (final p in _products) {
      final names = [p.productEN, p.productNL];
      double bestProductScore = 0.0;

      for (final name in names) {
        final candidate = name.toLowerCase();
        for (final token in tokens) {
          final score = _prefixConfidence(token, candidate);
          if (score > bestProductScore) {
            bestProductScore = score;
          }
        }
      }

      if (bestProductScore >= _minCsvConfidence) {
        final category = _mapSectionToCategory(p.sectionEN);
        final existing = scores[category] ?? 0.0;
        if (bestProductScore > existing) {
          scores[category] = bestProductScore;
        }
      }
    }

    return scores;
  }

  MapEntry<GroceryCategory, double>? _bestCategoryForScores(
    Map<GroceryCategory, double> scores,
  ) {
    if (scores.isEmpty) return null;

    MapEntry<GroceryCategory, double>? best;
    scores.forEach((category, score) {
      if (best == null || score > best!.value) {
        best = MapEntry(category, score);
      }
    });

    return best;
  }

  void _mergeScores(
    Map<GroceryCategory, double> target,
    Map<GroceryCategory, double> source,
  ) {
    source.forEach((category, score) {
      final existing = target[category] ?? 0.0;
      if (score > existing) {
        target[category] = score;
      }
    });
  }

  double _learnedMatchConfidence(String input, String learnedKey) {
    final normalizedInput = _normalizeText(input);
    final normalizedLearned = _normalizeText(learnedKey);
    if (normalizedInput.isEmpty || normalizedLearned.isEmpty) return 0.0;

    if (normalizedInput == normalizedLearned) {
      return 1.0;
    }

    final inputTokens = _tokenize(normalizedInput);
    final learnedTokens = _tokenize(normalizedLearned);
    if (inputTokens.isEmpty || learnedTokens.isEmpty) return 0.0;

    double bestScore = 0.0;

    for (
      int learnedIndex = 0;
      learnedIndex < learnedTokens.length;
      learnedIndex++
    ) {
      final learnedToken = learnedTokens[learnedIndex];
      final tokenWeight =
          learnedTokens.length == 1 || learnedIndex == learnedTokens.length - 1
          ? 1.0
          : 0.8;

      for (final inputToken in inputTokens) {
        final similarity = _tokenSimilarity(inputToken, learnedToken);
        if (similarity <= 0) continue;

        final score = 0.75 + (0.25 * similarity * tokenWeight);
        if (score > bestScore) {
          bestScore = score;
        }
      }
    }

    return bestScore;
  }

  double _tokenSimilarity(String inputToken, String learnedToken) {
    if (inputToken.isEmpty || learnedToken.isEmpty) return 0.0;
    if (inputToken == learnedToken) return 1.0;

    if (inputToken.startsWith(learnedToken) ||
        learnedToken.startsWith(inputToken)) {
      final shorter = inputToken.length < learnedToken.length
          ? inputToken.length
          : learnedToken.length;
      final longer = inputToken.length > learnedToken.length
          ? inputToken.length
          : learnedToken.length;
      if (longer == 0) return 0.0;
      return shorter / longer;
    }

    return 0.0;
  }

  static const _sectionToCategory = {
    'alcohol': GroceryCategory.alcohol,
    'baby': GroceryCategory.baby,
    'bakery': GroceryCategory.bakery,
    'baking': GroceryCategory.baking,
    'canned & jarred': GroceryCategory.canned,
    'soda and juice': GroceryCategory.beverages,
    'fruit': GroceryCategory.fruit,
    'vegetables': GroceryCategory.vegetables,
    'household': GroceryCategory.household,
    'pets': GroceryCategory.pets,
    'international': GroceryCategory.international,
    'cheese and dairy': GroceryCategory.dairy,
    'coffee and tea': GroceryCategory.coffeeAndTea,
    'herbs and spices': GroceryCategory.herbsAndSpices,
    'breakfast': GroceryCategory.breakfast,
    'sauces': GroceryCategory.sauces,
    'candy and snacks': GroceryCategory.snacks,
    'personal care': GroceryCategory.personal,
    'meat and fish': GroceryCategory.meat,
    'cold cuts': GroceryCategory.coldCuts,
    'freezer': GroceryCategory.frozen,
    'vegetarian': GroceryCategory.vegetarian,
  };

  GroceryCategory _mapSectionToCategory(String section) {
    return _sectionToCategory[section.toLowerCase().trim()] ??
        GroceryCategory.other;
  }

  Future<void> _loadProducts() async {
    if (_prefs == null) return;
    final csv = _prefs!.getString(_kProductsKey) ?? defaultShoppingProductsCsv;
    _parseProducts(csv);
  }

  void _parseProducts(String csv) {
    _products.clear();
    final lines = csv.split('\n');
    // Skip header line
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        _products.add(ShoppingProduct.fromCsvLine(line));
      } catch (_) {}
    }
  }

  /// Get all unique sections in EN.
  List<String> getSections() {
    final seen = <String>{};
    final result = <String>[];
    for (final p in _products) {
      if (!seen.contains(p.sectionEN)) {
        seen.add(p.sectionEN);
        result.add(p.sectionEN);
      }
    }
    result.sort();
    return result;
  }

  /// Get products for a given section (by EN name).
  List<ShoppingProduct> getProductsForSection(String sectionEN) {
    return _products.where((p) => p.sectionEN == sectionEN).toList();
  }

  /// Search products by English name (case-insensitive partial match).
  List<ShoppingProduct> searchProducts(String query) {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    return _products
        .where((p) => p.productEN.toLowerCase().contains(lower))
        .toList();
  }

  /// Get product names (EN) grouped by section for easy access.
  Map<String, List<String>> getProductsBySection() {
    final result = <String, List<String>>{};
    for (final p in _products) {
      if (!result.containsKey(p.sectionEN)) {
        result[p.sectionEN] = [];
      }
      result[p.sectionEN]!.add(p.productEN);
    }
    // Sort products within each section
    result.forEach((_, products) => products.sort());
    return result;
  }

  /// Find the section (English name) for a product by English product name.
  String? findSectionForProduct(String productEN) {
    final lower = productEN.toLowerCase();
    for (final p in _products) {
      if (p.productEN.toLowerCase() == lower) {
        return p.sectionEN;
      }
    }
    return null;
  }

  /// Add a new product and persist (Legacy CSV method, prefer learnProduct).
  Future<void> addProduct(ShoppingProduct product) async {
    _products.add(product);
    await _persist();
  }

  /// Get all products.
  List<ShoppingProduct> getAllProducts() => List.from(_products);

  Future<void> _persist() async {
    if (_prefs == null) return;
    final header = 'Section_NL,Section_EN,Product_NL,Product_EN';
    final lines = [header];
    for (final p in _products) {
      lines.add(p.toCsvLine());
    }
    await _prefs!.setString(_kProductsKey, lines.join('\n'));
  }
}

class ProductSuggestion {
  final String product;
  final double confidence;

  ProductSuggestion(this.product, this.confidence);
}
