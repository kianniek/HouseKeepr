import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/models/grocery_item.dart';
import 'package:housekeepr/repositories/grocery_repository.dart';
import 'package:housekeepr/ui/features/dashboard/models/dashboard_layout_store.dart';
import 'package:housekeepr/ui/features/dashboard/widgets/editable_bento_tile.dart';
import 'package:housekeepr/ui/features/dashboard/widgets/shopping_list_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DashboardLayoutStore', () {
    test('returns defaults when nothing is saved', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = DashboardLayoutStore(prefs: prefs);

      final layout = await store.load();
      expect(layout.order, DashboardWidgetId.values);
      expect(layout.hidden, isEmpty);
    });

    test('persists order and hidden widgets and handles unknown/missing ids', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = DashboardLayoutStore(prefs: prefs);

      await store.saveOrder([
        DashboardWidgetId.shopping,
        DashboardWidgetId.weather,
        DashboardWidgetId.medications,
        DashboardWidgetId.calendar,
      ]);
      await store.saveHidden({DashboardWidgetId.calendar});

      final loaded = await store.load();
      expect(loaded.order, [
        DashboardWidgetId.shopping,
        DashboardWidgetId.weather,
        DashboardWidgetId.medications,
        DashboardWidgetId.calendar,
      ]);
      expect(loaded.hidden, {DashboardWidgetId.calendar});

      // Simulate corrupted/partial stored list
      await prefs.setStringList(DashboardLayoutStore.orderKey, [
        'medications',
        'unknown_widget',
      ]);
      final migrated = await store.load();
      expect(migrated.order.first, DashboardWidgetId.medications);
      expect(migrated.order.toSet(), DashboardWidgetId.values.toSet());
    });
  });

  group('EditableBentoTile & HiddenBentoTile', () {
    testWidgets('long-press enters edit mode, × hides, tap restores, drag reorders', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _TestBentoHarness())),
      );
      await tester.pumpAndSettle();

      // Initially not in edit mode
      expect(find.text('Done'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      // Long-press first tile to enter edit mode
      final weatherFinder = find.text('Weather Card');
      final gesture = await tester.startGesture(tester.getCenter(weatherFinder));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pump();

      expect(find.text('Done'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNWidgets(4));

      // Remove Weather via its × badge -> moves to hidden tray
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();

      expect(find.text('Hidden widgets'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNWidgets(3));

      // Restore Weather by tapping it in the hidden tray
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('Hidden widgets'), findsNothing);
      expect(find.byIcon(Icons.close), findsNWidgets(4));

      // Drag Calendar onto Weather to reorder
      final calendarCenter = tester.getCenter(find.text('Calendar Card'));
      final weatherCenter = tester.getCenter(find.text('Weather Card'));
      await tester.timedDragFrom(
        calendarCenter,
        weatherCenter - calendarCenter,
        const Duration(milliseconds: 300),
      );
      await tester.pump();

      // Exit edit mode
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(find.text('Done'), findsNothing);
    });

    testWidgets(
      'dragging ShoppingListWidget provides ShoppingCubit to Overlay feedback',
      (tester) async {
        final repo = _FakeGroceryRepo([
          GroceryItem(
            id: '1',
            name: 'Coffee',
            createdAt: DateTime(2026, 11, 21),
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider(
              create: (_) => ShoppingCubit(repo),
              child: Scaffold(
                body: SizedBox(
                  width: 180,
                  child: EditableBentoTile(
                    id: DashboardWidgetId.shopping,
                    index: 0,
                    cardWidth: 180,
                    isEditing: true,
                    jiggleAnimation: const AlwaysStoppedAnimation(0.5),
                    onEnterEditMode: () {},
                    onRemove: () {},
                    onReorder: (_, _) {},
                    child: const ShoppingListWidget(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final center = tester.getCenter(find.text('Shopping'));
        final gesture = await tester.startGesture(center);
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(20, 20));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _FakeGroceryRepo extends GroceryRepository {
  final List<GroceryItem> _items;
  _FakeGroceryRepo(this._items);
  @override
  List<GroceryItem> loadItems() => List<GroceryItem>.from(_items);
}

class _TestBentoHarness extends StatefulWidget {
  const _TestBentoHarness();

  @override
  State<_TestBentoHarness> createState() => _TestBentoHarnessState();
}

class _TestBentoHarnessState extends State<_TestBentoHarness>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jiggleController;
  final List<DashboardWidgetId> _order = List.of(DashboardWidgetId.values);
  final Set<DashboardWidgetId> _hidden = {};
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
  }

  @override
  void dispose() {
    _jiggleController.dispose();
    super.dispose();
  }

  String _label(DashboardWidgetId id) {
    switch (id) {
      case DashboardWidgetId.weather:
        return 'Weather Card';
      case DashboardWidgetId.calendar:
        return 'Calendar Card';
      case DashboardWidgetId.shopping:
        return 'Shopping Card';
      case DashboardWidgetId.medications:
        return 'Medications Card';
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _order.where((id) => !_hidden.contains(id)).toList();
    final hidden = _order.where((id) => _hidden.contains(id)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_isEditing)
            FilledButton(
              onPressed: () => setState(() => _isEditing = false),
              child: const Text('Done'),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < visible.length; i++)
                SizedBox(
                  width: 160,
                  height: 100,
                  child: EditableBentoTile(
                    key: ValueKey(visible[i]),
                    id: visible[i],
                    index: i,
                    cardWidth: 160,
                    isEditing: _isEditing,
                    jiggleAnimation: _jiggleController,
                    onEnterEditMode: () => setState(() => _isEditing = true),
                    onRemove: () => setState(() => _hidden.add(visible[i])),
                    onReorder: (dragged, target) {
                      setState(() {
                        final oldIdx = _order.indexOf(dragged);
                        final newIdx = _order.indexOf(target);
                        _order.removeAt(oldIdx);
                        _order.insert(newIdx, dragged);
                      });
                    },
                    child: Card(child: Center(child: Text(_label(visible[i])))),
                  ),
                ),
            ],
          ),
          if (_isEditing && hidden.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Hidden widgets'),
            Wrap(
              spacing: 12,
              children: [
                for (final id in hidden)
                  SizedBox(
                    width: 160,
                    height: 100,
                    child: HiddenBentoTile(
                      id: id,
                      onRestore: () => setState(() => _hidden.remove(id)),
                      child: Card(child: Center(child: Text(_label(id)))),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
