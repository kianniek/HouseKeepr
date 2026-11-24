import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ml/nutrition_catalog.dart';
import '../ml/nutrition_mapper.dart';
import '../models/nutrition_food.dart';

/// Origin of an auto-filled nutrition estimate.
enum NutritionEstimateSource {
  onDeviceLlm('On-Device AI'),
  localCatalog('Local Catalog');

  const NutritionEstimateSource(this.label);
  final String label;
}

/// Estimated serving weight and macronutrients for a food description.
@immutable
class NutritionEstimate {
  const NutritionEstimate({
    required this.servingGrams,
    required this.kcal,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.source,
    this.matchedFoodName,
    this.matchedFood,
    this.matchKind,
    this.cleanedTitle,
  });

  final double servingGrams;
  final double kcal;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final NutritionEstimateSource source;
  final String? matchedFoodName;
  final NutritionFood? matchedFood;
  final NutritionMatchKind? matchKind;
  final String? cleanedTitle;
}

/// Contract for estimating calories and macros from a food name & optional weight.
abstract class NutritionEstimator {
  Future<NutritionEstimate?> estimate({
    required String foodName,
    double? servingGrams,
  });
}

/// Instant offline nutrition estimator backed by [NutritionCatalog] and [NutritionMapper].
class CatalogNutritionEstimator implements NutritionEstimator {
  CatalogNutritionEstimator(this.catalog) : _mapper = NutritionMapper(catalog);

  final NutritionCatalog catalog;
  final NutritionMapper _mapper;

  @override
  Future<NutritionEstimate?> estimate({
    required String foodName,
    double? servingGrams,
  }) async {
    final trimmed = foodName.trim();
    if (trimmed.isEmpty) return null;

    var match = _mapper.mapLabelDetailed(trimmed);
    NutritionFood resolved = match.food;
    var matchKind = match.kind;

    if (matchKind == NutritionMatchKind.fallback) {
      final searchHits = catalog.search(trimmed, limit: 1);
      if (searchHits.isNotEmpty) {
        resolved = searchHits.first;
        matchKind = NutritionMatchKind.keyword;
      }
    }

    final effectiveGrams =
        (servingGrams != null && servingGrams.isFinite && servingGrams > 0)
            ? servingGrams
            : resolved.defaultServingGrams;
    final macros = resolved.macrosForGrams(effectiveGrams);

    return NutritionEstimate(
      servingGrams: macros.servingGrams,
      kcal: macros.kcal,
      proteinGrams: macros.proteinGrams,
      carbsGrams: macros.carbsGrams,
      fatGrams: macros.fatGrams,
      source: NutritionEstimateSource.localCatalog,
      matchedFoodName: resolved.name,
      matchedFood: resolved,
      matchKind: matchKind,
    );
  }
}

/// Platform/engine abstraction for running an optional downloaded small on-device LLM.
abstract class OnDeviceLlmRunner {
  Future<bool> isModelReady();
  Future<String?> generateNutritionJson(String prompt);
}

