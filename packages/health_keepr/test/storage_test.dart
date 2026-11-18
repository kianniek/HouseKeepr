import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';

void main() {
  late Directory tempDir;
  late LocalHealthDataStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('health_keepr_test_');
    store = LocalHealthDataStore(
      storagePathProvider: () async => tempDir.path,
    );
  });

  tearDown(() async {
    await store.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('lazily initializes health_keepr.db only on first access', () async {
    expect(store.isInitialized, isFalse);

    final records = await store.readCollection('open_gym', 'workouts');
    expect(records, isEmpty);
    expect(store.isInitialized, isTrue);
  });

  test('populates UUID v4, UTC ISO-8601 updatedAt, and isSynced=false',
      () async {
    await store.upsertRecord('open_gym', 'exercises', <String, dynamic>{
      'name': 'Bench Press',
    });

    final items = await store.readCollection('open_gym', 'exercises');
    expect(items, hasLength(1));

    final item = items.first;
    expect(item['name'], 'Bench Press');
    expect(
      item['id'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ),
      ),
    );
    expect(item['updatedAt'], endsWith('Z'));
    expect(DateTime.tryParse(item['updatedAt'] as String), isNotNull);
    expect(item['isSynced'], isFalse);
  });

  test('supports CRUD and persists across store restarts', () async {
    const id = '11111111-1111-4111-8111-111111111111';
    await store.upsertRecord('open_gym', 'routines', <String, dynamic>{
      'id': id,
      'title': 'Push Day',
    });

    final fetched = await store.readRecord('open_gym', 'routines', id);
    expect(fetched?['title'], 'Push Day');

    await store.upsertRecord('open_gym', 'routines', <String, dynamic>{
      'id': id,
      'title': 'Push Day v2',
    });

    await store.close();

    final reopened = LocalHealthDataStore(
      storagePathProvider: () async => tempDir.path,
    );
    final persisted = await reopened.readRecord('open_gym', 'routines', id);
    expect(persisted?['title'], 'Push Day v2');

    await reopened.deleteRecord('open_gym', 'routines', id);
    expect(await reopened.readRecord('open_gym', 'routines', id), isNull);
    await reopened.close();
  });

  test('clearModuleData only wipes target module and isolates others',
      () async {
    await store.upsertRecord('open_gym', 'workouts', <String, dynamic>{
      'title': 'Leg Day',
    });
    await store.upsertRecord('nutrition', 'meals', <String, dynamic>{
      'title': 'Oatmeal',
    });

    await store.clearModuleData('open_gym');

    expect(await store.readCollection('open_gym', 'workouts'), isEmpty);
    final nutritionMeals = await store.readCollection('nutrition', 'meals');
    expect(nutritionMeals, hasLength(1));
    expect(nutritionMeals.first['title'], 'Oatmeal');
  });
}
