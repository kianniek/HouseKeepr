import 'package:housekeepr/core/grocery_parser.dart';
import 'package:housekeepr/models/grocery_category.dart';
import 'package:test/test.dart';

void main() {
  group('GroceryParser', () {
    test(
      'does not mistakenly extract single-letter or short units from words',
      () {
        final lasagne = GroceryParser.parseLine('lasagne');
        expect(lasagne.name, 'Lasagne');
        expect(lasagne.quantity, 1.0);
        expect(lasagne.unit, isNull);

        final limoen = GroceryParser.parseLine('1 limoen');
        expect(limoen.name, 'Limoen');
        expect(limoen.quantity, 1.0);
        expect(limoen.unit, isNull);

        final grapefruit = GroceryParser.parseLine('2 grapefruits');
        expect(grapefruit.name, 'Grapefruits');
        expect(grapefruit.quantity, 2.0);
        expect(grapefruit.unit, isNull);

        final gember = GroceryParser.parseLine('gember');
        expect(gember.name, 'Gember');
        expect(gember.quantity, 1.0);
        expect(gember.unit, isNull);

        final paksoi = GroceryParser.parseLine('1 paksoi');
        expect(paksoi.name, 'Paksoi');
        expect(paksoi.quantity, 1.0);
        expect(paksoi.unit, isNull);

        final flespompoen = GroceryParser.parseLine('1 flespompoen');
        expect(flespompoen.name, 'Flespompoen');
        expect(flespompoen.quantity, 1.0);
        expect(flespompoen.unit, isNull);
      },
    );

    test('extracts units with numbers accurately', () {
      final melk = GroceryParser.parseLine('2 pakken melk');
      expect(melk.name, 'Melk');
      expect(melk.quantity, 2.0);
      expect(melk.unit, 'pak');
      expect(melk.category, GroceryCategory.dairy);

      final pasta = GroceryParser.parseLine('500g pasta');
      expect(pasta.name, 'Pasta');
      expect(pasta.quantity, 500.0);
      expect(pasta.unit, 'g');

      final pastaGram = GroceryParser.parseLine('500 gram pasta');
      expect(pastaGram.name, 'Pasta');
      expect(pastaGram.quantity, 500.0);
      expect(pastaGram.unit, 'g');

      final appels = GroceryParser.parseLine('1,5 kg appels');
      expect(appels.name, 'Appels');
      expect(appels.quantity, 1.5);
      expect(appels.unit, 'kg');
      expect(appels.category, GroceryCategory.fruit);

      final tomaten = GroceryParser.parseLine('2 blikken tomatenblokjes');
      expect(tomaten.name, 'Tomatenblokjes');
      expect(tomaten.quantity, 2.0);
      expect(tomaten.unit, 'blik');

      final chips = GroceryParser.parseLine('2 zakken chips');
      expect(chips.name, 'Chips');
      expect(chips.quantity, 2.0);
      expect(chips.unit, 'zak');
      expect(chips.category, GroceryCategory.snacks);

      final olie = GroceryParser.parseLine('2 eetlepels olijfolie');
      expect(olie.name, 'Olijfolie');
      expect(olie.quantity, 2.0);
      expect(olie.unit, 'el');

      final zout = GroceryParser.parseLine('1 tl zout');
      expect(zout.name, 'Zout');
      expect(zout.quantity, 1.0);
      expect(zout.unit, 'tl');
    });

    test('extracts garlic cloves in various forms', () {
      final teen1 = GroceryParser.parseLine('2 teentjes knoflook');
      expect(teen1.name, 'Knoflook');
      expect(teen1.quantity, 2.0);
      expect(teen1.unit, 'teen');
      expect(teen1.category, GroceryCategory.vegetables);

      final teen2 = GroceryParser.parseLine('1 teen knoflook');
      expect(teen2.name, 'Knoflook');
      expect(teen2.quantity, 1.0);
      expect(teen2.unit, 'teen');

      final teen3 = GroceryParser.parseLine('1 teenknoflook');
      expect(teen3.name, 'Knoflook');
      expect(teen3.quantity, 1.0);
      expect(teen3.unit, 'teen');

      final teen4 = GroceryParser.parseLine('2 tenen knoflook');
      expect(teen4.name, 'Knoflook');
      expect(teen4.quantity, 2.0);
      expect(teen4.unit, 'teen');

      final teen5 = GroceryParser.parseLine('2 knoflooktenen');
      expect(teen5.name, 'Knoflook');
      expect(teen5.quantity, 2.0);
      expect(teen5.unit, 'teen');
    });

    test('handles fractions correctly', () {
      final halfBloemkool = GroceryParser.parseLine('½ bloemkool');
      expect(halfBloemkool.name, 'Bloemkool');
      expect(halfBloemkool.quantity, 0.5);
      expect(halfBloemkool.unit, isNull);

      final oneAndHalf = GroceryParser.parseLine('1 ½ el honing');
      expect(oneAndHalf.name, 'Honing');
      expect(oneAndHalf.quantity, 1.5);
      expect(oneAndHalf.unit, 'el');

      final slashFraction = GroceryParser.parseLine('1/2 ui');
      expect(slashFraction.name, 'Ui');
      expect(slashFraction.quantity, 0.5);
      expect(slashFraction.unit, isNull);

      final mixedSlash = GroceryParser.parseLine('1 1/2 tl kaneel');
      expect(mixedSlash.name, 'Kaneel');
      expect(mixedSlash.quantity, 1.5);
      expect(mixedSlash.unit, 'tl');
    });

    test('strips leading bullet markers and numbers', () {
      final bullet1 = GroceryParser.parseLine('- 2 appels');
      expect(bullet1.name, 'Appels');
      expect(bullet1.quantity, 2.0);

      final bullet2 = GroceryParser.parseLine('* 1 pak melk');
      expect(bullet2.name, 'Melk');
      expect(bullet2.quantity, 1.0);
      expect(bullet2.unit, 'pak');

      final bullet3 = GroceryParser.parseLine('1. 3 bananen');
      expect(bullet3.name, 'Bananen');
      expect(bullet3.quantity, 3.0);

      final bullet4 = GroceryParser.parseLine('[ ] kaas');
      expect(bullet4.name, 'Kaas');
      expect(bullet4.quantity, 1.0);
    });

    test('extracts notes and descriptors', () {
      final withComma = GroceryParser.parseLine('1 ui, gesnipperd');
      expect(withComma.name, 'Ui');
      expect(withComma.quantity, 1.0);
      expect(withComma.note, 'gesnipperd');

      final withParen = GroceryParser.parseLine(
        'tomatenblokjes (blik van 400g)',
      );
      expect(withParen.name, 'Tomatenblokjes');
      expect(withParen.note, 'blik van 400g');
    });

    test('handles multiplier prefix and quantity at the end', () {
      final multiPrefix = GroceryParser.parseLine('2x melk');
      expect(multiPrefix.name, 'Melk');
      expect(multiPrefix.quantity, 2.0);

      final endAmount = GroceryParser.parseLine('pasta 500g');
      expect(endAmount.name, 'Pasta');
      expect(endAmount.quantity, 500.0);
      expect(endAmount.unit, 'g');

      final endQty = GroceryParser.parseLine('appels 2x');
      expect(endQty.name, 'Appels');
      expect(endQty.quantity, 2.0);
    });
  });
}
