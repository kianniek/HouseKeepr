import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_drawing/path_drawing.dart';

/// Interactive SVG-path muscle map ported from `openGym` `body-paths.js`.
///
/// Supports full interactive mode (in Stats & Explore Muscles) and [compact]
/// mini-preview mode (side-by-side front & back silhouettes in Plan & Workout).
class BodyMapWidget extends StatefulWidget {
  const BodyMapWidget({
    super.key,
    required this.weeklySetsByBodyPart,
    this.compact = false,
    this.selectedMuscles,
    this.onToggleMuscle,
    this.showHeader = true,
  });

  final Map<String, int> weeklySetsByBodyPart;
  final bool compact;
  final Set<String>? selectedMuscles;
  final ValueChanged<String>? onToggleMuscle;
  final bool showHeader;

  @override
  State<BodyMapWidget> createState() => _BodyMapWidgetState();
}

class _BodyMapWidgetState extends State<BodyMapWidget> {
  static Map<String, dynamic>? _cachedPaths;
  Map<String, dynamic>? _paths;
  String _sex = 'male';
  String _side = 'front';

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    if (_cachedPaths != null) {
      if (mounted) setState(() => _paths = _cachedPaths);
      return;
    }
    try {
      final raw = await rootBundle.loadString(
        'packages/open_gym/assets/body_paths.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _cachedPaths = decoded;
        if (mounted) setState(() => _paths = decoded);
      }
    } catch (_) {
      // Asset unavailable in headless unit tests.
    }
  }

  static const Set<String> _inertParts = <String>{
    'head',
    'hair',
    'hands',
    'feet',
    'knees',
    'ankles',
  };

  double _heatForMuscle(String muscleKey) {
    if (_inertParts.contains(muscleKey)) return 0;
    final selected = widget.selectedMuscles;
    if (selected != null) {
      return selected.contains(muscleKey) ? 0.95 : 0;
    }

    final sets = widget.weeklySetsByBodyPart;
    if (sets.isEmpty) return 0;

    int count = 0;
    switch (muscleKey) {
      case 'chest':
      case 'serratus':
        count = sets['chest'] ?? 0;
      case 'abs':
      case 'obliques':
        count = sets['waist'] ?? 0;
      case 'biceps':
      case 'triceps':
        count = sets['upper arms'] ?? 0;
      case 'forearm':
        count = (sets['lower arms'] ?? 0) + (sets['upper arms'] ?? 0) ~/ 2;
      case 'deltoids':
        count = sets['shoulders'] ?? 0;
      case 'trapezius':
      case 'upper-back':
      case 'lower-back':
        count = sets['back'] ?? 0;
      case 'quadriceps':
      case 'hamstring':
      case 'adductors':
      case 'gluteal':
      case 'hip-flexors':
        count = sets['upper legs'] ?? 0;
      case 'calves':
      case 'tibialis':
        count = sets['lower legs'] ?? 0;
      case 'neck':
        count = sets['neck'] ?? 0;
      default:
        count = 0;
    }
    if (count <= 0) return 0;
    return (count / 12.0).clamp(0.3, 1.0);
  }

  Widget _buildSingleFigure(
    Map<String, dynamic>? viewData,
    ColorScheme colorScheme, {
    double height = 260,
  }) {
    if (viewData == null) {
      return SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: GestureDetector(
        onTapDown: widget.onToggleMuscle == null
            ? null
            : (details) => _handleTap(details.localPosition, viewData, height),
        child: CustomPaint(
          painter: _BodyMapPainter(
            viewData: viewData,
            baseColor: colorScheme.surfaceContainerHighest,
            outlineColor: colorScheme.outlineVariant,
            heatColor: colorScheme.primary,
            heatLookup: _heatForMuscle,
            inertParts: _inertParts,
            selectedMuscles: widget.selectedMuscles ?? const <String>{},
          ),
        ),
      ),
    );
  }

  void _handleTap(
    Offset localPos,
    Map<String, dynamic> viewData,
    double height,
  ) {
    final onToggle = widget.onToggleMuscle;
    if (onToggle == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 300;
    final vbParts = (viewData['vb'] as String? ?? '0 0 727 1280')
        .split(' ')
        .map((e) => double.tryParse(e) ?? 0)
        .toList();
    if (vbParts.length != 4 || vbParts[2] <= 0 || vbParts[3] <= 0) return;

    final vbX = vbParts[0];
    final vbY = vbParts[1];
    final vbW = vbParts[2];
    final vbH = vbParts[3];
    final scale = (width / vbW) < (height / vbH)
        ? (width / vbW)
        : (height / vbH);
    final dx = (width - vbW * scale) / 2 - vbX * scale;
    final dy = (height - vbH * scale) / 2 - vbY * scale;

    final svgPoint = Offset(
      (localPos.dx - dx) / scale,
      (localPos.dy - dy) / scale,
    );

    final parts = viewData['p'] as Map<String, dynamic>? ?? const {};
    for (final entry in parts.entries) {
      if (_inertParts.contains(entry.key)) continue;
      final list = entry.value as List<dynamic>? ?? const <dynamic>[];
      for (final pathStr in list) {
        if (pathStr is! String) continue;
        try {
          if (parseSvgPathData(pathStr).contains(svgPoint)) {
            onToggle(entry.key);
            return;
          }
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final frontData = _paths?[_sex]?['front'] as Map<String, dynamic>?;
    final backData = _paths?[_sex]?['back'] as Map<String, dynamic>?;

    if (widget.compact) {
      if (frontData == null || backData == null) {
        return const SizedBox(width: 56, height: 48);
      }
      return SizedBox(
        width: 64,
        height: 52,
        child: Row(
          children: <Widget>[
            Expanded(
              child: CustomPaint(
                size: const Size(30, 52),
                painter: _BodyMapPainter(
                  viewData: frontData,
                  baseColor: colorScheme.surfaceContainerHighest,
                  outlineColor: colorScheme.outlineVariant,
                  heatColor: colorScheme.primary,
                  heatLookup: _heatForMuscle,
                  inertParts: _inertParts,
                  selectedMuscles: const <String>{},
                ),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: CustomPaint(
                size: const Size(30, 52),
                painter: _BodyMapPainter(
                  viewData: backData,
                  baseColor: colorScheme.surfaceContainerHighest,
                  outlineColor: colorScheme.outlineVariant,
                  heatColor: colorScheme.primary,
                  heatLookup: _heatForMuscle,
                  inertParts: _inertParts,
                  selectedMuscles: const <String>{},
                ),
              ),
            ),
          ],
        ),
      );
    }

    final viewData = _side == 'front' ? frontData : backData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.showHeader)
              Row(
                children: <Widget>[
                  Text('Muscle Map', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(value: 'front', label: Text('Front')),
                      ButtonSegment<String>(value: 'back', label: Text('Back')),
                    ],
                    selected: <String>{_side},
                    onSelectionChanged: (s) => setState(() => _side = s.first),
                  ),
                ],
              ),
            if (widget.showHeader) const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (!widget.showHeader)
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(value: 'front', label: Text('Front')),
                      ButtonSegment<String>(value: 'back', label: Text('Back')),
                    ],
                    selected: <String>{_side},
                    onSelectionChanged: (s) => setState(() => _side = s.first),
                  ),
                const Spacer(),
                ChoiceChip(
                  label: Text(_sex == 'male' ? 'Male' : 'Female'),
                  selected: true,
                  onSelected: (_) => setState(
                    () => _sex = _sex == 'male' ? 'female' : 'male',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSingleFigure(viewData, colorScheme),
          ],
        ),
      ),
    );
  }
}

