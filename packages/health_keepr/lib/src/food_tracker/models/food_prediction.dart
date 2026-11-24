import 'package:flutter/foundation.dart';

import 'nutrition_food.dart';

/// A food classification result optionally enriched with a nutrition profile.
@immutable
class FoodPrediction {
  const FoodPrediction({
    required this.label,
    required this.confidence,
    this.rawIndex = -1,
    this.matchedFood,
    this.matchSource,
  });

  factory FoodPrediction.fromJson(Map<String, dynamic> json) {
    final rawMatched = json['matchedFood'];
    NutritionFood? matchedFood;
    if (rawMatched is Map<String, dynamic>) {
      matchedFood = NutritionFood.fromJson(rawMatched);
    } else if (rawMatched is Map) {
      matchedFood = NutritionFood.fromJson(
        Map<String, dynamic>.from(rawMatched),
      );
    }

    final rawLabel = json['label'];
    final rawIndex = json['rawIndex'];
    final rawConfidence = json['confidence'];
    final rawMatchSource = json['matchSource'];

    return FoodPrediction(
      label: rawLabel is String ? rawLabel : '',
      rawIndex: rawIndex is num ? rawIndex.toInt() : -1,
      confidence: rawConfidence is num && rawConfidence.isFinite
          ? rawConfidence.toDouble()
          : 0.0,
      matchedFood: matchedFood,
      matchSource: rawMatchSource is String ? rawMatchSource : null,
    );
  }

  final String label;
  final int rawIndex;
  final double confidence;
  final NutritionFood? matchedFood;
  final String? matchSource;

  /// Confidence expressed on a `0..100` percentage scale.
  double get confidencePercent => (confidence * 100.0).clamp(0.0, 100.0);

  FoodPrediction copyWith({
    String? label,
    int? rawIndex,
    double? confidence,
    NutritionFood? matchedFood,
    bool clearMatchedFood = false,
    String? matchSource,
    bool clearMatchSource = false,
  }) {
    return FoodPrediction(
      label: label ?? this.label,
      rawIndex: rawIndex ?? this.rawIndex,
      confidence: confidence ?? this.confidence,
      matchedFood:
          clearMatchedFood ? null : (matchedFood ?? this.matchedFood),
      matchSource:
          clearMatchSource ? null : (matchSource ?? this.matchSource),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'rawIndex': rawIndex,
        'confidence': confidence,
        if (matchedFood != null) 'matchedFood': matchedFood!.toJson(),
        if (matchSource != null) 'matchSource': matchSource,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoodPrediction &&
        other.label == label &&
        other.rawIndex == rawIndex &&
        other.confidence == confidence &&
        other.matchedFood == matchedFood &&
        other.matchSource == matchSource;
  }

  @override
  int get hashCode => Object.hash(
        label,
        rawIndex,
        confidence,
        matchedFood,
        matchSource,
      );
}
