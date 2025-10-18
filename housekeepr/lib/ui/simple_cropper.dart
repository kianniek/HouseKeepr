import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SimpleCropper extends StatefulWidget {
  final String imagePath;
  const SimpleCropper({super.key, required this.imagePath});

  @override
  State<SimpleCropper> createState() => _SimpleCropperState();
}

class _SimpleCropperState extends State<SimpleCropper> {
  final GlobalKey _key = GlobalKey();
  double _rotation = 0.0;
  double _scale = 1.0;

  Future<ui.Image> _capture(double pixelRatio) async {
    final boundary =
        _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: pixelRatio);
    return img;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop photo')),
      body: Center(
        child: RepaintBoundary(
          key: _key,
          child: Container(
            width: 320,
            height: 320,
            color: Colors.black,
            child: Stack(
              children: [
                Center(
                  child: GestureDetector(
                    onScaleUpdate: (details) {
                      setState(() {
                        _scale = (_scale * details.scale).clamp(0.5, 4.0);
                      });
                    },
                    onDoubleTap: () => setState(() => _scale = 1.0),
                    child: Transform.rotate(
                      angle: _rotation,
                      child: Transform.scale(
                        scale: _scale,
                        child: SizedBox(
                          width: 320,
                          height: 320,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: Image.file(File(widget.imagePath)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Aspect ratio overlay (square)
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withAlpha(204),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Rotation controls
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'rotate_right',
                        onPressed: () => setState(() => _rotation += 0.1),
                        child: const Icon(Icons.rotate_right),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'rotate_left',
                        onPressed: () => setState(() => _rotation -= 0.1),
                        child: const Icon(Icons.rotate_left),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'crop_done',
        onPressed: () async {
          final pixelRatio = MediaQuery.of(context).devicePixelRatio;
          final navigator = Navigator.of(context);
          final img = await _capture(pixelRatio);
          final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
          final bytes = byteData!.buffer.asUint8List();
          if (mounted) navigator.pop(bytes);
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}
