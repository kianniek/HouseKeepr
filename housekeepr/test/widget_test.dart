// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:housekeepr/main.dart';

void main() {
  testWidgets('App smoke test: shows spinner then finds HouseKeepr app bar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    // Should show CircularProgressIndicator first
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Pump until spinner disappears or timeout
    bool spinnerGone = false;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        spinnerGone = true;
        break;
      }
    }
    expect(spinnerGone, isTrue, reason: 'Spinner did not disappear');

    // Now check for app bar title
    bool found = false;
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('HouseKeepr').evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }
    expect(found, isTrue, reason: 'App bar title not found after waiting');
  });
}
