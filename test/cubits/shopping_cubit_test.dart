import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:housekeepr/core/sync_mode.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/models/shopping_item.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockShoppingRepository extends Mock implements ShoppingRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  group('ShoppingCubit', () {
    late MockShoppingRepository mockRepo;
    late MockSettingsRepository mockSettings;

    setUpAll(() {
      registerFallbackValue(<ShoppingItem>[]);
    });

    setUp(() {
      mockRepo = MockShoppingRepository();
      mockSettings = MockSettingsRepository();

      // Default stubs
      when(() => mockSettings.getSyncMode()).thenReturn(SyncMode.sync);
      when(() => mockRepo.loadItems()).thenReturn([]);
      when(() => mockRepo.saveItems(any())).thenAnswer((_) async {});
    });

    test('initial state is correct', () {
      final cubit = ShoppingCubit(mockRepo, settings: mockSettings);
      expect(cubit.state, ShoppingState.initial());
      cubit.close();
    });

    test('loads items on initialization', () {
      // ShoppingCubit calls load() synchronously in constructor
      final cubit = ShoppingCubit(mockRepo, settings: mockSettings);
      expect(cubit.state.items, isEmpty);
      verify(() => mockRepo.loadItems()).called(1);
      cubit.close();
    });

    test('adds an item and emits updated state', () async {
      final cubit = ShoppingCubit(mockRepo, settings: mockSettings);

      await cubit.addItem(ShoppingItem(id: '1', name: 'Milk'));

      expect(cubit.state.items.length, 1);
      expect(cubit.state.items.first.name, 'Milk');
      verify(() => mockRepo.saveItems(any())).called(1);
      cubit.close();
    });

    test('deletes an item and emits updated state', () async {
      final item = ShoppingItem(id: '1', name: 'Milk');
      when(() => mockRepo.loadItems()).thenReturn([item]);

      final cubit = ShoppingCubit(mockRepo, settings: mockSettings);
      expect(cubit.state.items.length, 1);

      await cubit.deleteItem('1');

      expect(cubit.state.items, isEmpty);
      verify(() => mockRepo.saveItems(any())).called(1);
      cubit.close();
    });
  });
}
