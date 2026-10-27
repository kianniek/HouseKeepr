import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:housekeepr/main.dart';

void main() {
  testWidgets('renders the sign-in screen when Firebase is unavailable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MyApp(initializationError: 'Firebase unavailable'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Initialization Error'), findsOneWidget);
    expect(find.text('The app failed to initialize Firebase.'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
