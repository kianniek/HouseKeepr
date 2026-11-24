import 'package:flutter/services.dart';

import '../models/food_prediction.dart';
import 'food_classifier.dart';
import 'litert_food_classifier_stub.dart'
    if (dart.library.io) 'litert_food_classifier_io.dart' as impl;

/// Default asset configuration for [LiteRtFoodClassifier].
abstract final class LiteRtFoodClassifierConfig {
  static const String defaultModelAssetPath = 'assets/ml/food_model.tflite';
  static const String defaultLabelsAssetPath = 'assets/ml/labels.txt';
}

/// Platform-safe [FoodClassifier] facade backed by `flutter_litert` on IO
/// platforms and a clean [UnsupportedError] stub on unsupported targets.
class LiteRtFoodClassifier implements FoodClassifier {
  LiteRtFoodClassifier({
    String modelAssetPath = LiteRtFoodClassifierConfig.defaultModelAssetPath,
    String labelsAssetPath = LiteRtFoodClassifierConfig.defaultLabelsAssetPath,
    AssetBundle? bundle,
    int threads = 2,
  }) : _delegate = impl.createLiteRtFoodClassifier(
          modelAssetPath: modelAssetPath,
          labelsAssetPath: labelsAssetPath,
          bundle: bundle,
          threads: threads,
        );

  final FoodClassifier _delegate;

  @override
  Future<void> warmUp() => _delegate.warmUp();

  @override
  Future<List<FoodPrediction>> classifyImageBytes(
    Uint8List imageBytes, {
    int topK = 5,
  }) =>
      _delegate.classifyImageBytes(imageBytes, topK: topK);

  @override
  Future<void> dispose() => _delegate.dispose();
}
