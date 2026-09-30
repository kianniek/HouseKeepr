import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:housekeepr/models/grocery_category.dart';
import 'package:housekeepr/services/shopping_products_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory hiveDir;
  late ShoppingProductsService service;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp(
      'shopping_products_service_test',
    );
    Hive.init(hiveDir.path);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    service = ShoppingProductsService.instance;
    await service.init(prefs);
  });

  setUp(() async {
    await Hive.box('learning_products').clear();
  });

  tearDownAll(() async {
    await Hive.box('learning_products').close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  test('learned exact match is normalized and reused', () async {
    await service.learnProduct('Milk', GroceryCategory.dairy);

    expect(service.getCategoryForProduct('milk'), GroceryCategory.dairy);
    expect(service.getCategoryForProduct('  MILK  '), GroceryCategory.dairy);
  });

  test('learned token match generalizes to related input', () async {
    await service.learnProduct('Apple', GroceryCategory.fruit);

    expect(service.getCategoryForProduct('apples'), GroceryCategory.fruit);
    expect(service.getCategoryForProduct('green apple'), GroceryCategory.fruit);
  });

  test('csv fallback still works when nothing is learned', () {
    expect(service.getCategoryForProduct('banana'), GroceryCategory.fruit);
  });

  test('confidence scores do not seed a fake other category', () {
    final scores = service.getCategoryConfidenceScores('unlikely product name');

    expect(scores.containsKey(GroceryCategory.other), isFalse);
  });
}
