import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ai/nutrition_estimator.dart';
import '../ml/nutrition_catalog.dart';
import '../ml/nutrition_mapper.dart';
import '../models/meal_log.dart';
import '../models/meal_type.dart';
import '../models/nutrition_food.dart';
import 'nutrition_autofill_helper.dart';

/// Modal confirmation sheet after offline AI food recognition.
///
/// Lets the user switch among top mapped predictions, search [catalog] for a
/// different food, adjust serving grams (with live macro scaling), optionally
/// switch to custom nutrition fields, and select [MealType] before saving.
class FoodConfirmationSheet extends StatefulWidget {
  const FoodConfirmationSheet({
    super.key,
    required this.mappedPredictions,
    required this.catalog,
    required this.initialMealType,
    this.previewBytes,
    this.targetDate,
    this.onConfirmPlate,
    this.estimator,
    this.isAiModelReady = false,
    this.onOpenAiModelManager,
  });

  final List<MappedFoodPrediction> mappedPredictions;
  final NutritionCatalog catalog;
  final MealType initialMealType;
  final Uint8List? previewBytes;
  final DateTime? targetDate;
  final ValueChanged<List<MealLog>>? onConfirmPlate;
  final NutritionEstimator? estimator;
  final bool isAiModelReady;
  final VoidCallback? onOpenAiModelManager;

  @override
  State<FoodConfirmationSheet> createState() => _FoodConfirmationSheetState();
}

enum _PortionHint {
  small('Small', 0.75),
  medium('Medium', 1.0),
  large('Large', 1.5);

  const _PortionHint(this.label, this.multiplier);
  final String label;
  final double multiplier;
}

class _FoodConfirmationSheetState extends State<FoodConfirmationSheet> {
  static const NutritionFood _fallbackFood = NutritionFood(
    id: 'mixed_meal',
    name: 'Mixed Meal',
    category: 'mixed',
    kcalPer100g: 165.0,
    proteinPer100g: 9.0,
    carbsPer100g: 18.0,
    fatPer100g: 6.0,
    defaultServingGrams: 250.0,
    servingLabel: '1 plate (250g)',
  );

  late NutritionFood _selectedFood;
  late MealType _selectedMealType;
  late final TextEditingController _gramsController;
  late final TextEditingController _searchController;
  late final TextEditingController _customNameController;
  late final TextEditingController _customKcalController;
  late final TextEditingController _customProteinController;
  late final TextEditingController _customCarbsController;
  late final TextEditingController _customFatController;

  bool _isCustomMode = false;
  bool _showCatalogSearch = false;
  bool _isEstimating = false;
  NutritionEstimate? _lastEstimate;
  String? _validationError;
  _PortionHint? _portionHint = _PortionHint.medium;
  final List<MealLog> _plateItems = <MealLog>[];
  late final NutritionEstimator _estimator;

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.initialMealType;
    _selectedFood = _initialFood();
    _estimator =
        widget.estimator ?? HybridNutritionEstimator(catalog: widget.catalog);

    _gramsController = TextEditingController(
      text: _formatNumber(_selectedFood.defaultServingGrams),
    );
    _searchController = TextEditingController();
    _customNameController = TextEditingController(text: _selectedFood.name);

