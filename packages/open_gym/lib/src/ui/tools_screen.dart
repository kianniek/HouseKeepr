import 'package:flutter/material.dart';

import '../state/open_gym_controller.dart';
import '../state/personal_record_service.dart';

/// Strength calculators: Barbell Plate Loader, 1RM Estimator, and Warm-up Ramp.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final _plateTargetCtrl = TextEditingController(text: '100');
  final _oneRmWeightCtrl = TextEditingController(text: '80');
  final _oneRmRepsCtrl = TextEditingController(text: '5');
  final _dotsBwCtrl = TextEditingController(text: '80');
  final _dotsTotalCtrl = TextEditingController(text: '450');
  final _heightCmCtrl = TextEditingController(text: '178');
  final _bodyFatCtrl = TextEditingController(text: '15');
  bool _isMale = true;

  @override
  void dispose() {
    _plateTargetCtrl.dispose();
    _oneRmWeightCtrl.dispose();
    _oneRmRepsCtrl.dispose();
    _dotsBwCtrl.dispose();
    _dotsTotalCtrl.dispose();
    _heightCmCtrl.dispose();
    _bodyFatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = widget.controller.preferences.weightUnit;
    final barWeight = widget.controller.preferences.barWeightKg;

    final target = double.tryParse(_plateTargetCtrl.text) ?? 0;
    final plates = widget.controller.analytics.calculatePlatesPerSide(
      targetWeight: target,
      barWeight: barWeight,
    );
    final warmup = widget.controller.analytics.generateWarmupRamp(
      workingWeight: target,
      barWeight: barWeight,
    );

    final rmWeight = double.tryParse(_oneRmWeightCtrl.text) ?? 0;
    final rmReps = int.tryParse(_oneRmRepsCtrl.text) ?? 0;
    final e1rm = OneRmEstimator.estimate(
      rmWeight,
      rmReps,
      formula: widget.controller.preferences.oneRmFormula,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Gym Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Barbell Plate Loader & Warm-Up',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _plateTargetCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Target Weight ($unit) • Bar $barWeight $unit',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    plates.isEmpty
                        ? 'Bar only (no plates needed)'
                        : 'Per side: ${plates.entries.map((e) => '${e.value} × ${e.key}$unit').join(', ')}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Text('Warm-up Ramp:', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: warmup
                        .map(
                          (w) => Chip(
                            label: Text('${w.weight} $unit × ${w.reps}'),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('1-Rep Max Estimator',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _oneRmWeightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Weight ($unit)',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _oneRmRepsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Reps (1–12)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    e1rm == null
                        ? 'Enter weight and 1–12 reps'
                        : 'Estimated 1RM (${OneRmEstimator.displayName(widget.controller.preferences.oneRmFormula)}): '
                            '${e1rm.toStringAsFixed(1)} $unit',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildBodyAndDotsCard(theme, unit),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyAndDotsCard(ThemeData theme, String unit) {
    final bwInput =
        double.tryParse(_dotsBwCtrl.text.trim().replaceAll(',', '.'));
    final totalInput =
        double.tryParse(_dotsTotalCtrl.text.trim().replaceAll(',', '.'));
    final heightCm =
        double.tryParse(_heightCmCtrl.text.trim().replaceAll(',', '.'));
    final bfPct =
        double.tryParse(_bodyFatCtrl.text.trim().replaceAll(',', '.'));

    final toKg = unit == 'lbs' ? 0.45359237 : 1.0;
    final bwKg = (bwInput != null && bwInput > 0) ? bwInput * toKg : null;
    final totalKg =
        (totalInput != null && totalInput > 0) ? totalInput * toKg : null;

    double? dots;
    if (bwKg != null && totalKg != null) {
      final bwClamped = _isMale
          ? bwKg.clamp(40.0, 210.0)
          : bwKg.clamp(40.0, 150.0);
      final coeffs = _isMale
          ? const <double>[
              -307.75076,
              24.0900756,
              -0.1918759221,
              0.0007391293,
              -0.000001093,
            ]
          : const <double>[
              -57.96288,
              13.6175032,
              -0.1126655495,
              0.0005158568,
              -0.0000010706,
            ];
      final bw2 = bwClamped * bwClamped;
      final bw3 = bw2 * bwClamped;
      final bw4 = bw3 * bwClamped;
      final denom = coeffs[0] +
          coeffs[1] * bwClamped +
          coeffs[2] * bw2 +
          coeffs[3] * bw3 +
          coeffs[4] * bw4;
      if (denom > 0) {
        dots = totalKg * 500.0 / denom;
      }
    }

    double? bmi;
    double? ffmiNorm;
    if (bwKg != null && heightCm != null && heightCm > 50) {
      final m = heightCm / 100.0;
      bmi = bwKg / (m * m);
      if (bfPct != null && bfPct >= 1 && bfPct <= 70) {
        final leanKg = bwKg * (1.0 - bfPct / 100.0);
        ffmiNorm = leanKg / (m * m) + 6.1 * (1.8 - m);
      }
    }

    String bmiLabel(double value) {
      if (value < 18.5) return 'Underweight';
      if (value < 25.0) return 'Normal';
      if (value < 30.0) return 'Overweight';
      return 'Obese';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'DOTS, BMI & FFMI',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: true, label: Text('Male')),
            ButtonSegment<bool>(value: false, label: Text('Female')),
          ],
          selected: <bool>{_isMale},
          onSelectionChanged: (sel) => setState(() => _isMale = sel.first),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _dotsBwCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Bodyweight ($unit)',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _dotsTotalCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'SBD Total ($unit)',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _heightCmCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _bodyFatCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Body Fat (%)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          dots == null ? 'DOTS: —' : 'DOTS Score: ${dots.toStringAsFixed(1)}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          bmi == null
              ? 'BMI: —'
              : 'BMI: ${bmi.toStringAsFixed(1)} (${bmiLabel(bmi)})'
                  '${ffmiNorm != null ? ' • Norm FFMI: ${ffmiNorm.toStringAsFixed(1)}' : ''}',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
