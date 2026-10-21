import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

Future<Color?> showColorPicker(
  BuildContext context, {
  required Color color,
}) async {
  Color tempColor = color;

  return showDialog<Color>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Choose Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (Color color) {
              tempColor = color;
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            displayThumbColor: true,
            portraitOnly: true,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(null),
          ),
          ElevatedButton(
            child: const Text('Select'),
            onPressed: () => Navigator.of(context).pop(tempColor),
          ),
        ],
      );
    },
  );
}

Future<Color?> showRestrictedColorPicker(
  BuildContext context, {
  required Color color,
  required List<Color> availableColors,
}) async {
  Color tempColor = color;

  return showDialog<Color>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Choose Layer Color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: tempColor,
            availableColors: availableColors, // Limits choices to this list
            onColorChanged: (Color color) {
              tempColor = color;
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(null),
          ),
          ElevatedButton(
            child: const Text('Select'),
            onPressed: () => Navigator.of(context).pop(tempColor),
          ),
        ],
      );
    },
  );
}
