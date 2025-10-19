import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/ui/shopping_page.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';
import 'package:housekeepr/models/shopping_item.dart';

import '../test_utils.dart';

void main() {
  testWidgets('Checkbox toggles inCart and dismiss shows undo', (tester) async {
    final prefs = InMemoryPrefs();
    final repo = ShoppingRepository(prefs);
    final settings = SettingsRepository(prefs);
    await settings.setSyncMode(SyncMode.localOnly);

    final cubit = ShoppingCubit(repo, settings: settings);

    final item = ShoppingItem(id: 's1', name: 'Milk');
    cubit.addItem(item);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ShoppingCubit>.value(
          value: cubit,
          child: const ShoppingPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);

    // Toggle checkbox
    final checkbox = find.byType(Checkbox).first;
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(cubit.state.items.any((i) => i.id == 's1' && i.inCart), isTrue);

    // Dismiss item (swipe) to trigger SnackBar with Undo
    final listTile = find.text('Milk');
    expect(listTile, findsOneWidget);
    await tester.drag(listTile, const Offset(-500.0, 0.0));
    await tester.pumpAndSettle();

    // After dismissal the item should be removed and a SnackBar should appear
    expect(find.text('Milk'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);

    // Tap Undo on the SnackBar action
    final undoBtn = find.text('Undo');
    expect(undoBtn, findsOneWidget);
    await tester.tap(undoBtn);
    await tester.pumpAndSettle();

    // Item should be back
    expect(find.text('Milk'), findsOneWidget);
    expect(cubit.state.items.any((i) => i.id == 's1'), isTrue);
  });
}
