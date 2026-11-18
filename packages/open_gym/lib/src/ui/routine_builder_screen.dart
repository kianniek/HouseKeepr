import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise.dart';
import '../models/workout_template.dart';
import '../state/open_gym_controller.dart';
import '../state/progression_service.dart';
import 'explore_muscles_screen.dart';
import 'widgets/body_map_widget.dart';
import 'widgets/exercise_media_view.dart';
import 'widgets/plan_sheets.dart';
import 'widgets/routine_glyph_icon.dart';
import 'widgets/undo_toast.dart';

/// Auto-saving routine editor screen matching
/// `Plan/plan_routines_new_routine*.png` (`RoutineEdit.jsx`).
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
  late WorkoutTemplate _template;
  late TextEditingController _nameCtrl;
  bool _hasPersisted = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTemplate;
    if (existing != null) {
      _template = existing;
      _hasPersisted = true;
    } else {
      _template = WorkoutTemplate.create(
        name: 'New routine',
        sortOrder: widget.controller.templates.length,
        entries: const <WorkoutTemplateEntry>[],
      );
      _hasPersisted = false;
    }
    _nameCtrl = TextEditingController(text: _template.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _commitTemplate(WorkoutTemplate next) async {
    setState(() => _template = next);
    await widget.controller.saveTemplate(next);
    _hasPersisted = true;
  }

  Future<void> _addExerciseFromModal() async {
    final picked = await _showRoutineAddExerciseSheet(context);
    if (picked == null) return;
    final newEntry = WorkoutTemplateEntry(
      exerciseId: picked.id,
      exerciseName: picked.name,
      bodyPart: picked.bodyPart,
      equipment: picked.equipment,
      restSeconds: widget.controller.preferences.defaultRestSeconds,
    );
    await _commitTemplate(
      _template.copyWith(
        entries: <WorkoutTemplateEntry>[..._template.entries, newEntry],
      ),
    );
  }

  Future<Exercise?> _showRoutineAddExerciseSheet(BuildContext context) {
    String query = '';
    String selectedPart = 'all';
    String selectedType = 'all';
    String selectedEq = 'all';
    bool isGrid = false;

    final all = widget.controller.exercises;
    final favIds = widget.controller.preferences.favoriteExerciseIds.toSet();
    final bodyParts = <String>{
      'all',
      ...all.map((e) => e.bodyPart).where((b) => b.isNotEmpty),
    }.toList();
    final types = <String>{
      'all',
      ...all.map((e) => e.category).where((c) => c.isNotEmpty),
    }.toList();
    final equipments = <String>{
      'all',
      ...all.map((e) => e.equipment).where((eq) => eq.isNotEmpty),
    }.toList();

    return showModalBottomSheet<Exercise>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final filtered = all.where((e) {
            if (selectedPart == '__favs__' && !favIds.contains(e.id)) {
              return false;
            } else if (selectedPart != 'all' &&
                selectedPart != '__favs__' &&
                e.bodyPart != selectedPart) {
              return false;
            }
            if (selectedType != 'all' && e.category != selectedType) {
              return false;
            }
            if (selectedEq != 'all' && e.equipment != selectedEq) {
              return false;
            }
            final q = query.trim().toLowerCase();
            if (q.isNotEmpty &&
                !e.name.toLowerCase().contains(q) &&
                !e.target.toLowerCase().contains(q) &&
                !e.equipment.toLowerCase().contains(q)) {
              return false;
            }
            return true;
          }).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            maxChildSize: 0.96,
            builder: (_, scrollCtrl) => Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Add exercise',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          Navigator.of(this.context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => ExploreMusclesScreen(
                                controller: widget.controller,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.accessibility_new, size: 18),
                        label: const Text('By muscle'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search ${all.length} exercises...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            isDense: true,
                          ),
                          onChanged: (v) => setSheetState(() => query = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
                        onPressed: () =>
                            setSheetState(() => isGrid = !isGrid),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text('★ Chosen (${favIds.length})'),
                          selected: selectedPart == '__favs__',
                          onSelected: (_) => setSheetState(
                            () => selectedPart = '__favs__',
                          ),
                        ),
                      ),
                      ...bodyParts.map(
                        (part) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(part == 'all' ? 'All' : part),
                            selected: selectedPart == part,
                            onSelected: (_) =>
                                setSheetState(() => selectedPart = part),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: types
                        .map(
                          (type) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(type == 'all' ? 'Any type' : type),
                              selected: selectedType == type,
                              onSelected: (_) =>
                                  setSheetState(() => selectedType = type),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: equipments
                        .map(
                          (eq) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(eq == 'all' ? 'Any equipment' : eq),
                              selected: selectedEq == eq,
                              onSelected: (_) =>
                                  setSheetState(() => selectedEq = eq),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: isGrid
                      ? GridView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.15,
                          ),
                          itemBuilder: (_, idx) {
                            final ex = filtered[idx];
                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.of(sheetCtx).pop(ex),
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
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length + 1,
                          itemBuilder: (_, index) {
                            if (index == 0) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.add_circle_outline),
                                  ),
                                  title:
                                      const Text('Create your own exercise'),
                                  subtitle: const Text(
                                    'name + body part, and a photo or video if you like',
                                  ),
                                  trailing: const Icon(Icons.add),
                                  onTap: () => _createCustomFromSheet(sheetCtx),
                                ),
                              );
                            }
                            final ex = filtered[index - 1];
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
                                    Text('${ex.target} · ${ex.equipment}'),
                                trailing: const Icon(Icons.add),
                                onTap: () => Navigator.of(sheetCtx).pop(ex),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createCustomFromSheet(BuildContext sheetCtx) async {
    final nameCtrl = TextEditingController();
    String bodyPart = 'chest';
    String equipment = 'barbell';

    final created = await showDialog<Exercise>(
      context: sheetCtx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Custom Exercise'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
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
                      (b) => DropdownMenuItem<String>(value: b, child: Text(b)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => bodyPart = v);
                },
              ),
              const SizedBox(height: 10),
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
                      (eq) =>
                          DropdownMenuItem<String>(value: eq, child: Text(eq)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => equipment = v);
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = nameCtrl.text.trim();
                if (n.isEmpty) return;
                Navigator.of(dialogCtx).pop(
                  Exercise.create(
                    name: n,
                    bodyPart: bodyPart,
                    equipment: equipment,
                    target: bodyPart,
                  ),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created != null) {
      await widget.controller.addCustomExercise(created);
      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop(created);
    }
  }

  Future<void> _toggleSupersetWithAbove(int index) async {
    if (index <= 0 || index >= _template.entries.length) return;
    final list = List<WorkoutTemplateEntry>.from(_template.entries);
    final cur = list[index];
    final prev = list[index - 1];
    if (cur.supersetId != null && cur.supersetId == prev.supersetId) {
      list[index] = cur.copyWith(clearSuperset: true);
    } else {
      final gid = prev.supersetId ?? 'sg_${DateTime.now().millisecondsSinceEpoch}';
      list[index - 1] = prev.copyWith(supersetId: gid);
      list[index] = cur.copyWith(supersetId: gid);
    }
    await _commitTemplate(
      _template.copyWith(
        entries: ProgressionService.cleanupTemplateSupersets(list),
      ),
    );
  }

  Future<void> _moveEntry(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _template.entries.length) return;
    final list = List<WorkoutTemplateEntry>.from(_template.entries);
    final item = list.removeAt(index);
    list.insert(target, item);
    await _commitTemplate(
      _template.copyWith(
        entries: ProgressionService.cleanupTemplateSupersets(list),
      ),
    );
  }

  Future<void> _copyRoutine() async {
    if (!_hasPersisted) {
      await widget.controller.saveTemplate(_template);
      _hasPersisted = true;
    }
    final copy = await widget.controller.duplicateTemplate(
      _template.id,
      insertBelowOriginal: false,
    );
    if (!mounted) return;
    setState(() {
      _template = copy;
      _nameCtrl.text = copy.name;
    });
  }

  Future<void> _deleteRoutine() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete routine?'),
        content: Text(
          '“${_template.name}” and its exercises will be removed.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.error,
              foregroundColor: Theme.of(dialogCtx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (_hasPersisted) {
      await widget.controller.deleteTemplateWithSnapshot(_template.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unit = widget.controller.preferences.weightUnit;
    final entries = _template.entries;
    final units = ProgressionService.supersetUnits(entries);
    final ssBadges = <int, String>{};
    int groupNumber = 0;
    for (final u in units) {
      if (u.length > 1) {
        final letter = String.fromCharCode(65 + (groupNumber % 26));
        for (var k = 0; k < u.length; k++) {
          ssBadges[u[k]] = '$letter${k + 1}';
        }
        groupNumber++;
      }
    }

    final existingFolders = widget.controller.templates
        .map((t) => t.folder?.trim() ?? '')
        .where((f) => f.isNotEmpty)
        .toSet()
        .toList();

    final bodyPartMap = <String, int>{
      for (final e in entries) e.bodyPart: 4,
    };

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            // Top bar matching `Plan/plan_routines_new_routine.png`
            Row(
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: 'Back to Plan',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Routine name',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) {
                      final trimmed = v.trim();
                      if (trimmed.isNotEmpty) {
                        _commitTemplate(_template.copyWith(name: trimmed));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: _template.isFavorite
                      ? 'Remove from favourites'
                      : 'Add to favourites',
                  icon: Icon(
                    _template.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: _template.isFavorite ? Colors.amber.shade600 : null,
                  ),
                  onPressed: () async {
                    final nextFav = !_template.isFavorite;
                    await _commitTemplate(
                      _template.copyWith(isFavorite: nextFav),
                    );
                    if (context.mounted) {
                      showOpenGymUndoToast(
                        context,
                        message: nextFav
                            ? 'Starred. It leads your routines now.'
                            : 'No longer a favourite.',
                      );
                    }
                  },
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Pick an icon',
                  icon: Icon(routineGlyphIconData(_template.iconKey)),
                  onPressed: () async {
                    final picked = await showRoutineGlyphPickerSheet(
                      context,
                      currentIconKey: _template.iconKey,
                    );
                    if (picked != null) {
                      await _commitTemplate(
                        _template.copyWith(iconKey: picked),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4-row grouped routine settings Card
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.show_chart_rounded,
                        size: 20,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    title: const Text('Progression'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          ProgressionService.policyTitle(
                            _template.progressionPolicy,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showRoutineProgressionSheet(
                        context,
                        currentPolicy: _template.progressionPolicy,
                      );
                      if (picked != null) {
                        await _commitTemplate(
                          _template.copyWith(progressionPolicy: picked),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.folder_outlined,
                        size: 20,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: const Text('Folder'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          (_template.folder?.isNotEmpty ?? false)
                              ? _template.folder!
                              : 'None',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showRoutineFolderSheet(
                        context,
                        currentFolder: _template.folder,
                        existingFolders: existingFolders,
                      );
                      if (picked != null) {
                        await _commitTemplate(
                          picked.isEmpty
                              ? _template.copyWith(clearFolder: true)
                              : _template.copyWith(folder: picked),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.timer_outlined,
                        size: 20,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    title: const Text('Routine type'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          routineTypeLabel(_template.routineType),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showRoutineTypeSheet(
                        context,
                        currentType: _template.routineType,
                      );
                      if (picked != null) {
                        await _commitTemplate(
                          _template.copyWith(routineType: picked),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.trending_down_rounded,
                        size: 20,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                    title: const Text('Deload routine'),
                    subtitle: const Text(
                      'Its workouts do not count toward progression. They still show in history and statistics.',
                    ),
                    value: _template.isDeload,
                    onChanged: (v) =>
                        _commitTemplate(_template.copyWith(isDeload: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _template.isDeload
                  ? 'A deload routine opens at the numbers set here, so the progression above does not apply to it. The next regular target continues from the last included workout.'
                  : '${ProgressionService.policyDescription(_template.progressionPolicy)} Applies to every exercise in this routine that does not set its own rule.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Exercises header + Add exercise
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Exercises', style: theme.textTheme.titleMedium),
                FilledButton.tonalIcon(
                  onPressed: _addExerciseFromModal,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add exercise'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 32,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No exercises yet. Add your first one!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else ...<Widget>[
              ...entries.asMap().entries.map((item) {
                final idx = item.key;
                final entry = item.value;
                final linkedPrev = idx > 0 &&
                    entry.supersetId != null &&
                    entry.supersetId == entries[idx - 1].supersetId;
                final badge = ssBadges[idx];

                return Card(
                  key: ValueKey<String>('ex_${entry.exerciseId}_$idx'),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (badge != null) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        ExerciseStillThumbnail(
                          exerciseId: entry.exerciseId,
                          mediaService: widget.controller.mediaService,
                          serverUrl:
                              widget.controller.serverConnection?.serverUrl,
                        ),
                      ],
                    ),
                    title: Text(entry.exerciseName),
                    subtitle: Text(entry.prescriptionSummary(unit)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (idx > 0)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Superset with exercise above',
                            icon: Icon(
                              Icons.link,
                              size: 18,
                              color: linkedPrev
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () => _toggleSupersetWithAbove(idx),
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                          onPressed:
                              idx > 0 ? () => _moveEntry(idx, -1) : null,
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                          onPressed: idx < entries.length - 1
                              ? () => _moveEntry(idx, 1)
                              : null,
                        ),
                      ],
                    ),
                    onTap: () => showExerciseConfigSheet(
                      context,
                      controller: widget.controller,
                      entry: entry,
                      onSave: (updated) {
                        final list = List<WorkoutTemplateEntry>.from(entries);
                        list[idx] = updated;
                        _commitTemplate(_template.copyWith(entries: list));
                      },
                      onRemove: () {
                        final list = List<WorkoutTemplateEntry>.from(entries)
                          ..removeAt(idx);
                        _commitTemplate(
                          _template.copyWith(
                            entries: ProgressionService.cleanupTemplateSupersets(
                              list,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'What this session hits',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      BodyMapWidget(
                        weeklySetsByBodyPart: bodyPartMap,
                        showHeader: false,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: bodyPartMap.keys
                            .take(6)
                            .map((m) => Chip(label: Text(m)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.link,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tap the link button on an exercise to superset it with the one above. You’ll do them back-to-back.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bottom action cards (`Copy routine`, `Share with a friend`, `Print / Save as PDF`)
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: Icon(Icons.copy_rounded, color: colorScheme.primary),
                    title: const Text('Copy routine'),
                    onTap: _copyRoutine,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    enabled: entries.isNotEmpty,
                    leading: const Icon(Icons.ios_share_rounded),
                    title: const Text('Share with a friend'),
                    onTap: entries.isEmpty
                        ? null
                        : () async {
                            final payload = jsonEncode(_template.toJson());
                            await Clipboard.setData(ClipboardData(text: payload));
                            if (context.mounted) {
                              showOpenGymUndoToast(
                                context,
                                message: 'Routine JSON copied to clipboard.',
                              );
                            }
                          },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    enabled: entries.isNotEmpty,
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('Print / Save as PDF'),
                    onTap: entries.isEmpty
                        ? null
                        : () {
                            final summary = entries
                                .map(
                                  (e) =>
                                      '• ${e.exerciseName}: ${e.prescriptionSummary(unit)}',
                                )
                                .join('\n');
                            showDialog<void>(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                title: Text(_template.name),
                                content: SelectableText(summary),
                                actions: <Widget>[
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(dialogCtx).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: colorScheme.error),
                title: Text(
                  'Delete routine',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '“${_template.name}” and its exercises will be removed.',
                ),
                onTap: _deleteRoutine,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
