import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/ui/member_picker.dart';

void main() {
  testWidgets('MemberPicker widget builds (smoke test)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberPicker(householdId: 'h1', onChanged: (_, _) {}),
        ),
      ),
    );
    // Pump to let any async builders run; in absence of a Firestore instance
    // the widget should still build and show a progress indicator initially.
    await tester.pump();
    expect(find.byType(MemberPicker), findsOneWidget);
  });
}
