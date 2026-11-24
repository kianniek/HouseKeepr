import '../models/food_prediction.dart';
import '../models/nutrition_food.dart';
import 'nutrition_catalog.dart';

/// Resolution tier used by [NutritionMapper].
enum NutritionMatchKind {
  exact,
  alias,
  keyword,
  category,
  fallback,
}

/// Detailed match outcome produced by [NutritionMapper.mapLabelDetailed].
class NutritionMatch {
  const NutritionMatch({
    required this.food,
    required this.kind,
    this.matchedTerm,
  });

  final NutritionFood food;
  final NutritionMatchKind kind;
  final String? matchedTerm;
}

/// A [FoodPrediction] paired with its resolved [NutritionMatch].
class MappedFoodPrediction {
  const MappedFoodPrediction({
    required this.prediction,
    required this.match,
  });

  final FoodPrediction prediction;
  final NutritionMatch match;
}

/// Maps AIY Food V1 labels and predictions to profiles in [NutritionCatalog].
class NutritionMapper {
  NutritionMapper(this.catalog) : _indexedFoods = _buildIndex(catalog);

  final NutritionCatalog catalog;
  final List<_IndexedFood> _indexedFoods;

  static const Set<String> _rawIngredientCategories = <String>{
    'fruit',
    'vegetable',
    'nuts',
    'fats',
    'condiment',
    'legume',
    'dairy',
    'beverage',
  };

  static const Set<String> _nonDishCategoryNeedles = <String>{
    'steak',
    'beef',
    'veal',
    'lamb',
    'chicken',
    'turkey',
    'duck',
    'bacon',
    'sausage',
    'ham',
    'pork',
    'salmon',
    'tuna',
    'cod',
    'shrimp',
    'crab',
    'lobster',
    'seafood',
    'fish',
    'egg',
  };

  static const Set<String> _beverageCategoryNeedles = <String>{
    'coffee',
    'tea',
    'juice',
    'smoothie',
    'shake',
    'drink',
  };

  static const Set<String> _accompanimentPrepositions = <String>{
    'with',
    'served',
    'topped',
    'accompanied',
  };

  static final Set<String> _categoryNeedleSingles = <String>{
    for (final rule in _categoryRules)
      if (!rule.needle.contains(' ')) _singularize(rule.needle),
  };

  static const NutritionFood _builtInFallback = NutritionFood(
    id: 'mixed_meal',
    name: 'Mixed Meal',
    category: 'mixed',
    kcalPer100g: 165.0,
    proteinPer100g: 9.0,
    carbsPer100g: 18.0,
    fatPer100g: 6.0,
    defaultServingGrams: 250.0,
    servingLabel: '1 plate (250g)',
  );

