import 'package:flutter/material.dart';

/// Material 3 line chart with gradient area fill and optional dashed goal line.
class OpenGymLineChart extends StatelessWidget {
  const OpenGymLineChart({
    super.key,
    required this.values,
    this.goalValue,
    this.height = 140,
  });

  final List<double> values;
  final double? goalValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data yet',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineChartPainter(
          values: values,
          goalValue: goalValue,
          lineColor: colorScheme.primary,
          goalColor: colorScheme.tertiary,
          gridColor: colorScheme.outlineVariant,
          labelStyle: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ) ??
              const TextStyle(fontSize: 10),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.goalValue,
    required this.lineColor,
    required this.goalColor,
    required this.gridColor,
    required this.labelStyle,
  });

  final List<double> values;
  final double? goalValue;
  final Color lineColor;
  final Color goalColor;
  final Color gridColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final allVals = <double>[
      ...values,
      ?goalValue,
    ];
    final minVal = allVals.reduce((a, b) => a < b ? a : b);
    final maxVal = allVals.reduce((a, b) => a > b ? a : b);
    final span = (maxVal - minVal).abs() < 0.01 ? 10.0 : (maxVal - minVal);
    final yMin = minVal - span * 0.15;
    final yMax = maxVal + span * 0.15;

    const leftPad = 32.0;
    const rightPad = 12.0;
    const topPad = 12.0;
    const bottomPad = 12.0;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    if (chartW <= 0 || chartH <= 0) return;

    double yFor(double v) =>
        topPad + chartH * (1 - ((v - yMin) / (yMax - yMin)));

    // Grid line at midpoint
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    final midY = topPad + chartH / 2;
    canvas.drawLine(
      Offset(leftPad, midY),
      Offset(size.width - rightPad, midY),
      gridPaint,
    );

    // Dashed goal line
    if (goalValue != null) {
      final gy = yFor(goalValue!);
      final goalPaint = Paint()
        ..color = goalColor
        ..strokeWidth = 1.5;
      const dashW = 6.0;
      const gapW = 4.0;
      double x = leftPad;
      while (x < size.width - rightPad) {
        final endX = (x + dashW).clamp(leftPad, size.width - rightPad);
        canvas.drawLine(Offset(x, gy), Offset(endX, gy), goalPaint);
        x += dashW + gapW;
      }
    }

    // Points
    final points = <Offset>[];
    if (values.length == 1) {
      points.add(Offset(leftPad + chartW * 0.65, yFor(values.first)));
    } else {
      for (var i = 0; i < values.length; i++) {
        final px = leftPad + (chartW * i / (values.length - 1));
        points.add(Offset(px, yFor(values[i])));
      }
    }

    // Area fill
    final fillPath = Path();
    if (points.length == 1) {
      final p = points.first;
      fillPath.moveTo(leftPad, topPad + chartH);
      fillPath.lineTo(p.dx, p.dy);
      fillPath.lineTo(p.dx, topPad + chartH);
      fillPath.close();
    } else {
      fillPath.moveTo(points.first.dx, topPad + chartH);
      for (final p in points) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath.lineTo(points.last.dx, topPad + chartH);
      fillPath.close();
    }
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          lineColor.withValues(alpha: 0.28),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH));
    canvas.drawPath(fillPath, fillPaint);

    // Line
    if (points.length > 1) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Dots
    final dotPaint = Paint()..color = lineColor;
    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
    }

    // Y labels
    final tpMax = TextPainter(
      text: TextSpan(text: maxVal.toStringAsFixed(0), style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tpMax.paint(canvas, Offset(2, topPad));

    final tpMin = TextPainter(
      text: TextSpan(text: minVal.toStringAsFixed(0), style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tpMin.paint(canvas, Offset(2, topPad + chartH - tpMin.height));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.goalValue != goalValue;
}
