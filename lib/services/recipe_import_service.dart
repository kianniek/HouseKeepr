import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;

import '../core/grocery_parser.dart';

class ImportedRecipe extends Equatable {
  final String title;
  final String url;
  final String sourceName;
  final int? servings;
  final String? imageUrl;
  final List<ParsedGroceryItem> ingredients;

  const ImportedRecipe({
    required this.title,
    required this.url,
    required this.sourceName,
    this.servings,
    this.imageUrl,
    required this.ingredients,
  });

  @override
  List<Object?> get props => [
    title,
    url,
    sourceName,
    servings,
    imageUrl,
    ingredients,
  ];
}

class RecipeFetchException implements Exception {
  final String message;
  final int? statusCode;

  const RecipeFetchException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class RecipeParseException implements Exception {
  final String message;

  const RecipeParseException(this.message);

  @override
  String toString() => message;
}

/// Fetches a recipe webpage and extracts structured recipe metadata &
/// ingredients using Schema.org JSON-LD, Microdata, or HTML list fallbacks.
class RecipeImportService {
  final http.Client _client;
  final Duration timeout;

  RecipeImportService({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  /// Returns true if [input] looks like an HTTP(S) URL.
  static bool isRecipeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.host.contains('.');
  }

  /// Derives a friendly display name for the recipe's source domain.
  static String deriveSourceName(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return 'Recipe';
    var host = uri.host.toLowerCase();
    if (host.startsWith('www.')) {
      host = host.substring(4);
    }
    if (host == 'ah.nl' || host.endsWith('.ah.nl')) {
      return 'Albert Heijn';
    }
    if (host == 'jumbo.com' || host.endsWith('.jumbo.com')) {
      return 'Jumbo';
    }
    if (host == 'plus.nl' || host.endsWith('.plus.nl')) {
      return 'PLUS';
    }
    if (host == 'lidl.nl' || host.endsWith('.lidl.nl')) {
      return 'Lidl';
    }
    if (host == 'aldi.nl' || host.endsWith('.aldi.nl')) {
      return 'Aldi';
    }
    return host;
  }

  /// Fetches [url] and parses its recipe data.
  Future<ImportedRecipe> fetchAndParse(String url) async {
    final trimmedUrl = url.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !isRecipeUrl(trimmedUrl)) {
      throw const RecipeFetchException('Invalid recipe URL.');
    }

    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
              'Accept-Language': 'nl-NL,nl;q=0.9,en-US;q=0.8,en;q=0.7',
              'Upgrade-Insecure-Requests': '1',
              'Sec-Fetch-Dest': 'document',
              'Sec-Fetch-Mode': 'navigate',
              'Sec-Fetch-Site': 'none',
              'Sec-Fetch-User': '?1',
            },
          )
          .timeout(timeout);
    } catch (e) {
      throw RecipeFetchException('Failed to fetch recipe page: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RecipeFetchException(
        'Recipe page returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    return parseHtml(html, url: trimmedUrl);
  }

  /// Builds an [ImportedRecipe] from manually pasted ingredient lines when
  /// a website blocks automated fetching (e.g. HTTP 403).
  ImportedRecipe fromManualIngredients({
    required String url,
    required String title,
    int? servings,
    required String rawIngredientsText,
  }) {
    final trimmedUrl = url.trim();
    final sourceName = deriveSourceName(trimmedUrl);
    final lines = rawIngredientsText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final ingredients = _parseIngredientLines(lines);
    if (ingredients.isEmpty) {
      throw const RecipeParseException(
        'No recipe ingredients could be found in the pasted text.',
      );
    }
    return ImportedRecipe(
      title: title.trim().isEmpty ? sourceName : title.trim(),
      url: trimmedUrl,
      sourceName: sourceName,
      servings: servings,
      ingredients: ingredients,
    );
  }

  /// Parses raw [html] from [url] into an [ImportedRecipe].
  ImportedRecipe parseHtml(String html, {required String url}) {
    final sourceName = deriveSourceName(url);

    // 1. Try Schema.org JSON-LD first (used by AH, Jumbo, WordPress recipe plugins, etc.)
    final jsonLdRecipe = _extractFromJsonLd(html);
    if (jsonLdRecipe != null && jsonLdRecipe.rawIngredients.isNotEmpty) {
      final parsedIngredients = _parseIngredientLines(
        jsonLdRecipe.rawIngredients,
      );
      if (parsedIngredients.isNotEmpty) {
        return ImportedRecipe(
          title:
              _cleanText(jsonLdRecipe.title) ??
              _extractPageTitle(html) ??
              sourceName,
          url: url,
          sourceName: sourceName,
          servings: jsonLdRecipe.servings,
          imageUrl: jsonLdRecipe.imageUrl,
          ingredients: parsedIngredients,
        );
      }
    }

    // 2. Fallback: Microdata (itemprop="recipeIngredient")
    final microdataIngredients = _extractMicrodataIngredients(html);
    if (microdataIngredients.isNotEmpty) {
      final parsedIngredients = _parseIngredientLines(microdataIngredients);
      if (parsedIngredients.isNotEmpty) {
        return ImportedRecipe(
          title:
              _extractMicrodataName(html) ??
              _extractPageTitle(html) ??
              sourceName,
          url: url,
          sourceName: sourceName,
          servings: _extractMicrodataServings(html),
          ingredients: parsedIngredients,
        );
      }
    }

    // 3. Fallback: Heuristic HTML ingredient list
    final heuristicIngredients = _extractHeuristicIngredients(html);
    if (heuristicIngredients.isNotEmpty) {
      final parsedIngredients = _parseIngredientLines(heuristicIngredients);
      if (parsedIngredients.isNotEmpty) {
        return ImportedRecipe(
          title: _extractPageTitle(html) ?? sourceName,
          url: url,
          sourceName: sourceName,
          ingredients: parsedIngredients,
        );
      }
    }

    throw const RecipeParseException(
      'No recipe ingredients could be found on this page.',
    );
  }

  List<ParsedGroceryItem> _parseIngredientLines(List<String> lines) {
    final result = <ParsedGroceryItem>[];
    for (final raw in lines) {
      final cleaned = _cleanText(raw);
      if (cleaned == null || cleaned.isEmpty) continue;
      final parsed = GroceryParser.parseLine(cleaned);
      if (parsed.name.isNotEmpty) {
        result.add(parsed);
      }
    }
    return result;
  }

  _RawRecipeData? _extractFromJsonLd(String html) {
    final scriptRegex = RegExp(
      r'''<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>''',
      caseSensitive: false,
    );

    for (final match in scriptRegex.allMatches(html)) {
      final rawJson = match.group(1)?.trim();
      if (rawJson == null || rawJson.isEmpty) continue;

      dynamic decoded;
      try {
        decoded = json.decode(rawJson);
      } catch (_) {
        continue;
      }

      final recipeNode = _findRecipeNode(decoded);
      if (recipeNode == null) continue;

      final rawIngredients = _extractStringList(recipeNode['recipeIngredient']);
      if (rawIngredients.isEmpty) continue;

      final title = recipeNode['name'] is String
          ? recipeNode['name'] as String
          : null;
      final servings = _parseServings(recipeNode['recipeYield']);
      final imageUrl = _extractImageUrl(recipeNode['image']);

      return _RawRecipeData(
        title: title,
        rawIngredients: rawIngredients,
        servings: servings,
        imageUrl: imageUrl,
      );
    }
    return null;
  }

  Map<String, dynamic>? _findRecipeNode(dynamic node) {
    if (node is Map<String, dynamic>) {
      if (_isRecipeType(node['@type'])) {
        return node;
      }
      final graph = node['@graph'];
      if (graph is List) {
        for (final item in graph) {
          final found = _findRecipeNode(item);
          if (found != null) return found;
        }
      }
      for (final value in node.values) {
        if (value is Map || value is List) {
          final found = _findRecipeNode(value);
          if (found != null) return found;
        }
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findRecipeNode(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  bool _isRecipeType(dynamic typeField) {
    if (typeField is String) {
      return typeField.toLowerCase() == 'recipe' ||
          typeField.toLowerCase().endsWith('/recipe');
    }
    if (typeField is List) {
      return typeField.any(_isRecipeType);
    }
    return false;
  }

  List<String> _extractStringList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(RegExp(r'\r?\n'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  int? _parseServings(dynamic rawYield) {
    String? text;
    if (rawYield is int) return rawYield > 0 ? rawYield : null;
    if (rawYield is num) return rawYield > 0 ? rawYield.toInt() : null;
    if (rawYield is String) {
      text = rawYield;
    } else if (rawYield is List && rawYield.isNotEmpty) {
      text = rawYield.first.toString();
    }
    if (text == null) return null;
    final match = RegExp(r'\b(\d{1,2})\b').firstMatch(text);
    if (match == null) return null;
    final parsed = int.tryParse(match.group(1)!);
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  String? _extractImageUrl(dynamic rawImage) {
    if (rawImage is String && rawImage.startsWith('http')) {
      return rawImage;
    }
    if (rawImage is List && rawImage.isNotEmpty) {
      return _extractImageUrl(rawImage.first);
    }
    if (rawImage is Map<String, dynamic>) {
      final url = rawImage['url'] ?? rawImage['contentUrl'];
      if (url is String && url.startsWith('http')) return url;
    }
    return null;
  }

  List<String> _extractMicrodataIngredients(String html) {
    final regex = RegExp(
      r'''itemprop\s*=\s*["'](?:recipeIngredient|ingredients)["'][^>]*>([\s\S]*?)</(?:li|span|p|div)>''',
      caseSensitive: false,
    );
    return regex
        .allMatches(html)
        .map((m) => _stripHtmlTags(m.group(1) ?? ''))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String? _extractMicrodataName(String html) {
    final regex = RegExp(
      r'''itemtype\s*=\s*["']https?://schema\.org/Recipe["'][\s\S]{0,2000}?itemprop\s*=\s*["']name["'][^>]*>([\s\S]*?)</''',
      caseSensitive: false,
    );
    final match = regex.firstMatch(html);
    if (match == null) return null;
    return _cleanText(_stripHtmlTags(match.group(1) ?? ''));
  }

  int? _extractMicrodataServings(String html) {
    final regex = RegExp(
      r'''itemprop\s*=\s*["']recipeYield["'][^>]*>([\s\S]*?)</''',
      caseSensitive: false,
    );
    final match = regex.firstMatch(html);
    if (match == null) return null;
    return _parseServings(_stripHtmlTags(match.group(1) ?? ''));
  }

  List<String> _extractHeuristicIngredients(String html) {
    final containerRegex = RegExp(
      r'''<(?:ul|ol)[^>]*class\s*=\s*["'][^"']*ingredient[^"']*["'][^>]*>([\s\S]*?)</(?:ul|ol)>''',
      caseSensitive: false,
    );
    final liRegex = RegExp(r'<li[^>]*>([\s\S]*?)</li>', caseSensitive: false);
    for (final container in containerRegex.allMatches(html)) {
      final items = liRegex
          .allMatches(container.group(1) ?? '')
          .map((m) => _stripHtmlTags(m.group(1) ?? ''))
          .where((s) => s.isNotEmpty)
          .toList();
      if (items.isNotEmpty) return items;
    }
    return const [];
  }

  String? _extractPageTitle(String html) {
    final ogTitle = RegExp(
      r'''<meta[^>]*property\s*=\s*["']og:title["'][^>]*content\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    if (ogTitle != null) {
      final cleaned = _cleanText(ogTitle.group(1));
      if (cleaned != null && cleaned.isNotEmpty) return cleaned;
    }

    final h1 = RegExp(
      r'<h1[^>]*>([\s\S]*?)</h1>',
      caseSensitive: false,
    ).firstMatch(html);
    if (h1 != null) {
      final cleaned = _cleanText(_stripHtmlTags(h1.group(1) ?? ''));
      if (cleaned != null && cleaned.isNotEmpty) return cleaned;
    }

    final titleTag = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (titleTag != null) {
      final cleaned = _cleanText(_stripHtmlTags(titleTag.group(1) ?? ''));
      if (cleaned != null && cleaned.isNotEmpty) return cleaned;
    }
    return null;
  }

  static String _stripHtmlTags(String raw) {
    return raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
  }

  static String? _cleanText(String? raw) {
    if (raw == null) return null;
    var text = _decodeHtmlEntities(raw);
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? null : text;
  }

  static String _decodeHtmlEntities(String input) {
    var result = input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&frac12;', '1/2')
        .replaceAll('&frac14;', '1/4')
        .replaceAll('&frac34;', '3/4')
        .replaceAll('½', '1/2')
        .replaceAll('¼', '1/4')
        .replaceAll('¾', '3/4');

    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    });
    result = result.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    });
    return result;
  }
}

class _RawRecipeData {
  final String? title;
  final List<String> rawIngredients;
  final int? servings;
  final String? imageUrl;

  const _RawRecipeData({
    required this.title,
    required this.rawIngredients,
    this.servings,
    this.imageUrl,
  });
}
