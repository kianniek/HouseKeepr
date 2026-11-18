import 'package:flutter/material.dart';

import '../models/programme.dart';
import '../state/open_gym_controller.dart';

/// Weekly training programmes screen mapping weekdays (Mon–Sun) to routines.
class ProgrammesScreen extends StatelessWidget {
  const ProgrammesScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  static const List<String> _weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<void> _createOrEditProgramme(
    BuildContext context, [
    Programme? existing,
  ]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final schedule = Map<int, String>.from(
      existing?.weekdayToTemplateId ?? const <int, String>{},
    );
    final templates = controller.templates;

    final saved = await showDialog<Programme>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'New Programme' : 'Edit Programme'),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Programme Name',
                        hintText: 'e.g. PPL 3-Day Split',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List<Widget>.generate(7, (i) {
                      final day = i + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DropdownButtonFormField<String?>(
                          initialValue: schedule[day],
                          decoration: InputDecoration(
                            labelText: _weekdayNames[i],
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Rest Day'),
                            ),
                            ...templates.map(
                              (t) => DropdownMenuItem<String?>(
                                value: t.id,
                                child: Text(t.name),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == null) {
                                schedule.remove(day);
                              } else {
                                schedule[day] = v;
                              }
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
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
                  final result = existing != null
                      ? existing.copyWith(
                          name: name,
                          weekdayToTemplateId: schedule,
                        )
                      : Programme.create(
                          name: name,
                          weekdayToTemplateId: schedule,
                          isActive: controller.programmes.isEmpty,
                        );
                  Navigator.of(dialogContext).pop(result);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != null) {
      await controller.saveProgramme(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final programmes = controller.programmes;
        final templatesById = <String, String>{
          for (final t in controller.templates) t.id: t.name,
        };

        return Scaffold(
          appBar: AppBar(title: const Text('Weekly Programmes')),
          body: programmes.isEmpty
              ? Center(
                  child: Text(
                    'No programmes yet. Tap + to schedule your week.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: programmes.length,
                  itemBuilder: (context, index) {
                    final p = programmes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (p.isActive)
                                  Chip(
                                    label: Text('Active',
                                        style: theme.textTheme.labelSmall),
                                    visualDensity: VisualDensity.compact,
                                  )
                                else
                                  TextButton(
                                    onPressed: () =>
                                        controller.activateProgramme(p.id),
                                    child: const Text('Activate'),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () =>
                                      _createOrEditProgramme(context, p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      controller.deleteProgramme(p.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...p.weekdayToTemplateId.entries.map((e) {
                              final dayName = _weekdayNames[(e.key - 1).clamp(0, 6)];
                              final routineName =
                                  templatesById[e.value] ?? 'Routine';
                              return Text('$dayName: $routineName',
                                  style: theme.textTheme.bodySmall);
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _createOrEditProgramme(context),
            icon: const Icon(Icons.add),
            label: const Text('New Programme'),
          ),
        );
      },
    );
  }
}