/// Default [OnDeviceLlmRunner] backed by `housekeepr/food_llm` on Android.
///
/// Degrades gracefully when no native LLM plugin/model is present.
class MethodChannelOnDeviceLlmRunner implements OnDeviceLlmRunner {
  MethodChannelOnDeviceLlmRunner({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('housekeepr/food_llm');

  final MethodChannel _channel;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isModelReady() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isModelReady') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String?> generateNutritionJson(String prompt) async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>(
        'generateNutritionJson',
        <String, dynamic>{'prompt': prompt},
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// Hybrid nutrition estimator: tries an optional downloaded small on-device LLM
/// first, then built-in compound meal estimation when [isBuiltInAiEnabled] is
/// true, and falls back to [CatalogNutritionEstimator].
class HybridNutritionEstimator implements NutritionEstimator {
  HybridNutritionEstimator({
    required NutritionCatalog catalog,
    OnDeviceLlmRunner? llmRunner,
    this.isBuiltInAiEnabled = true,
  })  : _catalogEstimator = CatalogNutritionEstimator(catalog),
        _llmRunner = llmRunner ?? MethodChannelOnDeviceLlmRunner();

  final CatalogNutritionEstimator _catalogEstimator;
  final OnDeviceLlmRunner _llmRunner;
  final bool isBuiltInAiEnabled;

  @override
  Future<NutritionEstimate?> estimate({
    required String foodName,
    double? servingGrams,
  }) async {
    final trimmed = foodName.trim();
    if (trimmed.isEmpty) return null;

    if (await _llmRunner.isModelReady()) {
      final hasWeight =
          servingGrams != null && servingGrams.isFinite && servingGrams > 0;
      final prompt = hasWeight
          ? 'Return ONLY JSON with keys servingGrams,kcal,proteinGrams,carbsGrams,fatGrams '
              'for "$trimmed" at ${servingGrams.round()}g.'
          : 'Return ONLY JSON with keys servingGrams,kcal,proteinGrams,carbsGrams,fatGrams '
              'for a typical serving of "$trimmed".';
      final raw = await _llmRunner.generateNutritionJson(prompt);
      final parsed = _tryParseLlmJson(raw, requestedGrams: hasWeight ? servingGrams : null);
      if (parsed != null) {
        return parsed;
      }
    }

    if (isBuiltInAiEnabled) {
      final parsedMeal = await _estimateMealDescription(
        trimmed,
        fallbackServingGrams: servingGrams,
      );
      if (parsedMeal != null) {
        return parsedMeal;
      }
    }

    return _catalogEstimator.estimate(
      foodName: trimmed,
      servingGrams: servingGrams,
    );
  }

  static final RegExp _conjunctionSplitter = RegExp(
    r'\s+(?:with|and|en|met|\+|&)\s+|,\s*',
    caseSensitive: false,
  );

  static final RegExp _leadingWeightPattern = RegExp(
    r'^\s*(\d+(?:[.,]\d+)?)\s*(kg|g|gr|gram|grams|ml|l)\b\s*(?:of|van)?\s*(.+)$',
    caseSensitive: false,
  );

  static final RegExp _trailingWeightPattern = RegExp(
    r'^(.+?)\s+(\d+(?:[.,]\d+)?)\s*(kg|g|gr|gram|grams|ml|l)\s*$',
    caseSensitive: false,
  );

  static final RegExp _leadingCountPattern = RegExp(
    r'^\s*(\d+(?:[.,]\d+)?)\s*(?:x\s*)?(.+)$',
    caseSensitive: false,
  );

  static double? _toGrams(String numberRaw, String unitRaw) {
    final value = double.tryParse(numberRaw.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) return null;
    return switch (unitRaw.toLowerCase()) {
      'kg' || 'l' => value * 1000.0,
      _ => value,
    };
  }

  static ({String foodQuery, double? grams, double? countMultiplier})
      _parseClause(String rawClause) {
    final trimmed = rawClause.trim();
    final leading = _leadingWeightPattern.firstMatch(trimmed);
    if (leading != null) {
      final grams = _toGrams(leading.group(1)!, leading.group(2)!);
      final query = leading.group(3)!.trim();
      if (query.isNotEmpty) {
        return (foodQuery: query, grams: grams, countMultiplier: null);
      }
    }

    final trailing = _trailingWeightPattern.firstMatch(trimmed);
    if (trailing != null) {
      final query = trailing.group(1)!.trim();
      final grams = _toGrams(trailing.group(2)!, trailing.group(3)!);
      if (query.isNotEmpty) {
        return (foodQuery: query, grams: grams, countMultiplier: null);
      }
    }

    final countMatch = _leadingCountPattern.firstMatch(trimmed);
    if (countMatch != null) {
      final count = double.tryParse(countMatch.group(1)!.replaceAll(',', '.'));
      final query = countMatch.group(2)!.trim();
      if (count != null && count.isFinite && count > 0 && query.isNotEmpty) {
        return (foodQuery: query, grams: null, countMultiplier: count);
      }
    }

    return (foodQuery: trimmed, grams: null, countMultiplier: null);
  }

  Future<NutritionEstimate?> _estimateMealDescription(
    String foodName, {
    double? fallbackServingGrams,
  }) async {
    final rawParts = foodName
        .split(_conjunctionSplitter)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (rawParts.isEmpty) return null;

    final hasCompound = rawParts.length >= 2;
    final parsedSingle = _parseClause(rawParts.first);
    if (!hasCompound &&
        parsedSingle.grams == null &&
        parsedSingle.countMultiplier == null) {
      return null;
    }

    final estimates = <NutritionEstimate>[];
    var anyExplicitWeight = false;
    for (final rawPart in rawParts) {
      final parsed = _parseClause(rawPart);
      if (parsed.grams != null || parsed.countMultiplier != null) {
        anyExplicitWeight = true;
      }

      double? partGrams = parsed.grams;
      if (partGrams == null && parsed.countMultiplier != null) {
        final baseEst = await _catalogEstimator.estimate(
          foodName: parsed.foodQuery,
        );
        if (baseEst != null) {
          partGrams = baseEst.servingGrams * parsed.countMultiplier!;
        }
      }

      final est = await _catalogEstimator.estimate(
        foodName: parsed.foodQuery,
        servingGrams: partGrams ??
            (!hasCompound ? fallbackServingGrams : null),
      );
      if (est != null && est.matchKind != NutritionMatchKind.fallback) {
        estimates.add(est);
      }
    }

    if (estimates.isEmpty) return null;
    if (hasCompound && estimates.length < 2 && !anyExplicitWeight) return null;

    var totalGrams = 0.0;
    var totalKcal = 0.0;
    var totalProtein = 0.0;
    var totalCarbs = 0.0;
    var totalFat = 0.0;
    for (final est in estimates) {
      totalGrams += est.servingGrams;
      totalKcal += est.kcal;
      totalProtein += est.proteinGrams;
      totalCarbs += est.carbsGrams;
      totalFat += est.fatGrams;
    }

    final hasFallbackWeight = fallbackServingGrams != null &&
        fallbackServingGrams.isFinite &&
        fallbackServingGrams > 0;
    final scale = (!anyExplicitWeight && hasFallbackWeight && totalGrams > 0)
        ? fallbackServingGrams / totalGrams
        : 1.0;

    final names = estimates
        .map((e) => e.matchedFoodName)
        .whereType<String>()
        .toList();
    final cleanedTitle = names.length <= 1
        ? (names.isEmpty ? foodName : names.first)
        : names.join(' & ');

    return NutritionEstimate(
      servingGrams: (!anyExplicitWeight && hasFallbackWeight)
          ? fallbackServingGrams
          : totalGrams,
      kcal: totalKcal * scale,
      proteinGrams: totalProtein * scale,
      carbsGrams: totalCarbs * scale,
      fatGrams: totalFat * scale,
      source: NutritionEstimateSource.onDeviceLlm,
      matchedFoodName: names.join(' + '),
      matchedFood: estimates.length == 1 ? estimates.first.matchedFood : null,
      matchKind:
          estimates.length == 1 ? estimates.first.matchKind : null,
      cleanedTitle: cleanedTitle,
    );
  }

  static NutritionEstimate? _tryParseLlmJson(
    String? raw, {
    double? requestedGrams,
  }) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      final jsonStr = match?.group(0) ?? raw;
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return null;

      final kcal = _readNonNegative(decoded['kcal']);
      final protein = _readNonNegative(
        decoded['proteinGrams'] ?? decoded['protein'],
      );
      final carbs = _readNonNegative(
        decoded['carbsGrams'] ?? decoded['carbs'],
      );
      final fat = _readNonNegative(
        decoded['fatGrams'] ?? decoded['fat'],
      );
      final inferredGrams = _readPositive(decoded['servingGrams']) ?? 100.0;
      if (kcal == null) return null;

      final effectiveGrams = requestedGrams ?? inferredGrams;
      return NutritionEstimate(
        servingGrams: effectiveGrams,
        kcal: kcal,
        proteinGrams: protein ?? 0.0,
        carbsGrams: carbs ?? 0.0,
        fatGrams: fat ?? 0.0,
        source: NutritionEstimateSource.onDeviceLlm,
      );
    } catch (_) {
      return null;
    }
  }

  static double? _readNonNegative(Object? raw) {
    if (raw is num) {
      final v = raw.toDouble();
      return (v.isFinite && v >= 0) ? v : null;
    }
    if (raw is String) {
      final v = double.tryParse(raw.trim());
      return (v != null && v.isFinite && v >= 0) ? v : null;
    }
    return null;
  }

  static double? _readPositive(Object? raw) {
    final v = _readNonNegative(raw);
    return (v != null && v > 0) ? v : null;
  }
}
