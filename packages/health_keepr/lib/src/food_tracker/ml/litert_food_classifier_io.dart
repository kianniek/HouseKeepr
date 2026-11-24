import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';

import '../models/food_prediction.dart';
import 'food_asset_loader.dart';
import 'food_classifier.dart';
import 'image_preprocessor.dart';

/// Creates the native IO [FoodClassifier] backed by `flutter_litert`.
FoodClassifier createLiteRtFoodClassifier({
  required String modelAssetPath,
  required String labelsAssetPath,
  AssetBundle? bundle,
  int threads = 2,
}) {
  return _IoLiteRtFoodClassifier(
    modelAssetPath: modelAssetPath,
    labelsAssetPath: labelsAssetPath,
    bundle: bundle,
    threads: threads,
  );
}

class _IoLiteRtFoodClassifier implements FoodClassifier {
  _IoLiteRtFoodClassifier({
    required this.modelAssetPath,
    required this.labelsAssetPath,
    this.bundle,
    this.threads = 2,
  });

  final String modelAssetPath;
  final String labelsAssetPath;
  final AssetBundle? bundle;
  final int threads;

  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  List<String> _labels = const <String>[];
  int _inputHeight = ImagePreprocessor.defaultInputSize;
  int _inputWidth = ImagePreprocessor.defaultInputSize;
  int _numClasses = 2024;
  double _outputScale = 1.0 / 256.0;
  int _outputZeroPoint = 0;

  Future<void>? _initFuture;
  Future<void> _activeRun = Future<void>.value();
  bool _disposed = false;

  @override
  Future<void> warmUp() {
    if (_disposed) {
      return Future<void>.error(
        StateError('LiteRtFoodClassifier has already been disposed.'),
      );
    }
    if (_isolateInterpreter != null) {
      return Future<void>.value();
    }
    return _initFuture ??= _initialize().catchError((Object error, StackTrace stack) {
      _initFuture = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _initialize() async {
    final modelBytes = await loadFoodAssetBytes(
      modelAssetPath,
      bundle: bundle,
    );
    final rawLabels = await loadFoodAssetString(
      labelsAssetPath,
      bundle: bundle,
    );
    if (_disposed) {
      throw StateError('LiteRtFoodClassifier was disposed during warmUp.');
    }

    final parsedLabels = FoodClassifier.parseLabels(rawLabels);
    final options = InterpreterOptions()..threads = threads;
    final interpreter = Interpreter.fromBuffer(modelBytes, options: options);
    try {
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);

      final inputShape = inputTensor.shape;
      if (inputShape.length == 4 &&
          inputShape[1] > 0 &&
          inputShape[2] > 0) {
        _inputHeight = inputShape[1];
        _inputWidth = inputShape[2];
      }

      final outputShape = outputTensor.shape;
      if (outputShape.isNotEmpty && outputShape.last > 0) {
        _numClasses = outputShape.last;
      } else if (parsedLabels.isNotEmpty) {
        _numClasses = parsedLabels.length;
      }

      final quantParams = outputTensor.params;
      _outputScale =
          quantParams.scale > 0 ? quantParams.scale : (1.0 / 256.0);
      _outputZeroPoint = quantParams.zeroPoint;

      final isolateInterpreter = await IsolateInterpreter.create(
        address: interpreter.address,
        debugName: 'FoodClassifierIsolate',
      );

      if (_disposed) {
        await isolateInterpreter.close();
        interpreter.close();
        throw StateError('LiteRtFoodClassifier was disposed during warmUp.');
      }

      _labels = parsedLabels;
      _interpreter = interpreter;
      _isolateInterpreter = isolateInterpreter;
    } catch (_) {
      if (_interpreter == null && !interpreter.isDeleted) {
        interpreter.close();
      }
      rethrow;
    }
  }

  @override
  Future<List<FoodPrediction>> classifyImageBytes(
    Uint8List imageBytes, {
    int topK = 5,
  }) async {
    if (_disposed) {
      throw StateError('LiteRtFoodClassifier has already been disposed.');
    }

    await warmUp();
    final isolateInterpreter = _isolateInterpreter;
    if (_disposed || isolateInterpreter == null) {
      throw StateError('LiteRtFoodClassifier is not available.');
    }

    final rgbBytes = await ImagePreprocessor.preprocessToRgbBytes(
      imageBytes,
      width: _inputWidth,
      height: _inputHeight,
    );

    final runFuture = _activeRun.then((_) async {
      if (_disposed) {
        throw StateError('LiteRtFoodClassifier has already been disposed.');
      }
      final input = rgbBytes.reshape<int>(
        <int>[1, _inputHeight, _inputWidth, 3],
      );
      final output = List<int>.filled(_numClasses, 0).reshape<int>(
        <int>[1, _numClasses],
      );

      await isolateInterpreter.run(input, output);
      final rawScores = (output[0] as List<dynamic>).cast<int>();
      return FoodClassifier.postProcessScores(
        rawScores,
        _labels,
        topK: topK,
        scale: _outputScale,
        zeroPoint: _outputZeroPoint,
      );
    });

    _activeRun = runFuture.then((_) {}, onError: (_) {});
    return runFuture;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    try {
      await _initFuture?.catchError((_) {});
    } catch (_) {}
    try {
      await _activeRun;
    } catch (_) {}

    final isolateInterpreter = _isolateInterpreter;
    _isolateInterpreter = null;
    if (isolateInterpreter != null) {
      await isolateInterpreter.close();
    }

    final interpreter = _interpreter;
    _interpreter = null;
    if (interpreter != null && !interpreter.isDeleted) {
      interpreter.close();
    }
  }
}