    final initialMacros = _selectedFood.defaultServingMacros;
    _customKcalController = TextEditingController(
      text: _formatNumber(initialMacros.kcal),
    );
    _customProteinController = TextEditingController(
      text: _formatNumber(initialMacros.proteinGrams),
    );
    _customCarbsController = TextEditingController(
      text: _formatNumber(initialMacros.carbsGrams),
    );
    _customFatController = TextEditingController(
      text: _formatNumber(initialMacros.fatGrams),
    );
  }

  NutritionFood _initialFood() {
    if (widget.mappedPredictions.isNotEmpty) {
      return widget.mappedPredictions.first.match.food;
    }
    return widget.catalog.findById('mixed_meal') ??
        (widget.catalog.foods.isNotEmpty
            ? widget.catalog.foods.first
            : _fallbackFood);
  }

  @override
  void dispose() {
    _gramsController.dispose();
    _searchController.dispose();
    _customNameController.dispose();
    _customKcalController.dispose();
    _customProteinController.dispose();
    _customCarbsController.dispose();
    _customFatController.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (!value.isFinite) return '0';
    if ((value - value.roundToDouble()).abs() < 0.05) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  double? _parsePositiveDouble(String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    return parsed;
  }

  double _parseNonNegativeOrZero(String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite || parsed < 0) return 0.0;
    return parsed;
  }

  void _selectCatalogFood(NutritionFood food) {
    final multiplier = _portionHint?.multiplier ?? 1.0;
    final scaledGrams = food.defaultServingGrams * multiplier;
    final macros = food.macrosForGrams(scaledGrams);
    setState(() {
      _selectedFood = food;
      _isCustomMode = false;
      _showCatalogSearch = false;
      _validationError = null;
      _gramsController.text = _formatNumber(scaledGrams);
      _customNameController.text = food.name;
      _customKcalController.text = _formatNumber(macros.kcal);
      _customProteinController.text = _formatNumber(macros.proteinGrams);
      _customCarbsController.text = _formatNumber(macros.carbsGrams);
      _customFatController.text = _formatNumber(macros.fatGrams);
    });
  }

  void _applyPortionHint(_PortionHint hint) {
    final grams = _selectedFood.defaultServingGrams * hint.multiplier;
    setState(() {
      _portionHint = hint;
      _gramsController.text = _formatNumber(grams);
      _validationError = null;
    });
  }

  void _toggleCustomMode(bool custom) {
    if (custom == _isCustomMode) return;
    if (custom) {
      final grams =
          _parsePositiveDouble(_gramsController.text) ??
          _selectedFood.defaultServingGrams;
      final macros = _selectedFood.macrosForGrams(grams);
      _customNameController.text = _selectedFood.name;
      _customKcalController.text = _formatNumber(macros.kcal);
      _customProteinController.text = _formatNumber(macros.proteinGrams);
      _customCarbsController.text = _formatNumber(macros.carbsGrams);
      _customFatController.text = _formatNumber(macros.fatGrams);
    }
    setState(() {
      _isCustomMode = custom;
      _validationError = null;
    });
  }

  void _clearCustomMacros() {
    setState(() {
      _customKcalController.clear();
      _customProteinController.clear();
      _customCarbsController.clear();
      _customFatController.clear();
      _lastEstimate = null;
      _validationError = null;
    });
  }

  Future<void> _runAutoFill() async {
    if (_isEstimating) return;
    if (_customNameController.text.trim().isEmpty) {
      setState(() {
        _validationError = 'Enter a food name first to auto-fill.';
      });
      return;
    }
    setState(() {
      _isEstimating = true;
      _validationError = null;
    });
    try {
      final estimate = await NutritionAutoFillHelper.fillEmptyFields(
        estimator: _estimator,
        nameController: _customNameController,
        gramsController: _gramsController,
        kcalController: _customKcalController,
        proteinController: _customProteinController,
        carbsController: _customCarbsController,
        fatController: _customFatController,
      );
      if (!mounted) return;
      setState(() {
        _lastEstimate = estimate;
        _isEstimating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isEstimating = false;
      });
    }
  }

  DateTime _resolveLoggedAt() {
    final now = DateTime.now();
    final target = widget.targetDate?.toLocal();
    if (target == null ||
        (target.year == now.year &&
            target.month == now.month &&
            target.day == now.day)) {
      return now;
    }
    return DateTime(
      target.year,
      target.month,
      target.day,
      now.hour,
      now.minute,
      now.second,
    );
  }

  MealLog? _buildCurrentLog() {
    final grams = _parsePositiveDouble(_gramsController.text);
    if (grams == null) {
      setState(() {
        _validationError = 'Enter a serving size greater than 0 g.';
      });
      return null;
    }

    final loggedAt = _resolveLoggedAt();
    if (_isCustomMode) {
      final name = _customNameController.text.trim();
      if (name.isEmpty) {
        setState(() {
          _validationError = 'Enter a food name.';
        });
        return null;
      }
      final kcal = double.tryParse(
        _customKcalController.text.trim().replaceAll(',', '.'),
      );
      if (kcal == null || !kcal.isFinite || kcal < 0) {
        setState(() {
          _validationError = 'Enter valid calories (0 or greater).';
        });
        return null;
      }
      return MealLog.create(
        foodName: name,
        mealType: _selectedMealType,
        servingGrams: grams,
        kcal: kcal,
        proteinGrams: _parseNonNegativeOrZero(_customProteinController.text),
        carbsGrams: _parseNonNegativeOrZero(_customCarbsController.text),
        fatGrams: _parseNonNegativeOrZero(_customFatController.text),
        loggedAt: loggedAt,
      );
    }

    return MealLog.fromNutritionFood(
      food: _selectedFood,
      mealType: _selectedMealType,
      servingGrams: grams,
      loggedAt: loggedAt,
    );
  }

  void _addCurrentItemToPlate() {
    final current = _buildCurrentLog();
    if (current == null) return;
    setState(() {
      _plateItems.add(current);
      _showCatalogSearch = true;
      _searchController.clear();
      _validationError = null;
      if (_isCustomMode) {
        _isCustomMode = false;
      }
    });
  }

  void _confirm() {
    final current = _buildCurrentLog();
    if (current == null) return;

    final onConfirmPlate = widget.onConfirmPlate;
    if (onConfirmPlate != null) {
      final allItems = <MealLog>[
        ..._plateItems.map(
          (item) => item.copyWith(mealType: _selectedMealType),
        ),
        current,
      ];
      onConfirmPlate(allItems);
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop(current);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final grams = _parsePositiveDouble(_gramsController.text) ?? 0.0;
    final scaledMacros = _selectedFood.macrosForGrams(grams);
    final topMapped = widget.mappedPredictions.take(5).toList();
    final searchResults = _showCatalogSearch
        ? widget.catalog.search(_searchController.text, limit: 15)
        : const <NutritionFood>[];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (widget.previewBytes != null) ...<Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        widget.previewBytes!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Confirm Food Snap',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          topMapped.isNotEmpty
                              ? 'Detected: ${topMapped.first.prediction.label} '
                                    '(${topMapped.first.prediction.confidencePercent.round()}%)'
                              : 'No confident match found — review or search below.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              if (topMapped.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  'Top matches',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: topMapped.map((entry) {
                    final food = entry.match.food;
                    final isSelected =
                        !_isCustomMode && _selectedFood.id == food.id;
                    return ChoiceChip(
                      label: Text(
                        '${food.name} · ${entry.prediction.confidencePercent.round()}%',
                      ),
                      selected: isSelected,
                      onSelected: (_) => _selectCatalogFood(food),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        _showCatalogSearch
                            ? Icons.expand_less
                            : Icons.search_rounded,
                      ),
                      label: Text(
                        _showCatalogSearch ? 'Hide catalog' : 'Switch food',
                      ),
                      onPressed: () {
                        setState(() {
                          _showCatalogSearch = !_showCatalogSearch;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Custom'),
                    selected: _isCustomMode,
                    onSelected: _toggleCustomMode,
                  ),
                ],
              ),
              if (_showCatalogSearch) ...<Widget>[
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search nutrition catalog...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: searchResults.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No matching foods found.'),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: searchResults.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final food = searchResults[index];
                              return ListTile(
                                dense: true,
                                title: Text(food.name),
                                subtitle: Text(
                                  '${food.servingLabel} · '
                                  '${food.defaultServingMacros.kcal.round()} kcal',
                                ),
                                trailing: _selectedFood.id == food.id
                                    ? Icon(
                                        Icons.check_circle,
                                        color: colorScheme.primary,
                                      )
                                    : null,
                                onTap: () => _selectCatalogFood(food),
                              );
                            },
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (!_isCustomMode) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _selectedFood.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${scaledMacros.kcal.round()} kcal',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Default serving: ${_selectedFood.servingLabel}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Protein ${scaledMacros.proteinGrams.toStringAsFixed(1)} g · '
                        'Carbs ${scaledMacros.carbsGrams.toStringAsFixed(1)} g · '
                        'Fat ${scaledMacros.fatGrams.toStringAsFixed(1)} g',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Portion size',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _PortionHint.values.map((hint) {
                    return ChoiceChip(
                      label: Text(hint.label),
                      selected: _portionHint == hint,
                      onSelected: (_) => _applyPortionHint(hint),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _gramsController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Serving size (g)',
                    border: OutlineInputBorder(),
                    suffixText: 'g',
                  ),
                  onChanged: (_) => setState(() {
                    _portionHint = null;
                    _validationError = null;
                  }),
                ),
              ] else ...<Widget>[
                TextField(
                  controller: _customNameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Food name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _validationError = null),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _gramsController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Serving (g)',
                          hintText: 'Auto',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) =>
                            setState(() => _validationError = null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _customKcalController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Calories (kcal)',
                          hintText: '0',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) =>
                            setState(() => _validationError = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _isEstimating ? null : _runAutoFill,
                      icon: _isEstimating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        _isEstimating ? 'Estimating...' : 'Auto-fill',
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _clearCustomMacros,
                      child: const Text('Clear'),
                    ),
                    if (_lastEstimate != null) ...<Widget>[
                      const SizedBox(width: 6),
                      Flexible(
                        child: NutritionAutoFillSourceChip(
                          estimate: _lastEstimate!,
                          isAiModelReady: widget.isAiModelReady,
                          onOpenAiModelManager: widget.onOpenAiModelManager,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _customProteinController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Protein (g)',
                          hintText: '0',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _customCarbsController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Carbs (g)',
                          hintText: '0',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _customFatController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Fat (g)',
                          hintText: '0',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Meal',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: MealType.values.map((mealType) {
                  return ChoiceChip(
                    label: Text(mealType.label),
                    selected: _selectedMealType == mealType,
                    onSelected: (_) =>
                        setState(() => _selectedMealType = mealType),
                  );
                }).toList(),
              ),
              if (_plateItems.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  'Plate items (${_plateItems.length})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: List<Widget>.generate(_plateItems.length, (index) {
                    final item = _plateItems[index];
                    return InputChip(
                      label: Text(
                        '${item.foodName} (${item.kcal.round()} kcal)',
                      ),
                      onDeleted: () {
                        setState(() {
                          _plateItems.removeAt(index);
                        });
                      },
                    );
                  }),
                ),
              ],
              if (_validationError != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _validationError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (widget.onConfirmPlate != null)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addCurrentItemToPlate,
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text('Add to plate'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _confirm,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          _plateItems.isEmpty
                              ? 'Log Meal'
                              : 'Log ${_plateItems.length + 1} Items',
                        ),
                      ),
                    ),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Log Meal'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
