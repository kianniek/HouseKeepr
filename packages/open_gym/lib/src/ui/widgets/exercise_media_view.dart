import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/exercise_media_service.dart';
import '../../state/open_gym_controller.dart';

/// Compact rounded `.webp` thumbnail for exercise list items and workout headers.
class ExerciseStillThumbnail extends StatefulWidget {
  const ExerciseStillThumbnail({
    super.key,
    required this.exerciseId,
    required this.mediaService,
    this.serverUrl,
    this.size = 44,
    this.showMaximizeBadge = false,
  });

  final String exerciseId;
  final ExerciseMediaService mediaService;
  final String? serverUrl;
  final double size;
  final bool showMaximizeBadge;

  @override
  State<ExerciseStillThumbnail> createState() => _ExerciseStillThumbnailState();
}

class _ExerciseStillThumbnailState extends State<ExerciseStillThumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ExerciseStillThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = await widget.mediaService.loadStillBytes(
      widget.exerciseId,
      serverUrl: widget.serverUrl,
    );
    if (mounted && bytes != null) {
      setState(() => _bytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_bytes != null)
            Image.memory(_bytes!, fit: BoxFit.cover)
          else
            Icon(
              Icons.fitness_center_rounded,
              size: widget.size * 0.45,
              color: colorScheme.onSurfaceVariant,
            ),
          if (widget.showMaximizeBadge)
            Positioned(
              right: 3,
              bottom: 3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: colorScheme.scrim.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_full,
                  size: 11,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Looping, muted, auto-playing `.mp4` exercise animation with `.webp` still
/// fallback and graceful offline handling.
class ExerciseAnimationView extends StatefulWidget {
  const ExerciseAnimationView({
    super.key,
    required this.exerciseId,
    required this.controller,
    this.height = 200,
    this.isPlaying = true,
  });

  final String exerciseId;
  final OpenGymController controller;
  final double? height;
  final bool isPlaying;

  @override
  State<ExerciseAnimationView> createState() => _ExerciseAnimationViewState();
}

class _ExerciseAnimationViewState extends State<ExerciseAnimationView> {
  VideoPlayerController? _videoController;
  Uint8List? _stillBytes;
  bool _videoReady = false;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  @override
  void didUpdateWidget(covariant ExerciseAnimationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId) {
      _videoController?.dispose();
      _videoController = null;
      _stillBytes = null;
      _videoReady = false;
      _videoFailed = false;
      _initMedia();
    } else if (oldWidget.isPlaying != widget.isPlaying && _videoReady) {
      if (widget.isPlaying) {
        _videoController?.play();
      } else {
        _videoController?.pause();
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initMedia() async {
    final serverUrl = widget.controller.serverConnection?.serverUrl;
    final stillFuture = widget.controller.mediaService.loadStillBytes(
      widget.exerciseId,
      serverUrl: serverUrl,
    );

    final clipUrl = ExerciseMediaService.clipUrlFor(
      widget.exerciseId,
      serverUrl: serverUrl,
    );
    final vc = VideoPlayerController.networkUrl(
      Uri.parse(clipUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _videoController = vc;

    stillFuture.then((bytes) {
      if (mounted && bytes != null) {
        setState(() => _stillBytes = bytes);
      }
    });

    try {
      await vc.initialize();
      await vc.setLooping(true);
      await vc.setVolume(0);
      if (widget.isPlaying) {
        await vc.play();
      }
      if (mounted) {
        setState(() => _videoReady = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _videoFailed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: _videoReady && _videoController != null
          ? FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            )
          : _stillBytes != null
              ? Image.memory(_stillBytes!, fit: BoxFit.contain)
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _videoFailed
                            ? Icons.videocam_off_outlined
                            : Icons.fitness_center_rounded,
                        size: 36,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _videoFailed
                            ? 'Animation unavailable offline'
                            : 'Loading visualization...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
    );
    if (widget.height == null) {
      return AspectRatio(aspectRatio: 1.0, child: content);
    }
    return content;
  }
}
