import 'package:flutter/material.dart';

import '../contracts/health_data_store.dart';

/// Descriptor for a mini-app module hosted inside HealthKeepr.
class HealthMiniApp {
  const HealthMiniApp({
    required this.id,
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconAsset,
    this.iconAssetPackage,
    required this.isInstalled,
    required this.onLaunch,
  }) : assert(
         icon != null || iconAsset != null,
         'Either icon or iconAsset must be provided',
       );

  /// Unique module identifier used to namespace local storage.
  final String id;

  /// Display title shown in the HealthKeepr hub.
  final String title;

  /// Short description of the module's capabilities.
  final String subtitle;

  /// Leading icon representing the module.
  final IconData? icon;

  /// Optional asset path for a custom icon image (rendered via [ImageIcon]).
  final String? iconAsset;

  /// Optional package name owning [iconAsset].
  final String? iconAssetPackage;

  /// Whether the deferred module library is currently loaded/installed.
  final bool isInstalled;

  /// Callback invoked when the user taps to launch this module.
  final Future<void> Function(BuildContext context, HealthDataStore store)
      onLaunch;
}
