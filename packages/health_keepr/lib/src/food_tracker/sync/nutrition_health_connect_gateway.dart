import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/meal_log.dart';

/// Availability of Android Health Connect for Food Snap nutrition writes.
enum NutritionHealthConnectStatus {
  available,
  providerUpdateRequired,
  unavailable,
}

/// Platform abstraction for writing Food Snap meals to Android Health Connect.
abstract class NutritionHealthConnectGateway {
  Future<NutritionHealthConnectStatus> getSdkStatus();
  Future<bool> hasWriteNutritionPermission();
  Future<bool> requestWriteNutritionPermission();
  Future<void> openHealthConnectSettings();
  Future<String?> writeNutritionRecord(MealLog log);
}

/// Default [NutritionHealthConnectGateway] backed by `housekeepr/health_connect`.
///
/// Degrades gracefully on non-Android platforms, missing plugins, or platform
/// exceptions so local food logging never fails.
class MethodChannelNutritionHealthConnectGateway
    implements NutritionHealthConnectGateway {
  MethodChannelNutritionHealthConnectGateway({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('housekeepr/health_connect');

  static const String writeNutritionPermissionKey = 'write_nutrition';

  final MethodChannel _channel;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<NutritionHealthConnectStatus> getSdkStatus() async {
    if (!_isAndroid) {
      return NutritionHealthConnectStatus.unavailable;
    }
    try {
      final raw = await _channel.invokeMethod<String>('getSdkStatus');
      return switch (raw) {
        'available' => NutritionHealthConnectStatus.available,
        'providerUpdateRequired' =>
          NutritionHealthConnectStatus.providerUpdateRequired,
        _ => NutritionHealthConnectStatus.unavailable,
      };
    } on MissingPluginException {
      return NutritionHealthConnectStatus.unavailable;
    } on PlatformException {
      return NutritionHealthConnectStatus.unavailable;
    }
  }

  @override
  Future<bool> hasWriteNutritionPermission() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final granted = await _channel.invokeMethod<bool>(
        'hasPermissions',
        <String, dynamic>{
          'permissions': const <String>[writeNutritionPermissionKey],
        },
      );
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> requestWriteNutritionPermission() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'requestPermissions',
        <String, dynamic>{
          'permissions': const <String>[writeNutritionPermissionKey],
        },
      );
      return (res?['granted'] as bool?) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> openHealthConnectSettings() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('openHealthConnectSettings');
    } on MissingPluginException {
      // No-op when plugin is unavailable.
    } on PlatformException {
      // No-op when settings intent cannot be opened.
    }
  }

  @override
  Future<String?> writeNutritionRecord(MealLog log) async {
    if (!_isAndroid) {
      return null;
    }
    final trimmedName = log.foodName.trim();
    if (log.id.trim().isEmpty || trimmedName.isEmpty) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>(
        'writeNutrition',
        <String, dynamic>{
          'id': log.id,
          'name': trimmedName,
          'mealType': log.mealType.name,
          'timeIso': log.loggedAt,
          'kcal': _nonNegativeFinite(log.kcal),
          'proteinGrams': _nonNegativeFinite(log.proteinGrams),
          'carbsGrams': _nonNegativeFinite(log.carbsGrams),
          'fatGrams': _nonNegativeFinite(log.fatGrams),
        },
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static double _nonNegativeFinite(double value) {
    if (!value.isFinite || value <= 0) {
      return 0.0;
    }
    return value;
  }
}
