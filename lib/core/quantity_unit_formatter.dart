String? formatQuantityUnit(String? unit, double quantity) {
  if (unit == null) return null;

  final trimmedUnit = unit.trim();
  if (trimmedUnit.isEmpty) return null;

  final normalizedUnit = trimmedUnit.toLowerCase();
  if (_uncountableUnits.contains(normalizedUnit)) {
    return trimmedUnit;
  }

  if (quantity == 1) {
    return _singularUnits[normalizedUnit] ?? trimmedUnit;
  }

  return _pluralUnits[normalizedUnit] ?? trimmedUnit;
}

const Set<String> _uncountableUnits = {'g', 'kg', 'ml', 'l', 'el', 'tl'};

const Map<String, String> _singularUnits = {
  'stuk': 'stuk',
  'stuks': 'stuk',
  'pot': 'pot',
  'potten': 'pot',
  'pak': 'pak',
  'pakken': 'pak',
  'blik': 'blik',
  'blikken': 'blik',
  'fles': 'fles',
  'flessen': 'fles',
  'zak': 'zak',
  'zakken': 'zak',
  'ei': 'ei',
  'eieren': 'ei',
  'doos': 'doos',
  'dozen': 'doos',
  'vel': 'vel',
  'vellen': 'vel',
};

const Map<String, String> _pluralUnits = {
  'stuk': 'stuks',
  'stuks': 'stuks',
  'pot': 'potten',
  'potten': 'potten',
  'pak': 'pakken',
  'pakken': 'pakken',
  'blik': 'blikken',
  'blikken': 'blikken',
  'fles': 'flessen',
  'flessen': 'flessen',
  'zak': 'zakken',
  'zakken': 'zakken',
  'ei': 'eieren',
  'eieren': 'eieren',
  'doos': 'dozen',
  'dozen': 'dozen',
  'vel': 'vellen',
  'vellen': 'vellen',
};
