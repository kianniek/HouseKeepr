import 'package:flutter/material.dart';

import '../models/body_measurement.dart';
import '../models/weigh_in.dart';
import '../state/open_gym_controller.dart';
import 'progress_photos_screen.dart';

/// Local-first bodyweight weigh-ins and body measurements screen.
class MeasurementsScreen extends StatelessWidget {
  const MeasurementsScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  String _todayIso() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  Future<void> _addWeighIn(BuildContext context) async {
    final weightCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final saved = await showDialog<WeighIn>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Weigh-In'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Weight (${controller.preferences.weightUnit})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final w = double.tryParse(weightCtrl.text.replaceAll(',', '.'));
              if (w == null || w <= 0) return;
              Navigator.of(dialogContext).pop(
                WeighIn.create(
                  date: _todayIso(),
                  weightKg: w,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != null) {
      await controller.saveWeighIn(saved);
    }
  }

  Future<void> _addMeasurement(BuildContext context) async {
    final waistCtrl = TextEditingController();
    final chestCtrl = TextEditingController();
    final armsCtrl = TextEditingController();
    final bfCtrl = TextEditingController();
    final hipsCtrl = TextEditingController();
    final thighsCtrl = TextEditingController();
    final calvesCtrl = TextEditingController();
    final bpSysCtrl = TextEditingController();
    final bpDiaCtrl = TextEditingController();
    final pulseCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final saved = await showDialog<BodyMeasurement>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Measurements'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: bfCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Body Fat (%)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: waistCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Waist (cm)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: chestCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Chest (cm)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: armsCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Arms (cm)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('More metrics'),
                children: <Widget>[
                  const SizedBox(height: 6),
                  TextField(
                    controller: hipsCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Hips (cm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: thighsCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Thighs (cm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: calvesCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Calves (cm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: bpSysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'BP Sys',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: bpDiaCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'BP Dia',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pulseCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Resting Pulse (bpm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              double? parse(TextEditingController c) =>
                  double.tryParse(c.text.trim().replaceAll(',', '.'));
              int? parseInt(TextEditingController c) =>
                  int.tryParse(c.text.trim());
              final bf = parse(bfCtrl);
              final waist = parse(waistCtrl);
              final chest = parse(chestCtrl);
              final arms = parse(armsCtrl);
              final hips = parse(hipsCtrl);
              final thighs = parse(thighsCtrl);
              final calves = parse(calvesCtrl);
              final bpSys = parseInt(bpSysCtrl);
              final bpDia = parseInt(bpDiaCtrl);
              final pulse = parseInt(pulseCtrl);
              final note = noteCtrl.text.trim();
              if (bf == null &&
                  waist == null &&
                  chest == null &&
                  arms == null &&
                  hips == null &&
                  thighs == null &&
                  calves == null &&
                  bpSys == null &&
                  bpDia == null &&
                  pulse == null &&
                  note.isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(
                BodyMeasurement.create(
                  date: _todayIso(),
                  bodyFatPct: bf,
                  chestCm: chest,
                  waistCm: waist,
                  hipsCm: hips,
                  armsCm: arms,
                  thighsCm: thighs,
                  calvesCm: calves,
                  bpSys: bpSys,
                  bpDia: bpDia,
                  pulse: pulse,
                  note: note.isEmpty ? null : note,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != null) {
      await controller.saveMeasurement(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final weighIns = controller.weighIns;
        final measurements = controller.measurements;
        final unit = controller.preferences.weightUnit;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _addWeighIn(context),
                    icon: const Icon(Icons.monitor_weight_outlined),
                    label: const Text('Log Weight'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _addMeasurement(context),
                    icon: const Icon(Icons.straighten),
                    label: const Text('Measurements'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ProgressPhotosScreen(controller: controller),
                ),
              ),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                'Progress Photos (${controller.progressPhotos.length})',
              ),
            ),
            const SizedBox(height: 20),
            Text('Weigh-Ins', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (weighIns.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No weigh-ins logged yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...weighIns.map(
                (w) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${w.weightKg.toStringAsFixed(1)} $unit'),
                    subtitle: Text(
                      w.note != null ? '${w.date} • ${w.note}' : w.date,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => controller.deleteWeighIn(w.id),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('Body Measurements', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (measurements.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No body measurements logged yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...measurements.map((m) {
                final parts = <String>[
                  if (m.bodyFatPct != null) 'BF ${m.bodyFatPct}%',
                  if (m.waistCm != null) 'Waist ${m.waistCm} cm',
                  if (m.chestCm != null) 'Chest ${m.chestCm} cm',
                  if (m.hipsCm != null) 'Hips ${m.hipsCm} cm',
                  if (m.armsCm != null) 'Arms ${m.armsCm} cm',
                  if (m.thighsCm != null) 'Thighs ${m.thighsCm} cm',
                  if (m.calvesCm != null) 'Calves ${m.calvesCm} cm',
                  if (m.bpSys != null && m.bpDia != null)
                    'BP ${m.bpSys}/${m.bpDia}',
                  if (m.pulse != null) 'Pulse ${m.pulse} bpm',
                  if (m.note != null && m.note!.isNotEmpty) m.note!,
                ];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(m.date),
                    subtitle: Text(parts.join(' • ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => controller.deleteMeasurement(m.id),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