class _BodyMapPainter extends CustomPainter {
  _BodyMapPainter({
    required this.viewData,
    required this.baseColor,
    required this.outlineColor,
    required this.heatColor,
    required this.heatLookup,
    required this.inertParts,
    required this.selectedMuscles,
  });

  final Map<String, dynamic> viewData;
  final Color baseColor;
  final Color outlineColor;
  final Color heatColor;
  final double Function(String) heatLookup;
  final Set<String> inertParts;
  final Set<String> selectedMuscles;

  @override
  void paint(Canvas canvas, Size size) {
    final vbParts = (viewData['vb'] as String? ?? '0 0 727 1280')
        .split(' ')
        .map((e) => double.tryParse(e) ?? 0)
        .toList();
    if (vbParts.length != 4 || vbParts[2] <= 0 || vbParts[3] <= 0) return;

    final vbX = vbParts[0];
    final vbY = vbParts[1];
    final vbW = vbParts[2];
    final vbH = vbParts[3];

    final scale = (size.width / vbW) < (size.height / vbH)
        ? (size.width / vbW)
        : (size.height / vbH);
    final dx = (size.width - vbW * scale) / 2 - vbX * scale;
    final dy = (size.height - vbH * scale) / 2 - vbY * scale;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final parts = viewData['p'] as Map<String, dynamic>? ?? const {};
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / scale
      ..color = outlineColor;

    for (final entry in parts.entries) {
      final muscleKey = entry.key;
      final rawList = entry.value as List<dynamic>? ?? const <dynamic>[];
      final heat = heatLookup(muscleKey);
      final isSelected = selectedMuscles.contains(muscleKey);
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = inertParts.contains(muscleKey)
            ? baseColor.withValues(alpha: 0.7)
            : (heat > 0 ? heatColor.withValues(alpha: heat) : baseColor);

      final activeStroke = isSelected
          ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 / scale
            ..color = heatColor)
          : strokePaint;

      for (final pathStr in rawList) {
        if (pathStr is! String) continue;
        try {
          final path = parseSvgPathData(pathStr);
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, activeStroke);
        } catch (_) {}
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BodyMapPainter oldDelegate) {
    return oldDelegate.viewData != viewData ||
        oldDelegate.heatColor != heatColor ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.selectedMuscles != selectedMuscles;
  }
}
