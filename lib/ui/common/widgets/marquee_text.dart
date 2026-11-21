import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

/// Displays [text] on a single line, automatically switching to a smooth
/// horizontal [Marquee] scroll when the text exceeds the available width.
class MarqueeText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const MarqueeText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: effectiveStyle),
          maxLines: 1,
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout();

        final overflows =
            constraints.hasBoundedWidth && painter.width > constraints.maxWidth;

        if (!overflows) {
          return Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: effectiveStyle,
          );
        }

        return SizedBox(
          height: painter.height,
          child: Marquee(
            text: text,
            style: effectiveStyle,
            blankSpace: 36.0,
            velocity: 30.0,
            pauseAfterRound: const Duration(seconds: 2),
            startAfter: const Duration(seconds: 1),
            fadingEdgeStartFraction: 0.05,
            fadingEdgeEndFraction: 0.1,
          ),
        );
      },
    );
  }
}
