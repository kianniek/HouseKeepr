import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../state/open_gym_controller.dart';
import 'active_workout_screen.dart';
import 'widgets/body_map_widget.dart';
import 'widgets/exercise_media_view.dart';

/// Interactive muscle explorer matching `explore_muscles.png` & `explore_muscles_selected.png`.
class ExploreMusclesScreen extends StatefulWidget {
  const ExploreMusclesScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  @override
  State<ExploreMusclesScreen> createState() => _ExploreMusclesScreenState();
}

class _ExploreMusclesScreenState extends State<ExploreMusclesScreen> {
  final Set<String> _selectedMuscles = <String>{};
  bool _matchAll = true;
  String _search = '';

  static const Map<String, List<String>> _muscleToBodyParts =
      <String, List<String>>{
    'chest': <String>['chest'],
    'abs': <String>['waist'],
    'obliques': <String>['waist'],
    'deltoids': <String>['shoulders'],
    'biceps': <String>['upper arms'],
    'triceps': <String>['upper arms'],
    'forearm': <String>['lower arms'],
    'trapezius': <String>['back'],
    'upper-back': <String>['back'],
    'lower-back': <String>['back'],
    'gluteal': <String>['upper legs'],
    'quadriceps': <String>['upper legs'],
    'hamstring': <String>['upper legs'],
    'adductors': <String>['upper legs'],
    'calves': <String>['lower legs'],
  };

  void _toggleMuscle(String key) {
    setState(() {
      if (_selectedMuscles.contains(key)) {
        _selectedMuscles.remove(key);
      } else {
        _selectedMuscles.add(key);
      }
    });
  }

  List<Exercise> _filteredExercises() {
    final all = widget.controller.exercises;
    return all.where((ex) {
      if (_search.isNotEmpty &&
          !ex.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      if (_selectedMuscles.isEmpty) return true;
      final matches = _selectedMuscles.map((m) {
        final parts = _muscleToBodyParts[m] ?? const <String>[];
        return parts.contains(ex.bodyPart) ||
            ex.target.toLowerCase().contains(m.replaceAll('-', ' ')) ||
            ex.secondaryMuscles.any(
              (s) => s.toLowerCase().contains(m.replaceAll('-', ' ')),
            );
      });
      return _matchAll ? matches.every((b) => b) : matches.any((b) => b);
    }).toList();
  }

  void _buildSession(List<Exercise> matching) {
    if (matching.isEmpty) return;
    widget.controller.startEmptyWorkout(title: 'Targeted Muscle Session');
    for (final ex in matching.take(5)) {
      widget.controller.addExerciseToActiveWorkout(ex);
    }
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
    final matching = _filteredExercises();

    return Scaffold(
      appBar: AppBar(title: const Text('Explore muscles')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Choose a muscle to see exercises that train it, or build a session from it.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          BodyMapWidget(
            weeklySetsByBodyPart: const <String, int>{},
            selectedMuscles: _selectedMuscles,
            onToggleMuscle: _toggleMuscle,
            showHeader: false,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _muscleToBodyParts.keys.map((m) {
              final selected = _selectedMuscles.contains(m);
              return FilterChip(
                label: Text(m.replaceAll('-', ' ')),
                selected: selected,
                onSelected: (_) => _toggleMuscle(m),
              );
            }).toList(),
          ),
          if (_selectedMuscles.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: true, label: Text('All of them')),
                ButtonSegment<bool>(value: false, label: Text('Any of them')),
              ],
              selected: <bool>{_matchAll},
              onSelectionChanged: (s) => setState(() => _matchAll = s.first),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _buildSession(matching),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Build a session'),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Exercises for ${_selectedMuscles.map((e) => e.replaceAll('-', ' ')).join(' + ')}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(_selectedMuscles.clear),
                  child: const Text('Clear selection'),
                ),
              ],
            ),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search ${matching.length} exercises...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 8),
            ...matching.take(40).map(
                  (ex) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: ExerciseStillThumbnail(
                        exerciseId: ex.id,
                        mediaService: widget.controller.mediaService,
                        serverUrl:
                            widget.controller.serverConnection?.serverUrl,
                      ),
                      title: Text(ex.name),
                      subtitle: Text('${ex.target} • ${ex.equipment}'),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
