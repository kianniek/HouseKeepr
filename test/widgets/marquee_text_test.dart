import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/ui/common/widgets/marquee_text.dart';
import 'package:marquee/marquee.dart';

void main() {
  testWidgets('MarqueeText uses Text when short and Marquee when overflowing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarqueeText('Short task'),
                MarqueeText(
                  'This is a very long household chore title that definitely overflows',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Marquee), findsOneWidget);
    expect(find.text('Short task'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
