import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:housekeepr/models/coffee_recipe.dart';
import 'package:housekeepr/services/widget_service.dart';

class CoffeePickerPage extends StatefulWidget {
  final String? recipeId;

  const CoffeePickerPage({super.key, this.recipeId});

  @override
  State<CoffeePickerPage> createState() => _CoffeePickerPageState();
}

class _CoffeePickerPageState extends State<CoffeePickerPage> {
  late final List<CoffeeRecipe> _recipes;
  late CoffeeRecipe _recipe;
  bool _spinning = false;
  int _yield = 240;
  Timer? _timer;
  int? _activeStep;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _recipes = [...CoffeeRegistry.recipes];
    _recipe = CoffeeRegistry.byId(widget.recipeId ?? 'latte');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _spin() {
    if (_spinning) return;
    setState(() => _spinning = true);
    Future<void>.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      setState(() {
        _recipe = _recipes[Random().nextInt(_recipes.length)];
        _spinning = false;
        _yield = _recipe.defaultYieldMl;
      });
      WidgetService.instance.updateCoffeeWidget(_recipe);
    });
  }

  Future<void> _createRecipe() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create coffee recipe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Recipe name'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Add recipe'),
          ),
        ],
      ),
    );
    final name = result;
    final description = descriptionController.text.trim();
    nameController.dispose();
    descriptionController.dispose();
    if (!mounted || name == null || name.isEmpty) return;
    final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final recipe = CoffeeRecipe(
      id: id,
      displayName: name,
      description: description.isEmpty
          ? 'A custom coffee recipe.'
          : description,
      layers: CoffeeRegistry.recipes.first.layers,
      brewSteps: const [],
    );
    setState(() {
      _recipes.add(recipe);
      _recipe = recipe;
    });
    await WidgetService.instance.updateCoffeeWidget(recipe);
  }

  void _startTimer(BrewStep step) {
    _timer?.cancel();
    setState(() {
      _activeStep = step.index;
      _remaining = step.durationSeconds ?? 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remaining <= 1) {
        timer.cancel();
        if (mounted) setState(() => _remaining = 0);
        return;
      }
      setState(() => _remaining--);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1EF),
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
          _PickerCard(recipe: _recipe, spinning: _spinning, onSpin: _spin),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _createRecipe,
              icon: const Icon(Icons.add),
              label: const Text('Create recipe'),
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

class _PickerCard extends StatelessWidget {
  final CoffeeRecipe recipe;
  final bool spinning;
  final VoidCallback onSpin;

  const _PickerCard({
    required this.recipe,
    required this.spinning,
    required this.onSpin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1B18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: spinning
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD7CCC8)),
              )
            : Row(
                key: ValueKey(recipe.id),
                children: [
                  Expanded(child: _Wheel(onSpin: onSpin)),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          recipe.displayName,
                          style: const TextStyle(
                            color: Color(0xFFFFF3E0),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 92,
                          width: 110,
                          child: _CoffeeCup(recipe: recipe),
                        ),
                        const SizedBox(height: 14),
                        _Legend(recipe: recipe),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  final VoidCallback onSpin;
  const _Wheel({required this.onSpin});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text(
        'What to brew?',
        style: TextStyle(color: Color(0xFFA1887F), fontSize: 13),
      ),
      const Text('▼', style: TextStyle(color: Color(0xFFD7CCC8), fontSize: 12)),
      const SizedBox(height: 2),
      GestureDetector(
        onTap: onSpin,
        child: const SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(painter: _WheelPainter()),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: onSpin,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFD7CCC8),
          foregroundColor: const Color(0xFF1F1B18),
        ),
        child: const Text(
          'TAP TO SPIN',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final colors = [
      const Color(0xFF6D4C41),
      const Color(0xFFE0CFC5),
      const Color(0xFF3E2723),
      const Color(0xFF8D6E63),
      const Color(0xFFD7CCC8),
      const Color(0xFF5D4037),
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
      Paint()..color = const Color(0xFF1F1B18),
    );
    canvas.drawCircle(
      center,
      radius * .12,
      Paint()..color = const Color(0xFFFFF3E0),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoffeeCup extends StatelessWidget {
  final CoffeeRecipe recipe;
  const _CoffeeCup({required this.recipe});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CupPainter(recipe));
}

class _CupPainter extends CustomPainter {
  final CoffeeRecipe recipe;
  const _CupPainter(this.recipe);

  @override
  void paint(Canvas canvas, Size size) {
    final cup = Rect.fromLTWH(8, 4, size.width * .65, size.height - 8);
    final total = recipe.layers.fold<double>(
      0,
      (sum, layer) => sum + layer.partsRatio,
    );
    var top = cup.bottom;
    for (final layer in recipe.layers) {
      final height = cup.height * layer.partsRatio / total;
      canvas.drawRect(
        Rect.fromLTRB(cup.left, top - height, cup.right, top),
        Paint()..color = Color(layer.color),
      );
      top -= height;
    }
    final outline = Paint()
      ..color = const Color(0xFFFFFDF9)
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
      oldDelegate.recipe.id != recipe.id;
}

class _Legend extends StatelessWidget {
  final CoffeeRecipe recipe;
  const _Legend({required this.recipe});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 3,
    alignment: WrapAlignment.center,
    children: recipe.layers
        .map(
          (layer) => Text(
            '● ${layer.unitLabel}',
            style: const TextStyle(
              color: Color(0xFFFFF3E0),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
        .toList(),
  );
}

class _YieldControl extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _YieldControl({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text(
        'Serving yield',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const Spacer(),
      IconButton(
        onPressed: () => onChanged(value - 30),
        icon: const Icon(Icons.remove_circle_outline),
      ),
      Text('$value ml', style: const TextStyle(fontWeight: FontWeight.w800)),
      IconButton(
        onPressed: () => onChanged(value + 30),
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
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
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(child: Text('${step.index}')),
      title: Text(
        step.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(step.description),
      trailing: onStart == null
          ? null
          : IconButton(
              onPressed: onStart,
              icon: Text(active && remaining > 0 ? '$remaining' : '▶'),
            ),
    ),
  );
}
