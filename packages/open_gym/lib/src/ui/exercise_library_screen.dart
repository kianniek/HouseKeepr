import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../state/open_gym_controller.dart';

/// Browseable, searchable exercise library.
///
/// When [isPicker] is `true`, tapping an exercise pops it as the route result.
class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({
    super.key,
    required this.controller,
    this.isPicker = false,
  });

  final OpenGymController controller;
  final bool isPicker;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _query = '';
  String _selectedBodyPart = 'all';

  Future<void> _showCreateExerciseDialog() async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    String bodyPart = 'chest';
    String equipment = 'barbell';

    final created = await showDialog<Exercise>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New Custom Exercise'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Exercise Name',
                        hintText: 'e.g. Bulgarian Split Squat',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: bodyPart,
                      decoration: const InputDecoration(labelText: 'Body Part'),
                      items: const <String>[
                        'chest',
                        'back',
                        'upper legs',
                        'lower legs',
                        'shoulders',
                        'upper arms',
                        'waist',
                        'full body',
                      ]
                          .map(
                            (bp) => DropdownMenuItem<String>(
                              value: bp,
                              child: Text(bp),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => bodyPart = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: equipment,
                      decoration: const InputDecoration(labelText: 'Equipment'),
                      items: const <String>[
                        'barbell',
                        'dumbbell',
                        'body weight',
                        'cable',
                        'machine',
                        'kettlebell',
                      ]
                          .map(
                            (eq) => DropdownMenuItem<String>(
                              value: eq,
                              child: Text(eq),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => equipment = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Target Muscle',
                        hintText: 'e.g. quads',
                      ),
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
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.of(dialogContext).pop(
                      Exercise.create(
                        name: name,
                        bodyPart: bodyPart,
                        equipment: equipment,
                        target: targetCtrl.text.trim().isEmpty
                            ? bodyPart
                            : targetCtrl.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != null) {
      await widget.controller.addCustomExercise(created);
      if (widget.isPicker && mounted) {
        Navigator.of(context).pop(created);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final all = widget.controller.exercises;
        final bodyParts = <String>{
          'all',
          ...all.map((e) => e.bodyPart),
        }.toList();

        final filtered = all.where((e) {
          final matchesPart =
              _selectedBodyPart == 'all' || e.bodyPart == _selectedBodyPart;
          final q = _query.trim().toLowerCase();
          final matchesQuery = q.isEmpty ||
              e.name.toLowerCase().contains(q) ||
              e.target.toLowerCase().contains(q) ||
              e.equipment.toLowerCase().contains(q);
          return matchesPart && matchesQuery;
        }).toList();

        final body = Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search exercises, muscles, equipment...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: bodyParts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final part = bodyParts[index];
                  return FilterChip(
                    label: Text(part),
                    selected: _selectedBodyPart == part,
                    onSelected: (_) =>
                        setState(() => _selectedBodyPart = part),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No exercises match your filter.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final ex = filtered[index];
                        return ListTile(
                          title: Text(ex.name),
                          subtitle: Text(
                            '${ex.bodyPart} • ${ex.equipment} • ${ex.target}',
                          ),
                          trailing: widget.isPicker
                              ? const Icon(Icons.add_circle_outline)
                              : (ex.isCustom
                                  ? Chip(
                                      label: Text(
                                        'Custom',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    )
                                  : null),
                          onTap: () {
                            if (widget.isPicker) {
                              Navigator.of(context).pop(ex);
                            } else {
                              _showExerciseDetail(ex);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );

        if (widget.isPicker) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Select Exercise'),
              actions: <Widget>[
                IconButton(
                  tooltip: 'New custom exercise',
                  icon: const Icon(Icons.add),
                  onPressed: _showCreateExerciseDialog,
                ),
              ],
            ),
            body: body,
          );
        }

        return Scaffold(
          body: body,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showCreateExerciseDialog,
            icon: const Icon(Icons.add),
            label: const Text('New Exercise'),
          ),
        );
      },
    );
  }

  void _showExerciseDetail(Exercise ex) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(ex.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  Chip(label: Text(ex.bodyPart)),
                  Chip(label: Text(ex.equipment)),
                  Chip(label: Text('Target: ${ex.target}')),
                ],
              ),
              if (ex.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(ex.description, style: theme.textTheme.bodyMedium),
              ],
              if (ex.instructions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text('Instructions', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                ...ex.instructions.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${entry.key + 1}. ${entry.value}'),
                      ),
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}
