import 'package:flutter/services.dart';

import '../models/food_prediction.dart';
import 'food_classifier.dart';

/// Creates the platform-specific [FoodClassifier] implementation.
FoodClassifier createLiteRtFoodClassifier({
  required String modelAssetPath,
  required String labelsAssetPath,
  AssetBundle? bundle,
  int threads = 2,
}) {
  return _StubLiteRtFoodClassifier();
}

class _StubLiteRtFoodClassifier implements FoodClassifier {
  @override
  Future<void> warmUp() {
    return Future<void>.error(
      UnsupportedError(
        'On-device LiteRT food classification is only supported on IO/Android platforms.',
      ),
    );
  }

  @override
  Future<List<FoodPrediction>> classifyImageBytes(
    Uint8List imageBytes, {
    int topK = 5,
  }) {
    return Future<List<FoodPrediction>>.error(
      UnsupportedError(
        'On-device LiteRT food classification is only supported on IO/Android platforms.',
      ),
    );
  }

  @override
  Future<void> dispose() => Future<void>.value();
}
