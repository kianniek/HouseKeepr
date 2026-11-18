import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../state/open_gym_controller.dart';
import 'active_workout_screen.dart';
import 'explore_muscles_screen.dart';
import 'skill_ladders_sheet.dart';
import 'widgets/exercise_media_view.dart';

/// Browseable, searchable exercise library matching `exercises_list_1.png`
/// and `exercises_filters.png`.
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
  String _selectedCategory = 'all';
  String _selectedEquipment = 'all';
  bool _isGrid = false;

  Future<void> _showFiltersSheet(List<Exercise> all) async {
    final categories = <String>{
      'all',
      ...all.map((e) => e.category).where((c) => c.isNotEmpty),
    }.toList()
      ..sort();
    final equipments = <String>{
      'all',
      ...all.map((e) => e.equipment).where((eq) => eq.isNotEmpty),
    }.toList()
      ..sort();

    String tempCat = _selectedCategory;
    String tempEq = _selectedEquipment;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            maxChildSize: 0.92,
            builder: (_, scrollCtrl) => Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: <Widget>[
                      Text(
                        'Filters',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Exercise type', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: categories.map((c) {
                          return FilterChip(
                            label: Text(c == 'all' ? 'Any type' : c),
                            selected: tempCat == c,
                            onSelected: (_) =>
                                setSheetState(() => tempCat = c),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Text('Equipment', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: equipments.map((eq) {
                          return FilterChip(
                            label: Text(eq == 'all' ? 'Any equipment' : eq),
                            selected: tempEq == eq,
                            onSelected: (_) =>
                                setSheetState(() => tempEq = eq),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = tempCat;
                          _selectedEquipment = tempEq;
                        });
                        Navigator.of(sheetCtx).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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

  void _quickAddToWorkout(Exercise ex) {
    if (!widget.controller.hasActiveWorkout) {
      widget.controller.startEmptyWorkout(title: ex.name);
    }
    widget.controller.addExerciseToActiveWorkout(ex);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActiveWorkoutScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final all = widget.controller.exercises;
        final unit = widget.controller.preferences.weightUnit;
        final favIds = widget.controller.preferences.favoriteExerciseIds.toSet();
        final bestWeights = <String, double>{
          for (final pr in widget.controller.allPersonalRecords)
            if (pr.bestWeight > 0) pr.exerciseId: pr.bestWeight,
        };
        final bodyParts = <String>{
          'all',
          ...all.map((e) => e.bodyPart),
        }.toList();

        final filtered = all.where((e) {
          final matchesPart =
              _selectedBodyPart == 'all' || e.bodyPart == _selectedBodyPart;
          final matchesCat =
              _selectedCategory == 'all' || e.category == _selectedCategory;
          final matchesEq =
              _selectedEquipment == 'all' || e.equipment == _selectedEquipment;
          final q = _query.trim().toLowerCase();
          final matchesQuery = q.isEmpty ||
              e.name.toLowerCase().contains(q) ||
              e.target.toLowerCase().contains(q) ||
              e.equipment.toLowerCase().contains(q);
          return matchesPart && matchesCat && matchesEq && matchesQuery;
        }).toList();

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!widget.isPicker)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Exercises',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${all.length} exercises with animations',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => ExploreMusclesScreen(
                            controller: widget.controller,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.accessibility_new, size: 18),
                      label: const Text('By muscle'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.tonalIcon(
                      onPressed: () => showSkillLaddersSheet(
                        context,
                        widget.controller,
                      ),
                      icon: const Icon(Icons.stairs, size: 18),
                      label: const Text('Ladders'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: _isGrid ? 'List view' : 'Grid view',
                    icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view),
                    onPressed: () => setState(() => _isGrid = !_isGrid),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: <Widget>[
                  ActionChip(
                    avatar: const Icon(Icons.tune, size: 18),
                    label: const Text('Filters'),
                    onPressed: () => _showFiltersSheet(all),
                  ),
                  const SizedBox(width: 8),
                  ...bodyParts.map((part) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(part == 'all' ? 'All' : part),
                        selected: _selectedBodyPart == part,
                        onSelected: (_) =>
                            setState(() => _selectedBodyPart = part),
                      ),
                    );
                  }),
                ],
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
                  : _isGrid
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.15,
                          ),
                          itemBuilder: (context, index) {
                            final ex = filtered[index];
                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => widget.isPicker
                                    ? Navigator.of(context).pop(ex)
                                    : _showExerciseDetail(ex),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      if (!ex.isCustom)
                                        ExerciseStillThumbnail(
                                          exerciseId: ex.id,
                                          mediaService:
                                              widget.controller.mediaService,
                                          serverUrl: widget.controller
                                              .serverConnection?.serverUrl,
                                        ),
                                      const Spacer(),
                                      Text(
                                        ex.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      Text(
                                        ex.equipment,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length + (widget.isPicker ? 0 : 1),
                          itemBuilder: (context, index) {
                            if (!widget.isPicker && index == 0) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.add),
                                  ),
                                  title: const Text('Create your own exercise'),
                                  subtitle: const Text(
                                    'Name + body part, custom tracking',
                                  ),
                                  trailing: const Icon(Icons.add),
                                  onTap: _showCreateExerciseDialog,
                                ),
                              );
                            }
                            final ex =
                                filtered[widget.isPicker ? index : index - 1];
                            final bestW = bestWeights[ex.id];
                            final isFav = favIds.contains(ex.id);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: ex.isCustom
                                    ? null
                                    : ExerciseStillThumbnail(
                                        exerciseId: ex.id,
                                        mediaService:
                                            widget.controller.mediaService,
                                        serverUrl: widget.controller
                                            .serverConnection?.serverUrl,
                                      ),
                                title: Text(ex.name),
                                subtitle:
                                    Text('${ex.target} • ${ex.equipment}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (bestW != null) ...<Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${bestW % 1 == 0 ? bestW.toInt() : bestW.toStringAsFixed(1)} $unit',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: isFav
                                          ? 'Remove favourite'
                                          : 'Favourite exercise',
                                      icon: Icon(
                                        isFav
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        size: 20,
                                        color: isFav
                                            ? Colors.amber.shade600
                                            : null,
                                      ),
                                      onPressed: () => widget.controller
                                          .toggleExerciseFavorite(ex.id),
                                    ),
                                    IconButton(
                                      tooltip: widget.isPicker
                                          ? 'Select'
                                          : 'Add to workout',
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        if (widget.isPicker) {
                                          Navigator.of(context).pop(ex);
                                        } else {
                                          _quickAddToWorkout(ex);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  if (widget.isPicker) {
                                    Navigator.of(context).pop(ex);
                                  } else {
                                    _showExerciseDetail(ex);
                                  }
                                },
                              ),
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
            body: content,
          );
        }

        return content;
      },
    );
  }

  void _showExerciseDetail(Exercise ex) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!ex.isCustom) ...<Widget>[
                ExerciseAnimationView(
                  exerciseId: ex.id,
                  controller: widget.controller,
                ),
                const SizedBox(height: 12),
              ],
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