  static const List<({String needle, String targetId, String? category})>
      _categoryRules = <({String needle, String targetId, String? category})>[
    (needle: 'pizza', targetId: 'pizza', category: 'pizza'),
    (needle: 'calzone', targetId: 'calzone', category: 'pizza'),
    (needle: 'flatbread', targetId: 'focaccia', category: 'pizza'),
    (needle: 'cheeseburger', targetId: 'cheeseburger', category: 'burger'),
    (needle: 'hamburger', targetId: 'hamburger', category: 'burger'),
    (needle: 'burger', targetId: 'hamburger', category: 'burger'),
    (needle: 'shawarma', targetId: 'shawarma', category: 'sandwich'),
    (needle: 'gyro', targetId: 'gyro', category: 'sandwich'),
    (needle: 'panini', targetId: 'panini', category: 'sandwich'),
    (needle: 'sandwich', targetId: 'club_sandwich', category: 'sandwich'),
    (needle: 'sub', targetId: 'sub_sandwich', category: 'sandwich'),
    (needle: 'wrap', targetId: 'wrap', category: 'sandwich'),
    (needle: 'taco', targetId: 'taco', category: 'mexican'),
    (needle: 'burrito', targetId: 'burrito', category: 'mexican'),
    (needle: 'quesadilla', targetId: 'quesadilla', category: 'mexican'),
    (needle: 'enchilada', targetId: 'enchilada', category: 'mexican'),
    (needle: 'empanada', targetId: 'empanada', category: 'mexican'),
    (needle: 'tamale', targetId: 'tamale', category: 'mexican'),
    (needle: 'sushi', targetId: 'sushi', category: 'sushi'),
    (needle: 'sashimi', targetId: 'sashimi', category: 'sushi'),
    (needle: 'maki', targetId: 'sushi', category: 'sushi'),
    (needle: 'nigiri', targetId: 'nigiri_sushi', category: 'sushi'),
    (needle: 'lasagna', targetId: 'lasagna', category: 'pasta'),
    (needle: 'spaghetti', targetId: 'pasta', category: 'pasta'),
    (needle: 'macaroni', targetId: 'mac_and_cheese', category: 'pasta'),
    (needle: 'ravioli', targetId: 'ravioli', category: 'pasta'),
    (needle: 'gnocchi', targetId: 'gnocchi', category: 'pasta'),
    (needle: 'pasta', targetId: 'pasta', category: 'pasta'),
    (needle: 'risotto', targetId: 'risotto', category: 'rice'),
    (needle: 'ramen', targetId: 'ramen', category: 'noodles'),
    (needle: 'pho', targetId: 'pho', category: 'noodles'),
    (needle: 'udon', targetId: 'udon', category: 'noodles'),
    (needle: 'soba', targetId: 'soba', category: 'noodles'),
    (needle: 'pad thai', targetId: 'pad_thai', category: 'noodles'),
    (needle: 'noodle', targetId: 'noodles', category: 'noodles'),
    (needle: 'dumpling', targetId: 'dumplings', category: 'noodles'),
    (needle: 'biryani', targetId: 'biryani', category: 'curry'),
    (needle: 'paella', targetId: 'paella', category: 'rice'),
    (needle: 'pilaf', targetId: 'biryani', category: 'rice'),
    (needle: 'fried rice', targetId: 'fried_rice', category: 'rice'),
    (needle: 'rice', targetId: 'rice_dish', category: 'rice'),
    (needle: 'curry', targetId: 'curry', category: 'curry'),
    (needle: 'masala', targetId: 'tikka_masala', category: 'curry'),
    (needle: 'korma', targetId: 'curry', category: 'curry'),
    (needle: 'dal', targetId: 'dal', category: 'curry'),
    (needle: 'chowder', targetId: 'clam_chowder', category: 'soup'),
    (needle: 'goulash', targetId: 'goulash', category: 'soup'),
    (needle: 'stew', targetId: 'beef_stew', category: 'soup'),
    (needle: 'chili', targetId: 'chili_con_carne', category: 'soup'),
    (needle: 'broth', targetId: 'soup', category: 'soup'),
    (needle: 'soup', targetId: 'soup', category: 'soup'),
    (needle: 'slaw', targetId: 'coleslaw', category: 'salad'),
    (needle: 'salad', targetId: 'garden_salad', category: 'salad'),
    (needle: 'steak', targetId: 'steak', category: 'meat'),
    (needle: 'beef', targetId: 'beef', category: 'meat'),
    (needle: 'veal', targetId: 'beef', category: 'meat'),
    (needle: 'lamb', targetId: 'lamb_chop', category: 'meat'),
    (needle: 'chicken', targetId: 'chicken', category: 'poultry'),
    (needle: 'turkey', targetId: 'turkey_breast', category: 'poultry'),
    (needle: 'duck', targetId: 'duck_roast', category: 'poultry'),
    (needle: 'bacon', targetId: 'bacon', category: 'meat'),
    (needle: 'sausage', targetId: 'sausage', category: 'meat'),
    (needle: 'ham', targetId: 'pork', category: 'meat'),
    (needle: 'pork', targetId: 'pork', category: 'meat'),
    (needle: 'salmon', targetId: 'salmon_fillet', category: 'seafood'),
    (needle: 'tuna', targetId: 'tuna_canned', category: 'seafood'),
    (needle: 'cod', targetId: 'baked_cod', category: 'seafood'),
    (needle: 'shrimp', targetId: 'shrimp', category: 'seafood'),
    (needle: 'crab', targetId: 'crab', category: 'seafood'),
    (needle: 'lobster', targetId: 'lobster', category: 'seafood'),
    (needle: 'seafood', targetId: 'seafood', category: 'seafood'),
    (needle: 'fish', targetId: 'fish', category: 'seafood'),
    (needle: 'croissant', targetId: 'croissant', category: 'bread'),
    (needle: 'bagel', targetId: 'bagel', category: 'bread'),
    (needle: 'muffin', targetId: 'muffin', category: 'bread'),
    (needle: 'donut', targetId: 'donut', category: 'dessert'),
    (needle: 'doughnut', targetId: 'donut', category: 'dessert'),
    (needle: 'biscuit', targetId: 'biscuit', category: 'bread'),
    (needle: 'scone', targetId: 'scone', category: 'bread'),
    (needle: 'pretzel', targetId: 'pretzel', category: 'bread'),
    (needle: 'pita', targetId: 'pita_bread', category: 'bread'),
    (needle: 'tortilla', targetId: 'tortilla', category: 'bread'),
    (needle: 'toast', targetId: 'bread', category: 'bread'),
    (needle: 'bun', targetId: 'bread', category: 'bread'),
    (needle: 'roll', targetId: 'bread', category: 'bread'),
    (needle: 'bread', targetId: 'bread', category: 'bread'),
    (needle: 'cheesecake', targetId: 'cheesecake', category: 'dessert'),
    (needle: 'cupcake', targetId: 'cupcake', category: 'dessert'),
    (needle: 'brownie', targetId: 'brownie', category: 'dessert'),
    (needle: 'cake', targetId: 'cake', category: 'dessert'),
    (needle: 'cobbler', targetId: 'cinnamon_apple_crisp', category: 'dessert'),
    (needle: 'tart', targetId: 'fruit_tart', category: 'dessert'),
    (needle: 'pie', targetId: 'pie', category: 'pie'),
    (needle: 'ice cream', targetId: 'ice_cream', category: 'dessert'),
    (needle: 'gelato', targetId: 'gelato', category: 'dessert'),
    (needle: 'pudding', targetId: 'pudding', category: 'dessert'),
    (needle: 'cookie', targetId: 'cookie', category: 'dessert'),
    (needle: 'pastry', targetId: 'dessert', category: 'dessert'),
    (needle: 'dessert', targetId: 'dessert', category: 'dessert'),
    (needle: 'pancake', targetId: 'pancake', category: 'breakfast'),
    (needle: 'waffle', targetId: 'waffle', category: 'breakfast'),
    (needle: 'omelet', targetId: 'omelet', category: 'breakfast'),
    (needle: 'egg', targetId: 'boiled_egg', category: 'breakfast'),
    (needle: 'coffee', targetId: 'black_coffee', category: 'beverage'),
    (needle: 'tea', targetId: 'green_tea', category: 'beverage'),
    (needle: 'juice', targetId: 'orange_juice', category: 'beverage'),
    (needle: 'smoothie', targetId: 'berry_smoothie', category: 'beverage'),
    (needle: 'shake', targetId: 'protein_shake', category: 'beverage'),
    (needle: 'drink', targetId: 'soda', category: 'beverage'),
  ];

