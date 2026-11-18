import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/progress_photo.dart';
import '../state/open_gym_controller.dart';

/// Local-first progress photos gallery and side-by-side comparison screen.
class ProgressPhotosScreen extends StatefulWidget {
  const ProgressPhotosScreen({
    super.key,
    required this.controller,
  });

  final OpenGymController controller;

  @override
  State<ProgressPhotosScreen> createState() => _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends State<ProgressPhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  String _selectedPose = 'front';
  final Set<String> _compareIds = <String>{};

  String _todayIso() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 960,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    await widget.controller.saveProgressPhoto(
      ProgressPhoto.create(
        date: _todayIso(),
        pose: _selectedPose,
        base64Image: b64,
      ),
    );
  }

  void _showCompareDialog(List<ProgressPhoto> photos) {
    final selected = photos.where((p) => _compareIds.contains(p.id)).toList();
    if (selected.length != 2) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Side-by-Side Comparison'),
        content: SizedBox(
          width: 420,
          child: Row(
            children: selected.map((p) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(p.base64Image),
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${p.date} (${p.pose})'),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
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
        final photos = widget.controller.progressPhotos;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Progress Photos'),
            actions: <Widget>[
              if (_compareIds.length == 2)
                TextButton.icon(
                  onPressed: () => _showCompareDialog(photos),
                  icon: const Icon(Icons.compare),
                  label: const Text('Compare'),
                ),
            ],
          ),
          body: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'front', label: Text('Front')),
                    ButtonSegment<String>(value: 'side', label: Text('Side')),
                    ButtonSegment<String>(value: 'back', label: Text('Back')),
                  ],
                  selected: <String>{_selectedPose},
                  onSelectionChanged: (s) =>
                      setState(() => _selectedPose = s.first),
                ),
              ),
              Expanded(
                child: photos.isEmpty
                    ? Center(
                        child: Text(
                          'No progress photos yet. Tap + to add one locally.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                        itemCount: photos.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (context, index) {
                          final photo = photos[index];
                          final selected = _compareIds.contains(photo.id);
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: selected
                                  ? BorderSide(
                                      color: colorScheme.primary,
                                      width: 2.5,
                                    )
                                  : BorderSide.none,
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (selected) {
                                    _compareIds.remove(photo.id);
                                  } else if (_compareIds.length < 2) {
                                    _compareIds.add(photo.id);
                                  }
                                });
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Expanded(
                                    child: Image.memory(
                                      base64Decode(photo.base64Image),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            '${photo.date} • ${photo.pose}',
                                            style: theme.textTheme.labelSmall,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _compareIds.remove(photo.id);
                                            widget.controller
                                                .deleteProgressPhoto(photo.id);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add Photo'),
          ),
        );
      },
    );
  }
}
