import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Package name used for dual-key asset resolution.
const String healthKeeprPackageName = 'health_keepr';

/// Loads a string asset from `packages/health_keepr/` with fallback to
/// package-local relative paths when running tests inside `packages/health_keepr`.
Future<String> loadFoodAssetString(
  String relativePath, {
  AssetBundle? bundle,
}) async {
  final activeBundle = bundle ?? rootBundle;
  final normalized = _stripPackagePrefix(relativePath);
  try {
    return await activeBundle.loadString(
      'packages/$healthKeeprPackageName/$normalized',
    );
  } on FlutterError {
    return activeBundle.loadString(normalized);
  }
}

/// Loads binary asset bytes from `packages/health_keepr/` with fallback to
/// package-local relative paths when running tests inside `packages/health_keepr`.
Future<Uint8List> loadFoodAssetBytes(
  String relativePath, {
  AssetBundle? bundle,
}) async {
  final activeBundle = bundle ?? rootBundle;
  final normalized = _stripPackagePrefix(relativePath);
  ByteData data;
  try {
    data = await activeBundle.load(
      'packages/$healthKeeprPackageName/$normalized',
    );
  } on FlutterError {
    data = await activeBundle.load(normalized);
  }
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

String _stripPackagePrefix(String path) {
  const prefix = 'packages/$healthKeeprPackageName/';
  if (path.startsWith(prefix)) {
    return path.substring(prefix.length);
  }
  return path;
}