  /// Resolves [label] to a guaranteed non-null [NutritionFood] profile.
  NutritionFood mapLabel(String label) => mapLabelDetailed(label).food;

  /// Resolves [label] with resolution tier and matched term metadata.
  NutritionMatch mapLabelDetailed(String label) {
    final normalizedLabel = normalizeNutritionTerm(label);
    if (normalizedLabel.isEmpty) {
      return NutritionMatch(
        food: _fallbackFood(),
        kind: NutritionMatchKind.fallback,
      );
    }

    // Tier 1: Exact name or ID match.
    for (final entry in _indexedFoods) {
      if (entry.normalizedName == normalizedLabel ||
          entry.normalizedId == normalizedLabel) {
        return NutritionMatch(
          food: entry.food,
          kind: NutritionMatchKind.exact,
          matchedTerm: entry.food.name,
        );
      }
    }

    // Tier 2: Exact alias match.
    for (final entry in _indexedFoods) {
      for (final alias in entry.aliases) {
        if (alias.normalized == normalizedLabel) {
          return NutritionMatch(
            food: entry.food,
            kind: NutritionMatchKind.alias,
            matchedTerm: alias.raw,
          );
        }
      }
    }

    // Tier 3: Best / longest whole-token phrase match across name, aliases, keywords.
    final hasVietnameseBun = _hasRawVietnameseBunToken(label);
    final labelTokens = _tokenize(normalizedLabel);
    final mainClauseEnd = _findMainClauseEnd(labelTokens);
    final mainClauseTokens = mainClauseEnd > 0
        ? labelTokens.sublist(0, mainClauseEnd)
        : labelTokens;
    final hasAccompanimentClause = mainClauseTokens.length < labelTokens.length;

    final mainClauseCategoryCandidate = _findBestCategoryCandidateFromTokens(
      mainClauseTokens,
      hasVietnameseBun: hasVietnameseBun,
    );
    final bestCategoryCandidate = mainClauseCategoryCandidate ??
        (hasAccompanimentClause
            ? _findBestCategoryCandidateFromTokens(
                labelTokens,
                hasVietnameseBun: hasVietnameseBun,
              )
            : null);

    var bestKeyword = _findBestKeywordCandidate(
      tokens: mainClauseTokens,
      head: mainClauseCategoryCandidate ?? bestCategoryCandidate,
    );

    // Only fall back to post-preposition tokens if the main clause yielded
    // neither a Tier 3 keyword match nor a Tier 4 category match.
    if (bestKeyword == null &&
        mainClauseCategoryCandidate == null &&
        hasAccompanimentClause) {
      bestKeyword = _findBestKeywordCandidate(
        tokens: labelTokens,
        head: bestCategoryCandidate,
      );
    }

    if (bestKeyword != null) {
      return NutritionMatch(
        food: bestKeyword.food,
        kind: NutritionMatchKind.keyword,
        matchedTerm: bestKeyword.term,
      );
    }

    // Tier 4: Head-noun / ordered category fallback rules.
    if (bestCategoryCandidate != null) {
      final rule = bestCategoryCandidate.rule;
      final byId = catalog.findById(rule.targetId);
      if (byId != null) {
        return NutritionMatch(
          food: byId,
          kind: NutritionMatchKind.category,
          matchedTerm: rule.needle,
        );
      }
      if (rule.category != null) {
        for (final food in catalog.foods) {
          if (food.category.toLowerCase() == rule.category) {
            return NutritionMatch(
              food: food,
              kind: NutritionMatchKind.category,
              matchedTerm: rule.needle,
            );
          }
        }
      }
    }

    // Tier 5: Generic mixed meal fallback.
    return NutritionMatch(
      food: _fallbackFood(),
      kind: NutritionMatchKind.fallback,
    );
  }

