import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../contracts/health_data_store.dart';
import '../registry/health_mini_app.dart';
import 'ml/food_classifier.dart';
import 'ml/litert_food_classifier.dart';
import 'sync/nutrition_health_connect_gateway.dart';
import 'ui/food_tracker_screen.dart';

/// Image acquisition source for Food Snap.
enum FoodImageOrigin { camera, gallery }

/// Host-supplied cropper callback returning PNG/JPEG bytes or `null` if cancelled.
typedef FoodPlateCropper =
    Future<Uint8List?> Function(BuildContext context, String imagePath);

/// Image picker callback returning a local file path or `null` if cancelled.
typedef FoodImageSourcePicker =
    Future<String?> Function(BuildContext context, FoodImageOrigin origin);

/// Launcher and host-integration registry for the Food Snap & Tracker mini-app.
class FoodTrackerLauncher {
  FoodTrackerLauncher._();

  static const String moduleId = 'food_tracker';

  static FoodPlateCropper? _defaultCropper;
  static FoodClassifier Function()? _defaultClassifierFactory;
  static FoodImageSourcePicker? _defaultImagePicker;

  /// Currently registered default plate cropper callback, if any.
  static FoodPlateCropper? get defaultCropper => _defaultCropper;

  /// Currently registered default classifier factory, if any.
  static FoodClassifier Function()? get defaultClassifierFactory =>
      _defaultClassifierFactory;

  /// Currently registered default image picker callback, if any.
  static FoodImageSourcePicker? get defaultImagePicker => _defaultImagePicker;

  /// Registers a host-provided plate cropper (for example `SimpleCropper`).
  static void registerDefaultCropper(FoodPlateCropper? cropper) {
    _defaultCropper = cropper;
  }

  /// Registers a factory used when [FoodTrackerScreen] creates a classifier.
  static void registerDefaultClassifierFactory(
    FoodClassifier Function()? factory,
  ) {
    _defaultClassifierFactory = factory;
  }

  /// Registers a default image source picker (useful for host overrides/tests).
  static void registerDefaultImagePicker(FoodImageSourcePicker? picker) {
    _defaultImagePicker = picker;
  }

  /// Creates a [FoodClassifier] using the registered factory or [LiteRtFoodClassifier].
  static FoodClassifier createDefaultClassifier() {
    return _defaultClassifierFactory?.call() ?? LiteRtFoodClassifier();
  }

  /// Picks a meal photo using the registered picker or `image_picker`.
  static Future<String?> pickImageWithDefault(
    BuildContext context,
    FoodImageOrigin origin,
  ) async {
    final registered = _defaultImagePicker;
    if (registered != null) {
      return registered(context, origin);
    }
    final picked = await ImagePicker().pickImage(
      source: origin == FoodImageOrigin.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 92,
    );
    return picked?.path;
  }

  /// Builds the [HealthMiniApp] descriptor for Food Snap & Tracker.
  static HealthMiniApp descriptor({
    FoodPlateCropper? cropper,
    FoodClassifier? classifier,
    FoodImageSourcePicker? imagePicker,
    NutritionHealthConnectGateway? healthConnectGateway,
  }) {
    return HealthMiniApp(
      id: moduleId,
      title: 'Food Snap & Tracker',
      subtitle: 'food scanner & daily macro log',
      icon: Icons.restaurant_rounded,
      isInstalled: true,
      onLaunch: (context, store) => launch(
        context,
        store,
        cropper: cropper,
        classifier: classifier,
        imagePicker: imagePicker,
        healthConnectGateway: healthConnectGateway,
      ),
    );
  }

  /// Pushes [FoodTrackerScreen] onto [context]'s navigator.
  static Future<void> launch(
    BuildContext context,
    HealthDataStore store, {
    FoodPlateCropper? cropper,
    FoodClassifier? classifier,
    FoodImageSourcePicker? imagePicker,
    NutritionHealthConnectGateway? healthConnectGateway,
  }) async {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FoodTrackerScreen(
          store: store,
          cropper: cropper,
          classifier: classifier,
          imagePicker: imagePicker,
          healthConnectGateway: healthConnectGateway,
        ),
      ),
    );
  }
}
