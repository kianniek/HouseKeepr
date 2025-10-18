import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/ui/shopping_page.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';

import '../test_utils.dart';

void main() {
  testWidgets('Add Shopping Item dialog flow updates cubit and shows item', (
    tester,
  ) async {
    final prefs = InMemoryPrefs();
    final repo = ShoppingRepository(prefs);
    final settings = SettingsRepository(prefs);
    await settings.setSyncMode(SyncMode.localOnly);

    final cubit = ShoppingCubit(repo, settings: settings);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ShoppingCubit>.value(
          value: cubit,
          child: const ShoppingPage(),
        ),
      ),
    );

    expect(find.text('No shopping items'), findsOneWidget);

    // open add dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // enter name and add
    await tester.enterText(find.byType(TextField).first, 'Bread');
    await tester.pump();
    final addBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Add'),
    );
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(find.text('Bread'), findsOneWidget);
    expect(cubit.state.items.any((i) => i.name == 'Bread'), isTrue);
  });
}