  /// Maps top predictions to nutrition profiles, deduplicating repeated
  /// resolved [NutritionFood.id]s while keeping the highest-confidence hit.
  List<MappedFoodPrediction> mapPredictions(List<FoodPrediction> predictions) {
    final sorted = List<FoodPrediction>.from(predictions)
      ..sort((a, b) {
        final byScore = b.confidence.compareTo(a.confidence);
        if (byScore != 0) return byScore;
        return a.rawIndex.compareTo(b.rawIndex);
      });

    final seenFoodIds = <String>{};
    final mapped = <MappedFoodPrediction>[];

    for (final prediction in sorted) {
      final match = mapLabelDetailed(prediction.label);
      final key = match.food.id.isNotEmpty ? match.food.id : match.food.name;
      if (!seenFoodIds.add(key)) continue;

      mapped.add(
        MappedFoodPrediction(
          prediction: prediction.copyWith(
            matchedFood: match.food,
            matchSource: match.kind.name,
          ),
          match: match,
        ),
      );
    }

    return List<MappedFoodPrediction>.unmodifiable(mapped);
  }

  NutritionFood _fallbackFood() {
    return catalog.findById('mixed_meal') ??
        (catalog.foods.isNotEmpty ? catalog.foods.first : _builtInFallback);
  }

  static List<_IndexedFood> _buildIndex(NutritionCatalog catalog) {
    return catalog.foods.map((food) {
      final normName = normalizeNutritionTerm(food.name);
      final normId = normalizeNutritionTerm(food.id);
      final aliasEntries = <_TermEntry>[];
      final phraseEntries = <_PhraseEntry>[];

      if (normName.isNotEmpty) {
        phraseEntries.add(
          _PhraseEntry(
            raw: food.name,
            normalized: normName,
            tokens: _tokenize(normName),
            priorityBoost: 3,
          ),
        );
      }

      for (final alias in food.aliases) {
        final normAlias = normalizeNutritionTerm(alias);
        if (normAlias.isEmpty) continue;
        aliasEntries.add(_TermEntry(raw: alias, normalized: normAlias));
        phraseEntries.add(
          _PhraseEntry(
            raw: alias,
            normalized: normAlias,
            tokens: _tokenize(normAlias),
            priorityBoost: 2,
          ),
        );
      }

      for (final keyword in food.keywords) {
        final normKeyword = normalizeNutritionTerm(keyword);
        if (normKeyword.isEmpty) continue;
        phraseEntries.add(
          _PhraseEntry(
            raw: keyword,
            normalized: normKeyword,
            tokens: _tokenize(normKeyword),
            priorityBoost: 1,
          ),
        );
      }

      return _IndexedFood(
        food: food,
        normalizedName: normName,
        normalizedId: normId,
        aliases: aliasEntries,
        phrases: phraseEntries,
      );
    }).toList(growable: false);
  }

