import 'package:flutter/material.dart';

import '../models/workout_template.dart';
import '../state/open_gym_controller.dart';

/// Browse and import shared community routines from a connected server.
class CommunityRoutinesScreen extends StatefulWidget {
  const CommunityRoutinesScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  @override
  State<CommunityRoutinesScreen> createState() =>
      _CommunityRoutinesScreenState();
}

class _CommunityRoutinesScreenState extends State<CommunityRoutinesScreen> {
  bool _loading = true;
  String? _error;
  List<WorkoutTemplate> _routines = const <WorkoutTemplate>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.controller.fetchCommunityRoutines();
      if (!mounted) return;
      setState(() => _routines = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Routines'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _routines.isEmpty
                  ? const Center(child: Text('No community routines found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _routines.length,
                      itemBuilder: (context, index) {
                        final r = _routines[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(r.name),
                            subtitle: Text(
                              '${r.entries.length} exercises • ${r.goal}',
                            ),
                            trailing: FilledButton.tonal(
                              onPressed: () async {
                                await widget.controller.saveTemplate(
                                  WorkoutTemplate.create(
                                    name: r.name,
                                    goal: r.goal,
                                    description: r.description,
                                    entries: r.entries,
                                  ),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Imported "${r.name}".'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Import'),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
