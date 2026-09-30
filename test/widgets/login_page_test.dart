import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/ui/features/auth/login_page.dart';

void main() {
  testWidgets('LoginPage renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          auth: null, // Unused in build (except for static calls in onPressed)
          googleSignIn: null,
          onSignedIn: (fb.User user) {},
        ),
      ),
    );

    // Verify that our title is present.
    expect(find.text('Welcome to HouseKeepr'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byIcon(Icons.login), findsOneWidget);
  });
}