  static List<String> _tokenize(String normalized) {
    if (normalized.isEmpty) return const <String>[];
    return normalized
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  _KeywordCandidate? _findBestKeywordCandidate({
    required List<String> tokens,
    required _CategoryCandidate? head,
  }) {
    _KeywordCandidate? bestKeyword;
    for (final entry in _indexedFoods) {
      for (final phrase in entry.phrases) {
        if (phrase.tokens.isEmpty) continue;
        // Let Tier 4 _categoryRules handle single-token generic category needles.
        if (phrase.tokens.length == 1 &&
            _categoryNeedleSingles.contains(_singularize(phrase.tokens.single))) {
          continue;
        }
        final span = _findTokenSubsequenceSpan(tokens, phrase.tokens);
        if (span == null) continue;

        // Guard against "jelly bean" colliding with "beans" -> black_beans.
        if (phrase.tokens.length == 1 &&
            _singularize(phrase.tokens.single) == 'bean' &&
            span.start > 0 &&
            tokens[span.start - 1] == 'jelly') {
          continue;
        }

        if (_isShadowedByCategoryHead(
          food: entry.food,
          phrase: phrase,
          matchStart: span.start,
          matchEnd: span.end,
          head: head,
        )) {
          continue;
        }

        final score = (phrase.tokens.length * 100) +
            phrase.normalized.length +
            phrase.priorityBoost;
        if (bestKeyword == null || score > bestKeyword.score) {
          bestKeyword = _KeywordCandidate(
            food: entry.food,
            term: phrase.raw,
            score: score,
          );
        }
      }
    }
    return bestKeyword;
  }

  static bool _hasRawVietnameseBunToken(String label) {
    final rawTokens = label
        .toLowerCase()
        .replaceAll(RegExp(r'''[-_/,'’‘"“”().:&+]'''), ' ')
        .split(RegExp(r'\s+'));
    return rawTokens.any(
      (token) => token == 'bún' || token == 'bu\u0301n',
    );
  }

  static int _findMainClauseEnd(List<String> labelTokens) {
    for (var i = 0; i < labelTokens.length; i++) {
      if (_accompanimentPrepositions.contains(labelTokens[i])) {
        return i;
      }
    }
    return labelTokens.length;
  }

  static bool _isShadowedByCategoryHead({
    required NutritionFood food,
    required _PhraseEntry phrase,
    required int matchStart,
    required int matchEnd,
    required _CategoryCandidate? head,
  }) {
    if (head == null) return false;
    final headCategory = head.rule.category;
    if (head.isDishHead) {
      if (phrase.tokens.length == 1) {
        // A single-token modifier/ingredient of a different category must not
        // override a prepared dish head-noun (e.g. "Apple cake", "Mutton curry",
        // "Eggplant Salad", "Sausage sandwich").
        if (headCategory != null && food.category != headCategory) {
          return true;
        }
        if (_rawIngredientCategories.contains(food.category)) {
          return true;
        }
      } else if (matchEnd <= head.start) {
        // Multi-word modifier preceding the head noun (e.g. "Peanut butter cookie",
        // "Sweet potato soup", "Green tea ice cream") must not shadow the dish.
        if (headCategory != null && food.category != headCategory) {
          return true;
        }
        if (_rawIngredientCategories.contains(food.category)) {
          return true;
        }
      }
      return false;
    }

    // Protein / egg / beverage head-noun: prevent raw ingredient/condiment/fat
    // modifiers preceding the head noun from shadowing it (e.g. "Honey glazed salmon").
    if (_rawIngredientCategories.contains(food.category) &&
        matchEnd <= head.start) {
      return true;
    }
    // Prevent single-token side accompaniments (e.g. "grits" in "Shrimp and grits")
    // from overriding a protein/egg/seafood head-noun.
    if (head.headPriority == 1 &&
        phrase.tokens.length == 1 &&
        food.category == 'side') {
      return true;
    }
    // Prevent single-token dessert/snack flavor modifiers preceding a beverage
    // head (e.g. "chocolate" in "Chocolate shake") from hijacking beverages.
    if (head.headPriority == 0 &&
        phrase.tokens.length == 1 &&
        matchEnd <= head.start &&
        (food.category == 'dessert' || food.category == 'snack')) {
      return true;
    }
    return false;
  }

  static _CategoryCandidate? _findBestCategoryCandidateFromTokens(
    List<String> tokens, {
    required bool hasVietnameseBun,
  }) {
    if (tokens.isEmpty) return null;
    final candidates = _collectCategoryCandidates(
      tokens,
      hasVietnameseBun: hasVietnameseBun,
    );
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final byPriority = b.headPriority.compareTo(a.headPriority);
      if (byPriority != 0) return byPriority;
      final byEnd = b.end.compareTo(a.end);
      if (byEnd != 0) return byEnd;
      final byLen = b.tokenCount.compareTo(a.tokenCount);
      if (byLen != 0) return byLen;
      return a.ruleIndex.compareTo(b.ruleIndex);
    });
    return candidates.first;
  }

  static List<_CategoryCandidate> _collectCategoryCandidates(
    List<String> tokens, {
    required bool hasVietnameseBun,
  }) {
    final results = <_CategoryCandidate>[];
    for (var i = 0; i < _categoryRules.length; i++) {
      final rule = _categoryRules[i];
      final needleTokens = _tokenize(rule.needle);
      final span = _findTokenSubsequenceSpan(
        tokens,
        needleTokens,
        preferLast: true,
      );
      if (span != null) {
        final effectiveRule = (hasVietnameseBun && rule.needle == 'bun')
            ? (needle: 'bún', targetId: 'noodles', category: 'noodles')
            : rule;
        final int headPriority;
        if (_beverageCategoryNeedles.contains(effectiveRule.needle)) {
          headPriority = 0;
        } else if (_nonDishCategoryNeedles.contains(effectiveRule.needle)) {
          headPriority = 1;
        } else {
          headPriority = 2;
        }
        results.add(
          _CategoryCandidate(
            rule: effectiveRule,
            ruleIndex: i,
            start: span.start,
            end: span.end,
            tokenCount: needleTokens.length,
            headPriority: headPriority,
          ),
        );
      }
    }
    return results;
  }

  static ({int start, int end})? _findTokenSubsequenceSpan(
    List<String> haystack,
    List<String> needle, {
    bool preferLast = false,
  }) {
    if (needle.isEmpty || needle.length > haystack.length) {
      return null;
    }
    ({int start, int end})? found;
    for (var start = 0; start <= haystack.length - needle.length; start++) {
      var matched = true;
      for (var offset = 0; offset < needle.length; offset++) {
        if (!_tokensMatch(haystack[start + offset], needle[offset])) {
          matched = false;
          break;
        }
      }
      if (matched) {
        found = (start: start, end: start + needle.length);
        if (!preferLast) return found;
      }
    }
    return found;
  }

  static bool _tokensMatch(String a, String b) {
    if (a == b) return true;
    return _singularize(a) == _singularize(b);
  }

  static String _singularize(String token) {
    if (token.length <= 3) return token;
    if (token.endsWith('ies') && token.length > 4) {
      return '${token.substring(0, token.length - 3)}y';
    }
    if (token.endsWith('ses') && token.length > 4) {
      return token.substring(0, token.length - 2);
    }
    if (token.endsWith('s') && !token.endsWith('ss')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }
}

