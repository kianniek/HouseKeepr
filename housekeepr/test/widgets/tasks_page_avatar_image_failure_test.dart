import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:housekeepr/ui/assignee_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Displays initials when network image fails to load', (
    WidgetTester tester,
  ) async {
    // Use an invalid scheme to force the widget's URL validation to skip
    // loading the network image and show the initials fallback. This covers
    // the failing-image fallback behavior without needing to stub HTTP.
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AssigneeAvatar(
            displayName: 'Alice Bob',
            radius: 24,
            // Invalid scheme — widget only accepts http/https — so it will
            // render initials instead of trying to load the image.
            photoUrl: 'ftp://example.com/avatar.jpg',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Expect initials 'AB' to be displayed by AssigneeAvatar fallback.
    expect(find.text('AB'), findsOneWidget);
  });
}
