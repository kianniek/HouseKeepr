import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/ui/common/widgets/undo_toast.dart';

void main() {
  testWidgets('showUndoToast displays message, countdown and UNDO button', (
    tester,
  ) async {
    bool undoCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showUndoToast(
                  context,
                  message: 'Item deleted',
                  onUndo: () => undoCalled = true,
                  duration: const Duration(seconds: 4),
                );
              },
              child: const Text('Show Toast'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Toast'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 300)); // Finish slide in

    expect(find.text('Item deleted'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);
    expect(find.byKey(const ValueKey('undo_toast_seconds')), findsOneWidget);

    // Tap UNDO
    await tester.tap(find.text('UNDO'));
    await tester.pump();
    expect(undoCalled, isTrue);
  });

  testWidgets(
    'showUndoToast auto-dismisses after duration without calling onUndo',
    (tester) async {
      bool undoCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showUndoToast(
                    context,
                    message: 'Item deleted',
                    onUndo: () => undoCalled = true,
                    duration: const Duration(seconds: 2),
                  );
                },
                child: const Text('Show Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Item deleted'), findsOneWidget);

      // Wait until duration elapses and snackbar slides away
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Item deleted'), findsNothing);
      expect(undoCalled, isFalse);
    },
  );

  testWidgets('Ctrl+Z triggers undo when focus is not inside an EditableText', (
    tester,
  ) async {
    bool undoCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showUndoToast(
                  context,
                  message: 'Item deleted',
                  onUndo: () => undoCalled = true,
                  duration: const Duration(seconds: 5),
                );
              },
              child: const Text('Show Toast'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(undoCalled, isFalse);

    // Simulate Ctrl+Z key down event
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(undoCalled, isTrue);
  });

  testWidgets('Ctrl+Z does NOT trigger undo when focus is inside a TextField', (
    tester,
  ) async {
    bool undoCalled = false;
    final controller = TextEditingController(text: 'Hello');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(controller: controller, autofocus: true),
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showUndoToast(
                      context,
                      message: 'Item deleted',
                      onUndo: () => undoCalled = true,
                      duration: const Duration(seconds: 5),
                    );
                  },
                  child: const Text('Show Toast'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Focus is on TextField
    await tester.tap(find.text('Show Toast'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Ensure focus is on TextField
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // Simulate Ctrl+Z
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(undoCalled, isFalse);
  });
}