class _IndexedFood {
  const _IndexedFood({
    required this.food,
    required this.normalizedName,
    required this.normalizedId,
    required this.aliases,
    required this.phrases,
  });

  final NutritionFood food;
  final String normalizedName;
  final String normalizedId;
  final List<_TermEntry> aliases;
  final List<_PhraseEntry> phrases;
}

class _TermEntry {
  const _TermEntry({
    required this.raw,
    required this.normalized,
  });

  final String raw;
  final String normalized;
}

class _PhraseEntry {
  const _PhraseEntry({
    required this.raw,
    required this.normalized,
    required this.tokens,
    required this.priorityBoost,
  });

  final String raw;
  final String normalized;
  final List<String> tokens;
  final int priorityBoost;
}

class _KeywordCandidate {
  const _KeywordCandidate({
    required this.food,
    required this.term,
    required this.score,
  });

  final NutritionFood food;
  final String term;
  final int score;
}

class _CategoryCandidate {
  const _CategoryCandidate({
    required this.rule,
    required this.ruleIndex,
    required this.start,
    required this.end,
    required this.tokenCount,
    required this.headPriority,
  });

  final ({String needle, String targetId, String? category}) rule;
  final int ruleIndex;
  final int start;
  final int end;
  final int tokenCount;
  final int headPriority;

  bool get isDishHead => headPriority >= 2;
}
