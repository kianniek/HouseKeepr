import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:housekeepr/models/coffee_recipe.dart';
import 'package:housekeepr/services/coffee_firebase_service.dart';
import 'package:housekeepr/services/widget_service.dart';
import 'package:housekeepr/ui/common/widgets/color_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _spinDuration = Duration(milliseconds: 550);

class CoffeePickerPage extends StatefulWidget {
  final String? recipeId;
  final String? householdId;

  const CoffeePickerPage({super.key, this.recipeId, this.householdId});

  @override
  State<CoffeePickerPage> createState() => _CoffeePickerPageState();
}

class _CoffeePickerPageState extends State<CoffeePickerPage> {
  static const _savedRecipesKey = 'coffee_custom_recipes';
  late final List<CoffeeRecipe> _recipes = [...CoffeeRegistry.recipes];
  CoffeeFirebaseService? get _firebaseService => widget.householdId == null
      ? null
      : CoffeeFirebaseService(householdId: widget.householdId!);
  final Set<String> _customRecipeIds = {};
  late CoffeeRecipe _recipe;
  bool _spinning = false;
  int _yield = 240;
  Timer? _timer;
  int? _activeStep;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _recipe = CoffeeRegistry.byId(widget.recipeId ?? 'latte');
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedRecipesKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final saved = decoded
              .whereType<Map>()
              .map(
                (map) => CoffeeRecipe.fromMap(Map<String, dynamic>.from(map)),
              )
              .where(
                (recipe) => recipe.id.isNotEmpty && recipe.layers.isNotEmpty,
              );
          _mergeRecipes(saved);
        }
      } on FormatException {
        debugPrint('CoffeePickerPage: saved recipes were invalid JSON');
      }
    }

    try {
      final firebaseService = _firebaseService;
      if (firebaseService != null) {
        final cloudRecipes = await firebaseService.getCustomRecipes();
        _mergeRecipes(cloudRecipes);
        await _saveCustomRecipes();
      }
      if (mounted) {
        await WidgetService.instance.updateCoffeeWidget(
          _recipe,
          availableRecipes: _recipes,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('CoffeePickerPage: cloud recipes unavailable: $error');
      debugPrint('$stackTrace');
    }
  }

  void _mergeRecipes(Iterable<CoffeeRecipe> recipes) {
    if (!mounted) return;
    setState(() {
      for (final recipe in recipes) {
        _customRecipeIds.add(recipe.id);
        final index = _recipes.indexWhere((item) => item.id == recipe.id);
        if (index == -1) {
          _recipes.add(recipe);
        } else {
          _recipes[index] = recipe;
        }
        if (recipe.id == widget.recipeId) _recipe = recipe;
      }
      _yield = _recipe.defaultYieldMl;
    });
  }

  Future<void> _saveCustomRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final recipes = _recipes
        .where((recipe) => _customRecipeIds.contains(recipe.id))
        .map((recipe) => recipe.toMap())
        .toList();
    await prefs.setString(_savedRecipesKey, jsonEncode(recipes));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _spin() {
    if (_spinning) return;
    setState(() => _spinning = true);
    Future<void>.delayed(_spinDuration, () {
      if (!mounted) return;
      setState(() {
        _recipe = _recipes[Random().nextInt(_recipes.length)];
        _spinning = false;
        _yield = _recipe.defaultYieldMl;
      });
      WidgetService.instance.updateCoffeeWidget(
        _recipe,
        availableRecipes: _recipes,
      );
    });
  }

  Future<void> _chooseRecipe() async {
    final selected = await showModalBottomSheet<CoffeeRecipe>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Coffee recipes',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ..._recipes.map(
              (recipe) => ListTile(
                leading: Icon(
                  recipe.id == _recipe.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(recipe.displayName),
                subtitle: Text(recipe.description),
                onTap: () => Navigator.pop(context, recipe),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _recipe = selected;
      _yield = selected.defaultYieldMl;
    });
    await WidgetService.instance.updateCoffeeWidget(
      selected,
      availableRecipes: _recipes,
    );
  }

  Future<void> _editRecipe() async {
    final result = await showDialog<_RecipeDraft>(
      context: context,
      builder: (context) => _RecipeEditorDialog(
        title: 'Edit ${_recipe.displayName}',
        initialName: _recipe.displayName,
        initialDescription: _recipe.description,
        initialYield: _recipe.defaultYieldMl,
        initialLayers: _recipe.layers,
        initialBrewSteps: _recipe.brewSteps,
        showYield: true,
      ),
    );
    if (!mounted || result == null) return;

    final updated = CoffeeRecipe(
      id: _recipe.id,
      displayName: result.name,
      description: result.description,
      layers: result.layers,
      brewSteps: result.brewSteps,
      defaultYieldMl: result.defaultYield,
    );
    final index = _recipes.indexWhere((recipe) => recipe.id == _recipe.id);
    setState(() {
      _recipes[index] = updated;
      _customRecipeIds.add(updated.id);
      _recipe = updated;
      _yield = updated.defaultYieldMl;
    });
    try {
      await _firebaseService?.saveRecipe(updated);
    } catch (error, stackTrace) {
      debugPrint('CoffeePickerPage: failed to save edited recipe: $error');
      debugPrint('$stackTrace');
    }
    await WidgetService.instance.updateCoffeeWidget(
      updated,
      availableRecipes: _recipes,
    );
    await _saveCustomRecipes();
  }

  Future<void> _createRecipe() async {
    final result = await showDialog<_RecipeDraft>(
      context: context,
      builder: (context) => const _RecipeEditorDialog(
        title: 'Create coffee recipe',
        showYield: true,
      ),
    );
    if (!mounted || result == null || result.name.isEmpty) return;
    final name = result.name;
    var id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    id = id.replaceAll(RegExp(r'^-+|-+$'), '');
    if (id.isEmpty) {
      id = 'custom-coffee';
    }
    if (_recipes.any((recipe) => recipe.id == id)) {
      id = '$id-${DateTime.now().millisecondsSinceEpoch}';
    }
    final recipe = CoffeeRecipe(
      id: id,
      displayName: name,
      description: result.description.isEmpty
          ? 'A custom coffee recipe.'
          : result.description,
      layers: result.layers,
      brewSteps: result.brewSteps,
      defaultYieldMl: result.defaultYield,
    );
    setState(() {
      _recipes.add(recipe);
      _customRecipeIds.add(recipe.id);
      _recipe = recipe;
      _yield = recipe.defaultYieldMl;
    });
    try {
      await _firebaseService?.saveRecipe(recipe);
    } catch (error, stackTrace) {
      debugPrint('CoffeePickerPage: failed to save new recipe: $error');
      debugPrint('$stackTrace');
    }
    await WidgetService.instance.updateCoffeeWidget(
      recipe,
      availableRecipes: _recipes,
    );
    await _saveCustomRecipes();
  }

  void _startTimer(BrewStep step) {
    _timer?.cancel();
    setState(() {
      _activeStep = step.index;
      _remaining = step.durationSeconds ?? 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remaining <= 0) {
        timer.cancel();
        if (mounted) setState(() => _remaining = 0);
        return;
      }
      setState(
        () => _remaining = (_remaining - 1).clamp(0, step.durationSeconds ?? 0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Coffee picker'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Spin again',
            onPressed: _spin,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _PickerCard(
            recipe: _recipe,
            yieldMl: _yield,
            spinning: _spinning,
            onSpin: _spin,
            showResult: widget.recipeId != null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _chooseRecipe,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('All recipes'),
              ),
              TextButton.icon(
                onPressed: _createRecipe,
                icon: const Icon(Icons.add),
                label: const Text('Create recipe'),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _editRecipe,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit recipe'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _recipe.displayName,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _recipe.description,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),
          _YieldControl(
            value: _yield,
            onChanged: (value) =>
                setState(() => _yield = value.clamp(120, 480)),
          ),
          const SizedBox(height: 24),
          Text(
            'Brew guide',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_recipe.brewSteps.isEmpty)
            const Text(
              'A quick pour-and-serve recipe. Adjust the yield above as needed.',
            )
          else
            ..._recipe.brewSteps.map(
              (step) => _StepTile(
                step: step,
                active: _activeStep == step.index,
                remaining: _remaining,
                onStart: step.durationSeconds == null
                    ? null
                    : () => _startTimer(step),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecipeDraft {
  final String name;
  final String description;
  final int defaultYield;
  final List<CoffeeIngredient> layers;
  final List<BrewStep> brewSteps;

  const _RecipeDraft({
    required this.name,
    required this.description,
    required this.defaultYield,
    required this.layers,
    required this.brewSteps,
  });
}

class _RecipeEditorDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final String initialDescription;
  final int initialYield;
  final bool showYield;
  final List<CoffeeIngredient> initialLayers;
  final List<BrewStep> initialBrewSteps;

  const _RecipeEditorDialog({
    required this.title,
    this.initialName = '',
    this.initialDescription = '',
    this.initialYield = 240,
    this.showYield = false,
    this.initialLayers = const [],
    this.initialBrewSteps = const [],
  });

  @override
  State<_RecipeEditorDialog> createState() => _RecipeEditorDialogState();
}

class _RecipeEditorDialogState extends State<_RecipeEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _yieldController;
  late final List<_IngredientDraft> _layers;
  late final List<_StepDraft> _steps;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _yieldController = TextEditingController(text: '${widget.initialYield}');
    _layers = widget.initialLayers
        .map(_IngredientDraft.fromIngredient)
        .toList();
    if (_layers.isEmpty) {
      _layers.add(_IngredientDraft(name: 'Espresso', ratio: 1));
    }
    _steps = widget.initialBrewSteps.map(_StepDraft.fromStep).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _yieldController.dispose();
    for (final layer in _layers) {
      layer.dispose();
    }
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final defaultYield = int.tryParse(_yieldController.text.trim());
    final layers = _layers
        .where(
          (layer) =>
              layer.nameController.text.trim().isNotEmpty && layer.ratio > 0,
        )
        .toList();
    final steps = _steps
        .where((step) => step.titleController.text.trim().isNotEmpty)
        .map(
          (step) => BrewStep(
            index: _steps.indexOf(step) + 1,
            title: step.titleController.text.trim(),
            description: step.descriptionController.text.trim(),
            durationSeconds: step.durationSeconds,
            targetTemperatureCelsius: step.targetTemperatureCelsius,
          ),
        )
        .toList();
    if (name.isEmpty ||
        defaultYield == null ||
        defaultYield <= 0 ||
        layers.isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      _RecipeDraft(
        name: name,
        description: description,
        defaultYield: defaultYield,
        layers: layers
            .map(
              (layer) => CoffeeIngredient(
                id: layer.nameController.text.trim().toLowerCase().replaceAll(
                  RegExp(r'[^a-z0-9]+'),
                  '-',
                ),
                name: layer.nameController.text.trim(),
                color: layer.colorValue,
                partsRatio: layer.ratio,
                unitLabel:
                    '${layer.ratio}x ${layer.nameController.text.trim()}',
              ),
            )
            .toList(),
        brewSteps: steps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Recipe name'),
            ),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            if (widget.showYield)
              TextField(
                controller: _yieldController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Default yield (ml)',
                ),
              ),
            const SizedBox(height: 12),
            ..._layers.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: entry.value.nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ingredient',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        controller: entry.value.ratioController,
                        decoration: const InputDecoration(labelText: 'Ratio'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Fixed-size color box matching text field height (~48-56px)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: ValueListenableBuilder<Color>(
                        valueListenable: entry.value.colorController,
                        builder: (context, color, child) => InkWell(
                          onTap: () async {
                            final pickedColor = await showRestrictedColorPicker(
                              context,
                              color: color,
                              availableColors: CoffeeIngredient.coffeePalette,
                            );

                            if (pickedColor != null) {
                              entry.value.overrideColor(pickedColor);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _layers.length == 1
                          ? null
                          : () => setState(() => _layers.removeAt(entry.key)),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(
                  () => _layers.add(
                    _IngredientDraft(name: 'Ingredient', ratio: 1),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add ingredient'),
              ),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Text(
                  'Brew steps',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Add brew step',
                  onPressed: () => setState(() {
                    _steps.add(_StepDraft(title: 'New step'));
                  }),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (_steps.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Add steps to create a brew guide.'),
              )
            else
              ..._steps.asMap().entries.map(
                (entry) => _StepEditor(
                  number: entry.key + 1,
                  step: entry.value,
                  onRemove: () => setState(() {
                    final removed = _steps.removeAt(entry.key);
                    removed.dispose();
                  }),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.showYield ? 'Save' : 'Add recipe'),
        ),
      ],
    );
  }
}

class _IngredientDraft {
  final TextEditingController nameController;
  final TextEditingController ratioController;
  final ValueNotifier<Color> colorController;
  bool colorOverridden = false;

  _IngredientDraft({
    required String name,
    required double ratio,
    int color = 0xFF9E9E9E,
  }) : nameController = TextEditingController(text: name),
       ratioController = TextEditingController(text: '$ratio'),
       colorController = ValueNotifier<Color>(Color(color)) {
    nameController.addListener(_updateColorForName);
  }

  factory _IngredientDraft.fromIngredient(CoffeeIngredient ingredient) =>
      _IngredientDraft(
        name: ingredient.name,
        ratio: ingredient.partsRatio,
        color: ingredient.color,
      );

  double get ratio => double.tryParse(ratioController.text) ?? 1;

  int get colorValue => colorController.value.toARGB32();

  void overrideColor(Color color) {
    colorOverridden = true;
    colorController.value = color;
  }

  void _updateColorForName() {
    if (colorOverridden) return;
    colorController.value = CoffeeColorMapper.getColorForName(
      nameController.text,
      defaultColor: colorController.value,
    );
  }

  void dispose() {
    nameController.removeListener(_updateColorForName);
    nameController.dispose();
    ratioController.dispose();
    colorController.dispose();
  }
}

class _StepDraft {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController durationController;
  final TextEditingController temperatureController;

  _StepDraft({
    required String title,
    String description = '',
    int? durationSeconds,
    int? targetTemperatureCelsius,
  }) : titleController = TextEditingController(text: title),
       descriptionController = TextEditingController(text: description),
       durationController = TextEditingController(
         text: durationSeconds?.toString() ?? '',
       ),
       temperatureController = TextEditingController(
         text: targetTemperatureCelsius?.toString() ?? '',
       );

  factory _StepDraft.fromStep(BrewStep step) => _StepDraft(
    title: step.title,
    description: step.description,
    durationSeconds: step.durationSeconds,
    targetTemperatureCelsius: step.targetTemperatureCelsius,
  );

  int? get durationSeconds => int.tryParse(durationController.text.trim());

  int? get targetTemperatureCelsius =>
      int.tryParse(temperatureController.text.trim());

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    durationController.dispose();
    temperatureController.dispose();
  }
}

class _StepEditor extends StatelessWidget {
  final int number;
  final _StepDraft step;
  final VoidCallback onRemove;

  const _StepEditor({
    required this.number,
    required this.step,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Step $number',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Remove step',
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
            TextField(
              controller: step.titleController,
              decoration: const InputDecoration(labelText: 'Step title'),
            ),
            TextField(
              controller: step.descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: step.durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration (seconds)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: step.temperatureController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Temperature (C)',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerCard extends StatefulWidget {
  final CoffeeRecipe recipe;
  final int yieldMl;
  final bool spinning;
  final VoidCallback onSpin;
  final bool showResult;

  const _PickerCard({
    required this.recipe,
    required this.yieldMl,
    required this.spinning,
    required this.onSpin,
    required this.showResult,
  });

  @override
  State<_PickerCard> createState() => _PickerCardState();
}

class _PickerCardState extends State<_PickerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  late bool _showResult;

  @override
  void initState() {
    super.initState();
    _showResult = widget.showResult;
    _rotationController = AnimationController(
      vsync: this,
      duration: _spinDuration,
    );
    if (widget.spinning) _rotationController.forward();
  }

  @override
  void didUpdateWidget(covariant _PickerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !oldWidget.spinning) {
      _showResult = false;
      _rotationController
        ..reset()
        ..repeat();
    } else if (!widget.spinning && oldWidget.spinning) {
      _rotationController.stop();
      _showResult = true;
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: widget.spinning
            ? Center(
                key: const ValueKey('spinning'),
                child: AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) => Transform.rotate(
                    angle: _rotationController.value * 2 * pi,
                    child: child,
                  ),
                  child: CustomPaint(
                    size: const Size.square(96),
                    painter: _WheelPainter(scheme),
                  ),
                ),
              )
            : _showResult
            ? Center(
                key: ValueKey('result-${widget.recipe.id}'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.recipe.displayName,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 92,
                      width: 110,
                      child: _CoffeeCup(
                        recipe: widget.recipe,
                        yieldMl: widget.yieldMl,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Legend(recipe: widget.recipe, yieldMl: widget.yieldMl),
                  ],
                ),
              )
            : Center(
                key: const ValueKey('wheel'),
                child: _Wheel(onSpin: widget.onSpin),
              ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  final VoidCallback onSpin;
  const _Wheel({required this.onSpin});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'What to brew?',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        Text('▼', style: TextStyle(color: scheme.onSurface, fontSize: 12)),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: onSpin,
          child: SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(painter: _WheelPainter(scheme)),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onSpin,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
          ),
          child: const Text(
            'TAP TO SPIN',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final ColorScheme scheme;
  const _WheelPainter(this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final colors = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.surfaceContainerLow,
    ];
    for (var index = 0; index < colors.length; index++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 + index * pi / 3,
        pi / 3,
        true,
        Paint()..color = colors[index],
      );
    }
    canvas.drawCircle(
      center,
      radius * .35,
      Paint()..color = scheme.surfaceContainerHighest,
    );
    canvas.drawCircle(center, radius * .12, Paint()..color = scheme.onSurface);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.scheme != scheme;
}

class _CoffeeCup extends StatelessWidget {
  final CoffeeRecipe recipe;
  final int yieldMl;
  const _CoffeeCup({required this.recipe, required this.yieldMl});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CupPainter(
        recipe,
        yieldMl,
        Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _CupPainter extends CustomPainter {
  final CoffeeRecipe recipe;
  final int yieldMl;
  final Color outlineColor;
  const _CupPainter(this.recipe, this.yieldMl, this.outlineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final cup = Rect.fromLTWH(8, 4, size.width * .65, size.height - 8);
    final total = recipe.layers.fold<double>(
      0,
      (sum, layer) => sum + layer.partsRatio,
    );
    var top = cup.bottom;
    for (final layer in recipe.layers) {
      final layerYield = yieldMl * layer.partsRatio / total;
      final height = cup.height * layerYield / yieldMl;
      canvas.drawRect(
        Rect.fromLTRB(cup.left, top - height, cup.right, top),
        Paint()..color = Color(layer.color),
      );
      top -= height;
    }
    final outline = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cup, const Radius.circular(5)),
      outline,
    );
    canvas.drawArc(
      Rect.fromLTWH(
        cup.right - 2,
        size.height * .3,
        size.width * .3,
        size.height * .35,
      ),
      -pi / 2,
      pi,
      false,
      outline,
    );
  }

  @override
  bool shouldRepaint(covariant _CupPainter oldDelegate) =>
      oldDelegate.recipe.id != recipe.id ||
      oldDelegate.yieldMl != yieldMl ||
      oldDelegate.outlineColor != outlineColor;
}

class _Legend extends StatelessWidget {
  final CoffeeRecipe recipe;
  final int yieldMl;
  const _Legend({required this.recipe, required this.yieldMl});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final total = recipe.layers.fold<double>(
      0,
      (sum, layer) => sum + layer.partsRatio,
    );
    return Wrap(
      spacing: 6,
      runSpacing: 3,
      alignment: WrapAlignment.center,
      children: recipe.layers
          .map(
            (layer) => Text(
              '● ${layer.unitLabel} (${(yieldMl * layer.partsRatio / total).round()} ml)',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _YieldControl extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _YieldControl({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Serving yield',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => onChanged(value - 30),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(
          '$value ml',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        IconButton(
          onPressed: () => onChanged(value + 30),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  final BrewStep step;
  final bool active;
  final int remaining;
  final VoidCallback? onStart;
  const _StepTile({
    required this.step,
    required this.active,
    required this.remaining,
    required this.onStart,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('${step.index}')),
        title: Text(
          step.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(step.description),
        trailing: onStart == null
            ? null
            : IconButton(
                onPressed: onStart,
                icon: (active && remaining > 0)
                    ? Text('$remaining')
                    : Icon(Icons.play_arrow_outlined),
              ),
      ),
    );
  }
}
