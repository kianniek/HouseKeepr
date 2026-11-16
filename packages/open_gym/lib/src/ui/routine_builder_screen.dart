import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/workout_template.dart';
import '../state/open_gym_controller.dart';
import 'exercise_library_screen.dart';

/// Screen for creating or editing a [WorkoutTemplate] routine.
class RoutineBuilderScreen extends StatefulWidget {
  const RoutineBuilderScreen({
    super.key,
    required this.controller,
    this.existingTemplate,
  });

  final OpenGymController controller;
  final WorkoutTemplate? existingTemplate;

  @override
  State<RoutineBuilderScreen> createState() => _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends State<RoutineBuilderScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String _goal;
  late List<WorkoutTemplateEntry> _entries;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTemplate;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _goal = existing?.goal ?? 'strength';
    _entries = existing != null
        ? List<WorkoutTemplateEntry>.from(existing.entries)
        : <WorkoutTemplateEntry>[];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _addExercise() async {
    final picked = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute<Exercise>(
        builder: (_) => ExerciseLibraryScreen(
          controller: widget.controller,
          isPicker: true,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _entries.add(
        WorkoutTemplateEntry(
          exerciseId: picked.id,
          exerciseName: picked.name,
          bodyPart: picked.bodyPart,
          equipment: picked.equipment,
        ),
      );
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine name.')),
      );
      return;
    }
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise.')),
      );
      return;
    }

    final existing = widget.existingTemplate;
    final template = existing != null
        ? existing.copyWith(
            name: name,
            goal: _goal,
            description: _descCtrl.text.trim(),
            entries: _entries,
          )
        : WorkoutTemplate.create(
            name: name,
            goal: _goal,
            description: _descCtrl.text.trim(),
            entries: _entries,
          );

    await widget.controller.saveTemplate(template);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingTemplate != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Routine' : 'New Routine'),
        actions: <Widget>[
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Routine Name',
              hintText: 'e.g. Upper Body Power',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _goal,
            decoration: const InputDecoration(
              labelText: 'Goal',
              border: OutlineInputBorder(),
            ),
            items: const <String>['strength', 'hypertrophy', 'endurance']
                .map(
                  (g) => DropdownMenuItem<String>(value: g, child: Text(g)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _goal = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Exercises (${_entries.length})',
                  style: theme.textTheme.titleMedium),
              FilledButton.tonalIcon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Add Exercise'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._entries.asMap().entries.map((item) {
            final idx = item.key;
            final entry = item.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            entry.exerciseName,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => _entries.removeAt(idx)),
                        ),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _StepperField(
                            label: 'Sets',
                            value: entry.targetSets,
                            min: 1,
                            onChanged: (v) => setState(() {
                              _entries[idx] = entry.copyWith(targetSets: v);
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StepperField(
                            label: 'Reps',
                            value: entry.targetReps,
                            min: 1,
                            onChanged: (v) => setState(() {
                              _entries[idx] = entry.copyWith(targetReps: v);
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StepperField(
                            label: 'Rest (s)',
                            value: entry.restSeconds,
                            min: 15,
                            step: 15,
                            onChanged: (v) => setState(() {
                              _entries[idx] = entry.copyWith(restSeconds: v);
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelSmall),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              onPressed: value - step >= min
                  ? () => onChanged(value - step)
                  : null,
            ),
            Text('$value', style: theme.textTheme.bodyMedium),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              onPressed: () => onChanged(value + step),
            ),
          ],
        ),
      ],
    );
  }
}
