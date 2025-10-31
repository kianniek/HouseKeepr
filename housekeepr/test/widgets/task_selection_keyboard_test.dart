import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:housekeepr/ui/household_dashboard_page.dart';
import 'package:housekeepr/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Space toggles selection and Escape cancels selection mode', (
    WidgetTester tester,
  ) async {
    final task = Task(id: 's1', title: 'Selectable Task');
    final selected = ValueNotifier<bool>(false);
    final cancelled = ValueNotifier<bool>(false);

    final focusNode = FocusNode();
    Widget buildTest() {
      return MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: selected,
            builder: (context, sel, _) {
              return SelectionTaskRow(
                task: task,
                selected: sel,
                focusNode: focusNode,
                onToggle: () => selected.value = !selected.value,
                onCancelSelection: () => cancelled.value = true,
              );
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(buildTest());
    await tester.pumpAndSettle();

    // Focus the tile by requesting focus on the injected FocusNode
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    // Send SPACE key
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(selected.value, isTrue);

    // Send ESCAPE to cancel selection mode
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(cancelled.value, isTrue);
  });
}
