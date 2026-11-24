import 'package:flutter/material.dart';

import '../ai/nutrition_estimator.dart';
import '../ml/nutrition_catalog.dart';
import '../models/meal_log.dart';
import '../models/meal_type.dart';
import '../models/nutrition_food.dart';
import 'nutrition_autofill_helper.dart';

/// Modal sheet for manually logging a food from [NutritionCatalog] or
/// entering one-off custom calories and macros.
class ManualFoodAddSheet extends StatefulWidget {
  const ManualFoodAddSheet({
    super.key,
    required this.catalog,
    required this.initialMealType,
    this.targetDate,
    this.favoriteFoodIds = const <String>[],
    this.recentFoodIds = const <String>[],
    this.onToggleFavorite,
    this.onSaveCustomFood,
    this.estimator,
    this.isAiModelReady = false,
    this.onOpenAiModelManager,
  });

  final NutritionCatalog catalog;
  final MealType initialMealType;
  final DateTime? targetDate;
  final List<String> favoriteFoodIds;
  final List<String> recentFoodIds;
  final ValueChanged<String>? onToggleFavorite;
  final ValueChanged<NutritionFood>? onSaveCustomFood;
  final NutritionEstimator? estimator;
  final bool isAiModelReady;
  final VoidCallback? onOpenAiModelManager;

  @override
  State<ManualFoodAddSheet> createState() => _ManualFoodAddSheetState();
}

class _ManualFoodAddSheetState extends State<ManualFoodAddSheet> {
  late MealType _selectedMealType;
  NutritionFood? _selectedFood;
  bool _isCustomMode = false;
  bool _saveToCatalog = true;
  bool _isEstimating = false;
  NutritionEstimate? _lastEstimate;
  late Set<String> _favoriteIds;
  String? _validationError;

  late final NutritionEstimator _estimator;
  late final TextEditingController _searchController;
  late final TextEditingController _gramsController;
  late final TextEditingController _customNameController;
  late final TextEditingController _customKcalController;
  late final TextEditingController _customProteinController;
  late final TextEditingController _customCarbsController;
  late final TextEditingController _customFatController;

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.initialMealType;
    _favoriteIds = widget.favoriteFoodIds.toSet();
    _estimator =
        widget.estimator ?? HybridNutritionEstimator(catalog: widget.catalog);
    _searchController = TextEditingController();
    _gramsController = TextEditingController(text: '100');
    _customNameController = TextEditingController();
    _customKcalController = TextEditingController();
    _customProteinController = TextEditingController();
    _customCarbsController = TextEditingController();
    _customFatController = TextEditingController();

