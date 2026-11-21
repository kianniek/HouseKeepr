import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/workout_template.dart';
import '../ui/widgets/routine_glyph_icon.dart';

/// Syncs the Android dynamic launcher shortcut for starting the next workout.
class OpenGymShortcutService {
  const OpenGymShortcutService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'housekeepr/shortcuts';
  static const Color defaultIconColor = Color(0xFFC65102);
  static const Color defaultBackgroundColor = Color(0xFFFFFFFF);

  final MethodChannel _channel;

  /// Updates the dynamic shortcut to reflect [nextTemplate] (or a quick
  /// workout fallback when no template is scheduled).
  Future<void> updateNextWorkoutShortcut(
    WorkoutTemplate? nextTemplate, {
    Color iconColor = defaultIconColor,
    Color backgroundColor = defaultBackgroundColor,
  }) async {
    final String shortLabel;
    final String longLabel;
    Uint8List? iconBytes;

    if (nextTemplate != null) {
      final name = nextTemplate.name.trim();
      shortLabel = name.isNotEmpty ? 'Next: $name' : 'Next Workout';
      longLabel = name.isNotEmpty ? 'Start $name' : 'Start Next Workout';
      iconBytes = await _renderRoutineIconBytes(
        nextTemplate.iconKey,
        iconColor: iconColor,
      );
    } else {
      shortLabel = 'Quick Workout';
      longLabel = 'Start Quick Workout';
    }

    try {
      await _channel.invokeMethod<bool>(
        'updateNextWorkoutShortcut',
        <String, dynamic>{
          'shortLabel': shortLabel,
          'longLabel': longLabel,
          'iconColor': iconColor.toARGB32(),
          'backgroundColor': backgroundColor.toARGB32(),
          'iconBytes': ?iconBytes,
        },
      );
    } on MissingPluginException {
      // Ignored on platforms/tests without the Android shortcut bridge.
    } on PlatformException catch (e) {
      debugPrint('OpenGymShortcutService: failed to update shortcut: $e');
    }
  }

  Future<Uint8List?> _renderRoutineIconBytes(
    String iconKey, {
    required Color iconColor,
  }) async {
    try {
      final iconData = routineGlyphIconData(iconKey);
      const size = 96.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: size * 0.75,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            color: iconColor,
          ),
        )
        ..layout();
      painter.paint(
        canvas,
        Offset(
          (size - painter.width) / 2,
          (size - painter.height) / 2,
        ),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('OpenGymShortcutService: failed to render icon "$iconKey": $e');
      return null;
    }
  }
}
