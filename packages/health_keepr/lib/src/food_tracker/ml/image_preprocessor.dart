import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Off-UI-thread image decoding, orientation baking, center-cropping,
/// and resizing for `UINT8` `[1, H, W, 3]` RGB food models.
class ImagePreprocessor {
  static const int defaultInputSize = 192;

  /// Decodes and resizes encoded PNG/JPEG [imageBytes] inside a background isolate.
  static Future<Uint8List> preprocessToRgbBytes(
    Uint8List imageBytes, {
    int width = defaultInputSize,
    int height = defaultInputSize,
  }) {
    return Isolate.run(
      () => preprocessToRgbBytesSync(
        imageBytes,
        width: width,
        height: height,
      ),
    );
  }

  /// Synchronous variant of [preprocessToRgbBytes] for isolate execution and testing.
  static Uint8List preprocessToRgbBytesSync(
    Uint8List imageBytes, {
    int width = defaultInputSize,
    int height = defaultInputSize,
  }) {
    if (imageBytes.isEmpty) {
      throw const FormatException('Cannot preprocess empty image bytes.');
    }
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Target dimensions must be positive: ${width}x$height');
    }

    img.Image? decoded;
    try {
      decoded = img.decodeImage(imageBytes);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Unable to decode food image bytes: $error');
    }
    if (decoded == null) {
      throw const FormatException('Unable to decode food image bytes.');
    }

    final oriented = img.bakeOrientation(decoded);
    final cropped = _centerCropSquareIfNeeded(oriented);
    final resized = img.copyResize(
      cropped,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );
    final normalized = resized.convert(
      format: img.Format.uint8,
      numChannels: 3,
    );

    final rgbBytes = Uint8List(width * height * 3);
    var offset = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = normalized.getPixel(x, y);
        rgbBytes[offset++] = pixel.r.toInt().clamp(0, 255);
        rgbBytes[offset++] = pixel.g.toInt().clamp(0, 255);
        rgbBytes[offset++] = pixel.b.toInt().clamp(0, 255);
      }
    }
    return rgbBytes;
  }

  static img.Image _centerCropSquareIfNeeded(img.Image source) {
    if (source.width == source.height) {
      return source;
    }
    final size = math.min(source.width, source.height);
    final offsetX = (source.width - size) ~/ 2;
    final offsetY = (source.height - size) ~/ 2;
    return img.copyCrop(
      source,
      x: offsetX,
      y: offsetY,
      width: size,
      height: size,
    );
  }
}
