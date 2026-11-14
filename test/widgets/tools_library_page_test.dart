import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/ui/features/tools/pages/tools_library_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget() {
    return const MaterialApp(home: ToolsLibraryPage());
  }

  group('ToolsLibraryPage view preference persistence', () {
    testWidgets('defaults to list view and persists grid view toggle', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.byType(GridView), findsNothing);

      // Toggle to grid view
      await tester.tap(find.byIcon(Icons.grid_view));
      await tester.pump();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tools_library_is_grid_view'), isTrue);

      // Simulate app restart by pumping a fresh widget tree
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byIcon(Icons.view_list), findsOneWidget);

      // Flush Marquee's 3-second startAfter timers after unmounting.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('loads saved list view preference when false', (tester) async {
      SharedPreferences.setMockInitialValues({
        'tools_library_is_grid_view': false,
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('persists selected category filter across restarts', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(3));

      await tester.tap(find.text('Kitchen'));
      await tester.pump();

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Coffee Picker'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('tools_library_selected_category_v1'),
        'kitchenUtilities',
      );

      // Simulate restart
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Coffee Picker'), findsOneWidget);

      // Reset back to All
      await tester.tap(find.text('All'));
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(3));
      expect(prefs.getString('tools_library_selected_category_v1'), isNull);
    });
  });
}

