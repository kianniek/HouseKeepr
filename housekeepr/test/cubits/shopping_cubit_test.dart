import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';
import 'package:housekeepr/models/shopping_item.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';

import '../test_utils.dart';

void main() {
  test(
    'ShoppingCubit add/update/delete/replaceAll emits expected states',
    () async {
      final prefs = InMemoryPrefs();
      final repo = ShoppingRepository(prefs);
      final settings = SettingsRepository(prefs);
      await settings.setSyncMode(SyncMode.localOnly);

      final cubit = ShoppingCubit(repo, settings: settings);

      expect(cubit.state.items, isEmpty);

      final item = ShoppingItem(id: 's1', name: 'Eggs');
      await cubit.addItem(item);
      expect(cubit.state.items.length, 1);
      expect(cubit.state.items.first.name, 'Eggs');

      final updated = item.copyWith(name: 'Eggs2');
      await cubit.updateItem(updated);
      expect(cubit.state.items.first.name, 'Eggs2');

      await cubit.deleteItem('s1');
      expect(cubit.state.items, isEmpty);

      final s2 = ShoppingItem(id: 's2', name: 'X');
      await cubit.replaceAll([s2]);
      expect(cubit.state.items.length, 1);
      expect(cubit.state.items.first.id, 's2');
    },
  );
}
