import 'dart:math';

import 'package:housekeepr/core/quantity_unit_formatter.dart';
import 'package:test/test.dart';

void main() {
  group('formatQuantityUnit', () {
    test('keeps uncountable units unchanged', () {
      expect(formatQuantityUnit('kg', 1), 'kg');
      expect(formatQuantityUnit('L', 3), 'L');
    });

    test('uses singular form for quantity one', () {
      expect(formatQuantityUnit('stuks', 1), 'stuk');
      expect(formatQuantityUnit('potten', 1), 'pot');
      expect(formatQuantityUnit('pakken', 1), 'pak');
      expect(formatQuantityUnit('flessen', 1), 'fles');
    });

    test('uses plural form for quantity greater than one', () {
      expect(formatQuantityUnit('stuk', 2), 'stuks');
      expect(formatQuantityUnit('pot', 2), 'potten');
      expect(formatQuantityUnit('pak', 2), 'pakken');
      expect(formatQuantityUnit('fles', 2), 'flessen');
      expect(formatQuantityUnit('ei', 2), 'eieren');
    });

    test('returns the original unit when no mapping exists', () {
      expect(formatQuantityUnit('literatuur', 2), 'literatuur');
    });
  });
}
