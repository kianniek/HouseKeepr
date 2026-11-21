import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/models/grocery_item.dart';
import 'package:housekeepr/models/medication.dart';
import 'package:housekeepr/repositories/grocery_repository.dart';
import 'package:housekeepr/repositories/local_medication_repository.dart';
import 'package:housekeepr/ui/features/dashboard/widgets/medication_widget.dart';
import 'package:housekeepr/ui/features/dashboard/widgets/shopping_list_widget.dart';
import 'package:housekeepr/ui/features/dashboard/widgets/stable_loading_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGroceryRepository extends GroceryRepository {
  List<GroceryItem> _items;

  _FakeGroceryRepository([List<GroceryItem>? initial])
    : _items = List<GroceryItem>.from(initial ?? const []);

  @override
  List<GroceryItem> loadItems() => List<GroceryItem>.from(_items);

  @override
  Future<void> saveItem(GroceryItem item) async {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.add(item);
    }
  }

  @override
  Future<void> saveItems(List<GroceryItem> items) async {
    _items = List<GroceryItem>.from(items);
  }

  @override
  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
  }

  @override
  Future<void> updateOrder(List<String> order) async {}

  @override
  Future<void> clearAll() async {
    _items.clear();
  }

  @override
  Future<void> overwriteAll(List<GroceryItem> items) async {
    _items = List<GroceryItem>.from(items);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StableLoadingCard.clearMemoryCache();
  });

  group('ShoppingListWidget', () {
    testWidgets('shows empty state when no unbought items exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => ShoppingCubit(_FakeGroceryRepository()),
              child: const ShoppingListWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('All caught up'), findsOneWidget);
    });

    testWidgets('shows unbought count, up to 3 items, and toggles item', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 21, 10, 0);
      final repo = _FakeGroceryRepository([
        GroceryItem(id: '1', name: 'Milk', quantity: 2, createdAt: now),
        GroceryItem(id: '2', name: 'Eggs', createdAt: now),
        GroceryItem(id: '3', name: 'Bread', createdAt: now),
        GroceryItem(id: '4', name: 'Apples', createdAt: now),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => ShoppingCubit(repo),
              child: const ShoppingListWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
      expect(find.text('Apples'), findsNothing);
      expect(find.text('+1 more'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.radio_button_unchecked).first);
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Apples'), findsOneWidget);
      expect(find.text('Checked off "Milk"'), findsOneWidget);
    });
  });

  group('MedicationWidget', () {
    testWidgets('shows empty state when no medications are configured', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalMedicationRepository(prefs: prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MedicationWidget(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Medications'), findsOneWidget);
      expect(find.text('No meds set up'), findsOneWidget);
    });

    testWidgets('shows next pending dose and marks it taken', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalMedicationRepository(prefs: prefs);
      final today = DateTime.now();
      await repo.saveMedication(
        Medication(
          id: 'med-1',
          name: 'Vitamin D',
          dosage: '1000 IU',
          startDate: DateTime(today.year, today.month, today.day),
          notificationTimes: [MedicationTime(hour: 8, minute: 0)],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MedicationWidget(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AM'), findsOneWidget);
      expect(find.text('Vitamin D'), findsOneWidget);
      expect(find.text('08:00 · 1000 IU'), findsOneWidget);
      expect(find.text('Mark Taken'), findsOneWidget);

      await tester.tap(find.text('Mark Taken'));
      await tester.pumpAndSettle();

      expect(find.text('All doses taken'), findsOneWidget);
      expect(find.text('Mark Taken'), findsNothing);
    });
  });

  group('StableLoadingCard', () {
    testWidgets('preserves pre-loading height while loading and persists it', (
      tester,
    ) async {
      const storageKey = 'test_stable_card_height';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 200,
                child: StableLoadingCard(
                  storageKey: storageKey,
                  isLoading: false,
                  child: SizedBox(height: 240, child: Text('Loaded')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final loadedHeight = tester.getSize(find.byType(StableLoadingCard)).height;
      expect(loadedHeight, greaterThanOrEqualTo(276));

      // Transition to loading state: height must stay at the previous height
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 200,
                child: StableLoadingCard(
                  storageKey: storageKey,
                  isLoading: true,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final reloadingHeight = tester.getSize(find.byType(StableLoadingCard)).height;
      expect(reloadingHeight, closeTo(loadedHeight, 1.0));

      // Simulate fresh mount (clear memory cache, read from SharedPreferences)
      await tester.pump(const Duration(milliseconds: 50));
      StableLoadingCard.clearMemoryCache();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 200,
                child: StableLoadingCard(
                  storageKey: storageKey,
                  isLoading: true,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));

      final coldStartLoadingHeight = tester
          .getSize(find.byType(StableLoadingCard))
          .height;
      expect(coldStartLoadingHeight, closeTo(loadedHeight, 1.0));
    });
  });
}
