import 'dart:math' as math;
import 'dart:typed_data';

import '../models/food_prediction.dart';

/// Contract for offline on-device food classification engines.
abstract class FoodClassifier {
  /// Preloads model weights, labels, and background worker resources.
  Future<void> warmUp();

  /// Classifies encoded PNG or JPEG [imageBytes] into top [topK] predictions.
  Future<List<FoodPrediction>> classifyImageBytes(
    Uint8List imageBytes, {
    int topK = 5,
  });

  /// Releases native interpreter and isolate resources.
  Future<void> dispose();

  /// Parses raw newline-delimited labels while preserving exact 0-based indices.
  static List<String> parseLabels(String rawLabels) {
    final lines = rawLabels
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .toList();
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return List<String>.unmodifiable(lines);
  }

  /// Returns `true` if [label] at [index] is a named food class rather than
  /// `__background__` or an unmapped Knowledge Graph MID (`/g/...`, `/m/...`).
  static bool isValidFoodLabel(int index, String label) {
    if (index == 0) return false;
    final trimmed = label.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == '__background__') return false;
    if (trimmed.startsWith('/')) return false;
    return true;
  }

  /// Converts quantized `UINT8` model scores into sorted [FoodPrediction]s.
  ///
  /// Filters out index `0` (`__background__`) and `/g/` or `/m/` MIDs,
  /// scales scores using `(rawScore - zeroPoint) * scale` (default `1/256.0`),
  /// and sorts deterministically by confidence descending then `rawIndex` ascending.
  static List<FoodPrediction> postProcessScores(
    List<int> rawScores,
    List<String> labels, {
    int topK = 5,
    double minConfidence = 0.0,
    double scale = 1.0 / 256.0,
    int zeroPoint = 0,
  }) {
    if (topK <= 0 || rawScores.isEmpty || labels.isEmpty) {
      return const <FoodPrediction>[];
    }

    final effectiveScale = (scale.isFinite && scale > 0) ? scale : 1.0 / 256.0;
    final count = math.min(rawScores.length, labels.length);
    final results = <FoodPrediction>[];

    for (var i = 0; i < count; i++) {
      final label = labels[i].trim();
      if (!isValidFoodLabel(i, label)) continue;

      final clampedRaw = rawScores[i].clamp(0, 255);
      final confidence =
          ((clampedRaw - zeroPoint) * effectiveScale).clamp(0.0, 1.0);
      if (confidence <= 0.0 || confidence < minConfidence) continue;

      results.add(
        FoodPrediction(
          label: label,
          rawIndex: i,
          confidence: confidence,
        ),
      );
    }

    results.sort((a, b) {
      final byScore = b.confidence.compareTo(a.confidence);
      if (byScore != 0) return byScore;
      return a.rawIndex.compareTo(b.rawIndex);
    });

    if (results.length <= topK) {
      return List<FoodPrediction>.unmodifiable(results);
    }
    return List<FoodPrediction>.unmodifiable(results.take(topK));
  }
}
