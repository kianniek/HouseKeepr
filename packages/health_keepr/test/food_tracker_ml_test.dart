import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';
import 'package:health_keepr/src/food_tracker/ml/litert_food_classifier_stub.dart'
    as classifier_stub;
import 'package:image/image.dart' as img;

File _resolvePackageFile(String relativePath) {
  final direct = File(relativePath);
  if (direct.existsSync()) return direct;
  final fromRoot = File('packages/health_keepr/$relativePath');
  if (fromRoot.existsSync()) return fromRoot;
  throw StateError('Unable to locate test asset file: $relativePath');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bundled ML & Nutrition Assets', () {
    test('nutrition_foods.json loads via dual-key rootBundle and passes schema checks', () async {
      final catalog = await NutritionCatalog.loadFromAsset();
      expect(catalog.foods.length, greaterThanOrEqualTo(200));

      final ids = <String>{};
      for (final food in catalog.foods) {
        expect(food.id, isNotEmpty);
        expect(ids.add(food.id), isTrue, reason: 'Duplicate ID: ${food.id}');
        expect(food.name, isNotEmpty);
        expect(food.category, isNotEmpty);
        expect(food.kcalPer100g.isFinite, isTrue);
        expect(food.kcalPer100g, greaterThanOrEqualTo(0.0));
        expect(food.proteinPer100g.isFinite, isTrue);
        expect(food.proteinPer100g, greaterThanOrEqualTo(0.0));
        expect(food.carbsPer100g.isFinite, isTrue);
        expect(food.carbsPer100g, greaterThanOrEqualTo(0.0));
        expect(food.fatPer100g.isFinite, isTrue);
        expect(food.fatPer100g, greaterThanOrEqualTo(0.0));
        expect(food.defaultServingGrams, greaterThan(0.0));
        expect(food.servingLabel, isNotEmpty);
      }

      // Required staples & fallback
      for (final requiredId in <String>[
        'mixed_meal',
        'oatmeal_cooked',
        'boiled_egg',
        'chicken_breast_grilled',
        'salmon_fillet',
        'banana',
        'apple',
        'avocado',
        'greek_yogurt',
        'black_coffee',
        'protein_shake',
      ]) {
        expect(
          catalog.findById(requiredId),
          isNotNull,
          reason: 'Missing required staple: $requiredId',
        );
      }
    });

    test('labels.txt contains 2,024 AIY Food V1 classes with expected structure', () async {
      final rawLabels = await loadFoodAssetString('assets/ml/labels.txt');
      final labels = FoodClassifier.parseLabels(rawLabels);

      expect(labels, hasLength(2024));
      expect(labels[0], '__background__');

      final midCount =
          labels.where((label) => label.startsWith('/')).length;
      final namedCount = labels
          .asMap()
          .entries
          .where((e) => FoodClassifier.isValidFoodLabel(e.key, e.value))
          .length;

      expect(midCount, 45);
      expect(namedCount, 1978);
      expect(labels, containsAll(<String>[
        'Chicago-style pizza',
        'New York-style pizza',
        'Hamburger',
        'Sushi',
        'Spaghetti',
        'Apple pie',
      ]));
    });

    test('food_model.tflite exists on disk with exact size and TFL3 magic header', () {
      final modelFile = _resolvePackageFile('assets/ml/food_model.tflite');
      expect(modelFile.existsSync(), isTrue);

      final bytes = modelFile.readAsBytesSync();
      expect(bytes.length, 21151551);
      expect(
        String.fromCharCodes(bytes.sublist(4, 8)),
        'TFL3',
      );
    });
  });

  group('ImagePreprocessor (Isolate.run)', () {
    test('center-crops non-square RGBA PNG and resizes to 192x192 RGB UINT8', () async {
      final image = img.Image(width: 300, height: 150, numChannels: 4);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          // Left/right margins blue; center 150x150 square green with alpha=128.
          final inCenter = x >= 75 && x < 225;
          image.setPixelRgba(
            x,
            y,
            inCenter ? 10 : 0,
            inCenter ? 220 : 0,
            inCenter ? 30 : 255,
            128,
          );
        }
      }
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final rgbBytes = await ImagePreprocessor.preprocessToRgbBytes(
        pngBytes,
        width: 192,
        height: 192,
      );

      expect(rgbBytes, hasLength(192 * 192 * 3));
      // Center-crop removes blue margins and strips alpha channel.
      expect(rgbBytes[0], 10);
      expect(rgbBytes[1], 220);
      expect(rgbBytes[2], 30);

      final centerOffset = ((96 * 192) + 96) * 3;
      expect(rgbBytes[centerOffset], 10);
      expect(rgbBytes[centerOffset + 1], 220);
      expect(rgbBytes[centerOffset + 2], 30);
    });

    test('bakes EXIF orientation 6 on JPEG before resizing', () async {
      // Orientation 6 = rotate 90 deg CW to display properly.
      // Source 120x120 image: top half red, bottom half blue.
      // After 90 deg CW rotation: right half is red, left half is blue.
      final image = img.Image(width: 120, height: 120);
      for (var y = 0; y < 120; y++) {
        for (var x = 0; x < 120; x++) {
          if (y < 60) {
            image.setPixelRgb(x, y, 250, 10, 10);
          } else {
            image.setPixelRgb(x, y, 10, 10, 250);
          }
        }
      }
      image.exif.imageIfd.orientation = 6;
      final jpegBytes = Uint8List.fromList(img.encodeJpg(image, quality: 95));

      final rgbBytes = await ImagePreprocessor.preprocessToRgbBytes(
        jpegBytes,
        width: 192,
        height: 192,
      );
      expect(rgbBytes, hasLength(192 * 192 * 3));

      // Check left-middle pixel (x=20, y=96) -> blue.
      final leftOffset = ((96 * 192) + 20) * 3;
      expect(rgbBytes[leftOffset + 2], greaterThan(200));
      expect(rgbBytes[leftOffset], lessThan(60));

      // Check right-middle pixel (x=172, y=96) -> red.
      final rightOffset = ((96 * 192) + 172) * 3;
      expect(rgbBytes[rightOffset], greaterThan(200));
      expect(rgbBytes[rightOffset + 2], lessThan(60));
    });

    test('throws FormatException on empty or corrupt image bytes', () async {
      await expectLater(
        () => ImagePreprocessor.preprocessToRgbBytes(Uint8List(0)),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        () => ImagePreprocessor.preprocessToRgbBytes(
          Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('normalizes 1-channel grayscale PNG to equal RGB channels', () async {
      final gray = img.Image(width: 40, height: 40, numChannels: 1);
      for (var y = 0; y < 40; y++) {
        for (var x = 0; x < 40; x++) {
          gray.setPixelR(x, y, 173);
        }
      }
      final pngBytes = Uint8List.fromList(img.encodePng(gray));

      final rgbBytes = await ImagePreprocessor.preprocessToRgbBytes(
        pngBytes,
        width: 192,
        height: 192,
      );
      final centerOffset = ((96 * 192) + 96) * 3;
      expect(rgbBytes[centerOffset], 173);
      expect(rgbBytes[centerOffset + 1], 173);
      expect(rgbBytes[centerOffset + 2], 173);
    });

    test('normalizes 16-bit RGB PNG proportionally to 8-bit UINT8', () async {
      final rgb16 = img.Image(
        width: 40,
        height: 40,
        format: img.Format.uint16,
        numChannels: 3,
      );
      for (var y = 0; y < 40; y++) {
        for (var x = 0; x < 40; x++) {
          rgb16.setPixelRgb(x, y, 32768, 16384, 65535);
        }
      }
      final pngBytes = Uint8List.fromList(img.encodePng(rgb16));

      final rgbBytes = await ImagePreprocessor.preprocessToRgbBytes(
        pngBytes,
        width: 192,
        height: 192,
      );
      final centerOffset = ((96 * 192) + 96) * 3;
      expect(rgbBytes[centerOffset], inInclusiveRange(127, 129));
      expect(rgbBytes[centerOffset + 1], inInclusiveRange(63, 65));
      expect(rgbBytes[centerOffset + 2], 255);
    });
  });

  group('Non-IO Classifier Stub Async Errors', () {
    test('warmUp and classifyImageBytes return async Future errors instead of throwing synchronously', () async {
      final classifier = classifier_stub.createLiteRtFoodClassifier(
        modelAssetPath: 'assets/ml/food_model.tflite',
        labelsAssetPath: 'assets/ml/labels.txt',
      );
      final warmUpFuture = classifier.warmUp();
      await expectLater(warmUpFuture, throwsA(isA<UnsupportedError>()));

      final classifyFuture = classifier.classifyImageBytes(Uint8List(4));
      await expectLater(classifyFuture, throwsA(isA<UnsupportedError>()));
      await classifier.dispose();
    });
  });

  group('UINT8 Post-Processing', () {
    test('filters __background__ and /g/ /m/ MIDs, scales / 256.0, and sorts deterministically', () {
      final labels = <String>[
        '__background__',
        '/g/11b8_rxx4d',
        '/m/083tx9',
        'Pizza',
        'Hamburger',
        'Sushi',
        'Spaghetti',
      ];
      final rawScores = <int>[255, 250, 240, 128, 128, 255, 10];

      final top = FoodClassifier.postProcessScores(
        rawScores,
        labels,
        topK: 3,
      );

      expect(top, hasLength(3));
      expect(top[0].label, 'Sushi');
      expect(top[0].rawIndex, 5);
      expect(top[0].confidence, closeTo(255 / 256.0, 0.0001));

      // Exact tie (128 == 128) breaks by rawIndex ascending (3 before 4).
      expect(top[1].label, 'Pizza');
      expect(top[1].rawIndex, 3);
      expect(top[1].confidence, closeTo(0.5, 0.0001));

      expect(top[2].label, 'Hamburger');
      expect(top[2].rawIndex, 4);
      expect(top[2].confidence, closeTo(0.5, 0.0001));

      final filtered = FoodClassifier.postProcessScores(
        rawScores,
        labels,
        topK: 5,
        minConfidence: 0.6,
      );
      expect(filtered, hasLength(1));
      expect(filtered.single.label, 'Sushi');
    });
  });

  group('NutritionCatalog, NutritionMapper & Portion Scaling', () {
    late NutritionCatalog catalog;
    late NutritionMapper mapper;

    setUpAll(() async {
      catalog = await NutritionCatalog.loadFromAsset();
      mapper = NutritionMapper(catalog);
    });

    test('resolves exact, alias, longest-phrase, and category matches accurately', () {
      final exact = mapper.mapLabelDetailed('Pizza');
      expect(exact.kind, NutritionMatchKind.exact);
      expect(exact.food.id, 'pizza');

      final alias = mapper.mapLabelDetailed('Pepperoni pizza');
      expect(alias.food.id, 'pepperoni_pizza');

      // Compound dish must not collide with raw fruit or plain breast.
      final dutchPie = mapper.mapLabelDetailed('Dutch apple pie');
      expect(dutchPie.food.id, 'apple_pie');

      final kfc = mapper.mapLabelDetailed('Korean fried chicken');
      expect(
        kfc.food.id,
        anyOf('korean_fried_chicken', 'fried_chicken'),
      );

      // Regional AIY classes resolve cleanly.
      final paloc = mapper.mapLabelDetailed('Palóc soup');
      expect(paloc.food.category, 'soup');

      final hainanCurry = mapper.mapLabelDetailed('Hainanese curry rice');
      expect(hainanCurry.food.category, anyOf('curry', 'rice'));

      final chicagoPizza = mapper.mapLabelDetailed('Chicago-style pizza');
      expect(chicagoPizza.food.id, 'pizza');

      // Compound dishes must resolve to dish head-noun rather than raw modifiers.
      expect(mapper.mapLabel('Apple cake').id, 'cake');
      expect(mapper.mapLabel('Gooey butter cake').id, 'cake');
      expect(mapper.mapLabel('Honey cake').id, 'cake');
      expect(mapper.mapLabel('Grape pie').id, 'pie');
      expect(mapper.mapLabel('Blackberry pie').id, 'pie');
      expect(mapper.mapLabel('Bean pie').id, 'pie');
      expect(mapper.mapLabel('Peanut soup').id, 'soup');
      expect(mapper.mapLabel('Cucumber soup').id, 'soup');
      expect(mapper.mapLabel('Tomato and egg soup').id, 'soup');
      expect(mapper.mapLabel('Bread soup').id, 'soup');
      expect(mapper.mapLabel('Eggplant Salad').id, 'garden_salad');
      expect(mapper.mapLabel('Cookie salad').id, 'garden_salad');
      expect(mapper.mapLabel('Sausage sandwich').id, 'club_sandwich');
      expect(
        mapper.mapLabel('Peanut butter and jelly sandwich').id,
        'club_sandwich',
      );
      expect(
        mapper.mapLabel('Duck rice').id,
        anyOf('duck_roast', 'rice_dish'),
      );
      expect(mapper.mapLabel('Butter cookie').id, 'cookie');
      expect(mapper.mapLabel('Pistachio pudding').id, 'pudding');

      // Specific multi-word dishes stay intact.
      expect(mapper.mapLabel('Apple pie').id, 'apple_pie');
      expect(mapper.mapLabel('Chicken noodle soup').id, 'chicken_noodle_soup');
      expect(mapper.mapLabel('Chocolate cake').id, 'chocolate_cake');
      expect(mapper.mapLabel('Fried rice').id, 'fried_rice');
      expect(mapper.mapLabel('Caesar salad').id, 'caesar_salad');

      // Obscure AIY classes resolve without null.
      for (final obscure in <String>['Kondowole', 'Chaudin', 'Bambalouni']) {
        final resolved = mapper.mapLabel(obscure);
        expect(resolved.id, isNotEmpty);
        expect(resolved.kcalPer100g, greaterThan(0));
        expect(resolved.defaultServingGrams, greaterThan(0));
      }
    });

    test('handles accompaniment clauses, beverage modifiers, quotes, Vietnamese bun, and keyword collisions', () {
      // 1. Accompaniment "with ..." clause must not override main entrée;
      //    "Shrimp and grits" must resolve to shrimp, while standalone "Grits" stays mashed_potatoes.
      expect(mapper.mapLabel('Steak with fries').id, 'steak');
      expect(mapper.mapLabel('Steak with mashed potatoes').id, 'steak');
      expect(mapper.mapLabel('Salmon with broccoli').id, 'salmon_fillet');
      expect(mapper.mapLabel('Chicken with mashed potatoes').id, 'chicken');
      expect(mapper.mapLabel('Chicken with roasted vegetables').id, 'chicken');
      expect(mapper.mapLabel('Shrimp with grits').id, 'shrimp');
      expect(mapper.mapLabel('Shrimp and grits').id, 'shrimp');
      expect(mapper.mapLabel('Grits').id, 'mashed_potatoes');
      expect(mapper.mapLabel('House special with fries').id, 'french_fries');

      // 2. Beverage modifier needles must not override protein/egg/dish heads,
      //    while standalone beverages and beverage heads with dessert/snack
      //    modifiers continue resolving to beverage profiles.
      expect(mapper.mapLabel('Tea egg').id, 'boiled_egg');
      expect(mapper.mapLabel('Tea smoked duck').id, 'duck_roast');
      expect(mapper.mapLabel('Coffee rubbed steak').id, 'steak');
      expect(mapper.mapLabel('Russian tea cake').id, 'cake');
      expect(mapper.mapLabel('Green tea ice cream').id, 'ice_cream');
      expect(mapper.mapLabel('Coffee ice cream').id, 'ice_cream');
      expect(mapper.mapLabel('Chocolate cake').id, 'chocolate_cake');
      expect(mapper.mapLabel('Chocolate ice cream').id, 'ice_cream');
      expect(mapper.mapLabel('Chocolate milkshake').id, 'milkshake');
      final chocolateShake = mapper.mapLabel('Chocolate shake');
      expect(chocolateShake.id, anyOf('milkshake', 'protein_shake'));
      expect(chocolateShake.category, 'beverage');
      expect(chocolateShake.id, isNot('dark_chocolate'));
      expect(mapper.mapLabel('Chocolate smoothie').id, 'berry_smoothie');
      expect(mapper.mapLabel('Chocolate protein shake').id, 'protein_shake');
      expect(mapper.mapLabel('Candy shake').category, 'beverage');
      expect(mapper.mapLabel('Strawberry smoothie').id, 'berry_smoothie');
      expect(mapper.mapLabel('Banana smoothie').id, 'berry_smoothie');
      expect(mapper.mapLabel('Green tea').id, 'green_tea');
      expect(mapper.mapLabel('Black coffee').id, 'black_coffee');
      expect(mapper.mapLabel('Iced tea').id, 'green_tea');
      expect(mapper.mapLabel('Iced green tea').id, 'green_tea');
      expect(mapper.mapLabel('Orange juice').id, 'orange_juice');
      expect(mapper.mapLabel('Berry smoothie').id, 'berry_smoothie');
      expect(mapper.mapLabel('Chai tea').id, 'green_tea');
      expect(mapper.mapLabel('Masala chai').id, 'green_tea');

      // 3. Unstripped ASCII and curly double quotes in normalizeNutritionTerm / AIY labels.
      expect(normalizeNutritionTerm('"Peanut butter'), 'peanut butter');
      expect(normalizeNutritionTerm('“Bacon”'), 'bacon');
      expect(mapper.mapLabel('"Peanut butter').id, 'peanut_butter');
      expect(mapper.mapLabel('"Bacon').id, 'bacon');

      // 4. Vietnamese "Bún ..." noodle soups (both NFC and NFD) vs unaccented
      //    "bun" bread, plus Tier 3 keyword collision fixes.
      expect(
        normalizeNutritionTerm('Bún bò Huế'),
        normalizeNutritionTerm('Bu\u0301n bo\u0300 Hu\u00ea\u0301'),
      );
      expect(normalizeNutritionTerm('bu\u0301n riêu'), 'bun rieu');
      for (final bunSoup in <String>[
        'Bún bò Huế',
        'Bu\u0301n bo\u0300 Hu\u00ea\u0301',
        'Bún riêu',
        'bu\u0301n riêu',
        'Bún ốc',
        'bu\u0301n o\u0302\u0301c',
      ]) {
        final resolved = mapper.mapLabel(bunSoup);
        expect(
          resolved.id,
          anyOf('beef_pho_bo', 'pho', 'noodles'),
          reason: bunSoup,
        );
        expect(resolved.category, 'noodles', reason: bunSoup);
        expect(resolved.id, isNot('mixed_meal'), reason: bunSoup);
        expect(resolved.id, isNot('bread'), reason: bunSoup);
      }
      expect(mapper.mapLabel('bu\u0301n riêu').id, 'noodles');
      expect(mapper.mapLabel('Steamed bun').id, 'bread');
      expect(mapper.mapLabel('Chelsea bun').id, 'bread');
      expect(mapper.mapLabel('Iced bun').id, 'bread');
      expect(mapper.mapLabel('Hamburger bun').id, 'bread');
      expect(
        mapper.mapLabel('Pork bun').id,
        anyOf('pork_bun', 'pork_dumplings', 'bread'),
      );

      expect(mapper.mapLabel('Chai tow kway').id, isNot('green_tea'));
      expect(mapper.mapLabel('Sweet and sour pork').id, 'pork');
      expect(mapper.mapLabel('Sweet and sour chicken').id, 'kung_pao_chicken');
      expect(mapper.mapLabel('Jelly bean').id, 'candy');
      expect(mapper.mapLabel('Jelly bean').id, isNot('black_beans'));
      expect(mapper.mapLabel('Jambon persillé').id, isNot('grilled_cheese_tomato'));
      expect(mapper.mapLabel('Jambon beurre').id, 'grilled_cheese_tomato');

      // Guard holds even in a minimal catalog without a dedicated candy entry.
      final beansOnlyCatalog = NutritionCatalog.fromFoods(<NutritionFood>[
        catalog.findById('black_beans')!,
        catalog.findById('mixed_meal')!,
      ]);
      final beansOnlyMapper = NutritionMapper(beansOnlyCatalog);
      expect(beansOnlyMapper.mapLabel('Jelly bean').id, 'mixed_meal');
    });

    test('maps all 1,978 named AIY Food V1 labels to valid non-null NutritionFood and exercises Tier 4', () async {
      final rawLabels = await loadFoodAssetString('assets/ml/labels.txt');
      final labels = FoodClassifier.parseLabels(rawLabels);
      var checkedCount = 0;
      final tierCounts = <NutritionMatchKind, int>{};

      for (var i = 0; i < labels.length; i++) {
        final label = labels[i];
        if (!FoodClassifier.isValidFoodLabel(i, label)) continue;
        checkedCount++;

        final match = mapper.mapLabelDetailed(label);
        tierCounts[match.kind] = (tierCounts[match.kind] ?? 0) + 1;
        final food = match.food;
        expect(food.id, isNotEmpty, reason: 'Empty food id for "$label"');
        expect(
          food.kcalPer100g.isFinite && food.kcalPer100g > 0,
          isTrue,
          reason: 'Invalid kcal for "$label" -> ${food.id}',
        );
        expect(
          food.defaultServingGrams > 0,
          isTrue,
          reason: 'Invalid serving for "$label" -> ${food.id}',
        );
      }

      expect(checkedCount, 1978);
      expect(tierCounts[NutritionMatchKind.category] ?? 0, greaterThan(0));
    });

    test('mapPredictions deduplicates mapped foods and scales servings proportionally', () {
      final mapped = mapper.mapPredictions(<FoodPrediction>[
        const FoodPrediction(label: 'Pizza', rawIndex: 10, confidence: 0.72),
        const FoodPrediction(
          label: 'Chicago-style pizza',
          rawIndex: 11,
          confidence: 0.41,
        ),
        const FoodPrediction(label: 'Sushi', rawIndex: 12, confidence: 0.25),
      ]);

      expect(mapped, hasLength(2));
      expect(mapped[0].prediction.matchedFood?.id, 'pizza');
      expect(mapped[0].prediction.confidence, 0.72);
      expect(mapped[1].prediction.matchedFood?.id, 'sushi');

      final pizza = mapped[0].match.food;
      final twoHundredGrams = pizza.forServing(200.0);
      expect(twoHundredGrams.kcal, closeTo(pizza.kcalPer100g * 2.0, 0.001));
      expect(
        twoHundredGrams.proteinGrams,
        closeTo(pizza.proteinPer100g * 2.0, 0.001),
      );
      expect(
        twoHundredGrams.carbsGrams,
        closeTo(pizza.carbsPer100g * 2.0, 0.001),
      );
      expect(
        twoHundredGrams.fatGrams,
        closeTo(pizza.fatPer100g * 2.0, 0.001),
      );
      expect(pizza.forServing(0.0).kcal, 0.0);
    });

    test('catalog search supports query ranking and category filtering', () {
      final oatmeal = catalog.search('oatmeal');
      expect(oatmeal, isNotEmpty);
      expect(oatmeal.first.id, 'oatmeal_cooked');

      final salmon = catalog.search('salmon');
      expect(salmon.any((f) => f.id == 'salmon_fillet'), isTrue);

      final seafoodOnly = catalog.search('', category: 'seafood');
      expect(seafoodOnly, isNotEmpty);
      expect(
        seafoodOnly.every((f) => f.category == 'seafood'),
        isTrue,
      );
    });
  });
}