    if (widget.catalog.foods.isNotEmpty) {
      _selectedFood = widget.catalog.foods.first;
      _gramsController.text = _formatNumber(_selectedFood!.defaultServingGrams);
    } else {
      _isCustomMode = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _gramsController.dispose();
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

  void _selectFood(NutritionFood food) {
    setState(() {
      _selectedFood = food;
      _gramsController.text = _formatNumber(food.defaultServingGrams);
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

  bool _looksLikeMealDescription(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(
      r'(\d+\s*(?:kg|g|gr|gram|grams|ml|l|x)\b|\s(?:and|with|en|met|\+|&)\s|,)',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  Future<void> _estimateQueryWithAi(String query) async {
    setState(() {
      _isCustomMode = true;
      _validationError = null;
      _customNameController.text = query.trim();
      _gramsController.clear();
      _customKcalController.clear();
      _customProteinController.clear();
      _customCarbsController.clear();
      _customFatController.clear();
      _lastEstimate = null;
    });
    await _runAutoFill();
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

  void _confirm() {
    final grams = _parsePositiveDouble(_gramsController.text);
    if (grams == null) {
      setState(() {
        _validationError = 'Enter a serving size greater than 0 g.';
      });
      return;
    }

    final loggedAt = _resolveLoggedAt();
    if (_isCustomMode) {
      final name = _customNameController.text.trim();
      if (name.isEmpty) {
        setState(() {
          _validationError = 'Enter a food name.';
        });
        return;
      }
      final kcal = double.tryParse(
        _customKcalController.text.trim().replaceAll(',', '.'),
      );
      if (kcal == null || !kcal.isFinite || kcal < 0) {
        setState(() {
          _validationError = 'Enter valid calories (0 or greater).';
        });
        return;
      }
      final protein = _parseNonNegativeOrZero(_customProteinController.text);
      final carbs = _parseNonNegativeOrZero(_customCarbsController.text);
      final fat = _parseNonNegativeOrZero(_customFatController.text);
      String? customFoodId;
      if (_saveToCatalog && widget.onSaveCustomFood != null) {
        final slug = name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');
        customFoodId =
            'custom_${slug.isEmpty ? 'food' : slug}_${DateTime.now().millisecondsSinceEpoch}';
        final factor = 100.0 / grams;
        widget.onSaveCustomFood!(
          NutritionFood(
            id: customFoodId,
            name: name,
            category: 'custom',
            kcalPer100g: kcal * factor,
            proteinPer100g: protein * factor,
            carbsPer100g: carbs * factor,
            fatPer100g: fat * factor,
            defaultServingGrams: grams,
            servingLabel: '${grams.round()} g',
          ),
        );
      }
      Navigator.of(context).pop(
        MealLog.create(
          foodName: name,
          foodId: customFoodId,
          mealType: _selectedMealType,
          servingGrams: grams,
          kcal: kcal,
          proteinGrams: protein,
          carbsGrams: carbs,
          fatGrams: fat,
          loggedAt: loggedAt,
        ),
      );
      return;
    }

    final selected = _selectedFood;
    if (selected == null) {
      setState(() {
        _validationError = 'Select a food from the catalog or use Custom.';
      });
      return;
    }

    Navigator.of(context).pop(
      MealLog.fromNutritionFood(
        food: selected,
        mealType: _selectedMealType,
        servingGrams: grams,
        loggedAt: loggedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final results = widget.catalog.search(_searchController.text, limit: 25);
    final favoriteFoods = _favoriteIds
        .map(widget.catalog.findById)
        .whereType<NutritionFood>()
        .toList();
    final recentFoods = widget.recentFoodIds
        .where((id) => !_favoriteIds.contains(id))
        .map(widget.catalog.findById)
        .whereType<NutritionFood>()
        .toList();
    final grams = _parsePositiveDouble(_gramsController.text) ?? 0.0;
    final selectedMacros = _selectedFood?.macrosForGrams(grams);

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Add Food Manually',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.menu_book_rounded),
                    label: Text('Catalog'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.edit_note_rounded),
                    label: Text('Custom'),
                  ),
                ],
                selected: <bool>{_isCustomMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _isCustomMode = selection.first;
                    _validationError = null;
                    if (_isCustomMode && _gramsController.text.trim().isEmpty) {
                      _gramsController.text = '100';
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              if (!_isCustomMode) ...<Widget>[
                if (favoriteFoods.isNotEmpty) ...<Widget>[
                  Text(
                    'Favorites',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: favoriteFoods
                          .map(
                            (food) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                avatar: const Icon(Icons.star_rounded, size: 16),
                                label: Text(food.name),
                                onPressed: () => _selectFood(food),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (recentFoods.isNotEmpty) ...<Widget>[
                  Text(
                    'Recent',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: recentFoods
                          .map(
                            (food) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                avatar: const Icon(Icons.history_rounded, size: 16),
                                label: Text(food.name),
                                onPressed: () => _selectFood(food),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search foods (e.g. oatmeal, salmon, rice)...',
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
                if (_searchController.text.trim().isNotEmpty &&
                    (results.isEmpty ||
                        _looksLikeMealDescription(_searchController.text))) ...<Widget>[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _estimateQueryWithAi(_searchController.text),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        'Estimate "${_searchController.text.trim()}" with AI',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: results.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No matching foods found.'),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: results.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final food = results[index];
                              final isSelected = _selectedFood?.id == food.id;
                              final isFavorite = _favoriteIds.contains(food.id);
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                title: Text(food.name),
                                subtitle: Text(
                                  '${food.servingLabel} · '
                                  '${food.defaultServingMacros.kcal.round()} kcal',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (widget.onToggleFavorite != null &&
                                        food.id.isNotEmpty)
                                      IconButton(
                                        tooltip: isFavorite
                                            ? 'Remove favorite'
                                            : 'Add favorite',
                                        icon: Icon(
                                          isFavorite
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                          color: isFavorite
                                              ? colorScheme.primary
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            if (isFavorite) {
                                              _favoriteIds.remove(food.id);
                                            } else {
                                              _favoriteIds.add(food.id);
                                            }
                                          });
                                          widget.onToggleFavorite!(food.id);
                                        },
                                      ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: colorScheme.primary,
                                      ),
                                  ],
                                ),
                                onTap: () => _selectFood(food),
                              );
                            },
                          ),
                  ),
                ),
                if (_selectedFood != null && selectedMacros != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
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
                                _selectedFood!.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${selectedMacros.kcal.round()} kcal',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Protein ${selectedMacros.proteinGrams.toStringAsFixed(1)} g · '
                          'Carbs ${selectedMacros.carbsGrams.toStringAsFixed(1)} g · '
                          'Fat ${selectedMacros.fatGrams.toStringAsFixed(1)} g',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
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
                  onChanged: (_) => setState(() => _validationError = null),
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
                      label: Text(_isEstimating ? 'Estimating...' : 'Auto-fill'),
                    ),
                    if (_lastEstimate != null) ...<Widget>[
                      const SizedBox(width: 10),
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
                if (widget.onSaveCustomFood != null) ...<Widget>[
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save to my foods'),
                    subtitle: const Text('Reuse this food in future searches'),
                    value: _saveToCatalog,
                    onChanged: (value) => setState(() => _saveToCatalog = value),
                  ),
                ],
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
              FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Meal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
