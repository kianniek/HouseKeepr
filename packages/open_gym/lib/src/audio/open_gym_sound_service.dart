import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'wav_synthesizer.dart';

/// Rest-end sound profile metadata matching `openGym` `rest-sounds.js`.
class RestSoundProfile {
  const RestSoundProfile({
    required this.id,
    required this.label,
    required this.notes,
    this.peak = 0.75,
    this.holdFraction = 0.0,
    this.timbre = 'sine',
  });

  final String id;
  final String label;
  final List<ToneNote> notes;
  final double peak;
  final double holdFraction;
  final String timbre;
}

/// Synthesizes and plays OpenGym's audio clicks, chimes, and haptics on
/// both Android and Web.
class OpenGymSoundService {
  OpenGymSoundService();

  static const List<RestSoundProfile> restSounds = <RestSoundProfile>[
    RestSoundProfile(
      id: 'chime',
      label: 'Chime',
      peak: 0.85,
      holdFraction: 0.6,
      timbre: 'bright',
      notes: <ToneNote>[
        ToneNote(freqHz: 1319, durationSec: 0.16, startOffsetSec: 0),
        ToneNote(freqHz: 988, durationSec: 0.16, startOffsetSec: 0.22),
        ToneNote(freqHz: 1319, durationSec: 0.50, startOffsetSec: 0.44),
      ],
    ),
    RestSoundProfile(
      id: 'classic',
      label: 'Classic',
      peak: 0.45,
      notes: <ToneNote>[
        ToneNote(freqHz: 880, durationSec: 0.15, startOffsetSec: 0),
        ToneNote(freqHz: 880, durationSec: 0.15, startOffsetSec: 0.25),
        ToneNote(freqHz: 1320, durationSec: 0.40, startOffsetSec: 0.50),
      ],
    ),
    RestSoundProfile(
      id: 'bell',
      label: 'Bell',
      peak: 0.55,
      timbre: 'bell',
      notes: <ToneNote>[
        ToneNote(freqHz: 1319, durationSec: 0.90, startOffsetSec: 0),
        ToneNote(freqHz: 1047, durationSec: 1.30, startOffsetSec: 0.40),
      ],
    ),
    RestSoundProfile(
      id: 'beep',
      label: 'Sports Watch Beep',
      peak: 0.80,
      holdFraction: 0.8,
      timbre: 'bright',
      notes: <ToneNote>[
        ToneNote(freqHz: 1760, durationSec: 0.08, startOffsetSec: 0),
        ToneNote(freqHz: 1760, durationSec: 0.08, startOffsetSec: 0.13),
        ToneNote(freqHz: 1760, durationSec: 0.08, startOffsetSec: 0.40),
        ToneNote(freqHz: 1760, durationSec: 0.08, startOffsetSec: 0.53),
      ],
    ),
    RestSoundProfile(
      id: 'whistle',
      label: 'Coach Whistle',
      peak: 0.70,
      holdFraction: 0.55,
      notes: <ToneNote>[
        ToneNote(
          freqHz: 1300,
          durationSec: 0.16,
          startOffsetSec: 0,
          endFreqHz: 2100,
        ),
        ToneNote(
          freqHz: 1500,
          durationSec: 0.42,
          startOffsetSec: 0.22,
          endFreqHz: 2500,
        ),
      ],
    ),
    RestSoundProfile(
      id: 'soft',
      label: 'Soft',
      peak: 0.35,
      notes: <ToneNote>[
        ToneNote(freqHz: 659, durationSec: 0.40, startOffsetSec: 0),
        ToneNote(freqHz: 784, durationSec: 0.40, startOffsetSec: 0.20),
        ToneNote(freqHz: 988, durationSec: 0.80, startOffsetSec: 0.40),
      ],
    ),
  ];

  static RestSoundProfile profileFor(String id) {
    return restSounds.firstWhere(
      (s) => s.id == id,
      orElse: () => restSounds.first,
    );
  }

  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  AudioPlayer? _player;

  Uint8List _bytesFor(String key, List<ToneNote> Function() buildNotes,
      {double peak = 0.55, double hold = 0.0, String timbre = 'sine'}) {
    return _cache.putIfAbsent(
      key,
      () => WavSynthesizer.synthesize(
        buildNotes(),
        peak: peak,
        holdFraction: hold,
        timbre: timbre,
      ),
    );
  }

  Future<void> _playBytes(Uint8List bytes) async {
    try {
      _player ??= AudioPlayer();
      await _player!.stop();
      await _player!.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Safe no-op in headless unit tests or restricted audio environments.
    }
  }

  /// Plays the set-completion click (`1040 Hz`, `120 ms`) and optional haptic.
  Future<void> playSetTick({
    required bool soundEnabled,
    required bool hapticsEnabled,
  }) async {
    if (hapticsEnabled) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
    if (!soundEnabled) return;
    final bytes = _bytesFor(
      'set_tick',
      () => const <ToneNote>[ToneNote(freqHz: 1040, durationSec: 0.12)],
      peak: 0.38,
    );
    await _playBytes(bytes);
  }

  /// Plays the rising two-note PR celebration chime (`1320 Hz -> 1760 Hz`).
  Future<void> playPrChime({required bool soundEnabled}) async {
    if (!soundEnabled) return;
    final bytes = _bytesFor(
      'pr_chime',
      () => const <ToneNote>[
        ToneNote(freqHz: 1320, durationSec: 0.10, startOffsetSec: 0.14),
        ToneNote(freqHz: 1760, durationSec: 0.22, startOffsetSec: 0.26),
      ],
      peak: 0.55,
      timbre: 'bright',
    );
    await _playBytes(bytes);
  }

  /// Plays the 3-2-1 countdown tick (`660 Hz`, `100 ms`).
  Future<void> playCountdownTick({required bool soundEnabled}) async {
    if (!soundEnabled) return;
    final bytes = _bytesFor(
      'countdown_tick',
      () => const <ToneNote>[ToneNote(freqHz: 660, durationSec: 0.10)],
      peak: 0.40,
    );
    await _playBytes(bytes);
  }

  /// Plays the selected rest-end chime and heavy haptic buzz.
  Future<void> playRestEndChime({
    required String kind,
    required bool soundEnabled,
    required bool hapticsEnabled,
  }) async {
    if (hapticsEnabled) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
    if (!soundEnabled) return;
    final profile = profileFor(kind);
    final bytes = _bytesFor(
      'rest_${profile.id}',
      () => profile.notes,
      peak: profile.peak,
      hold: profile.holdFraction,
      timbre: profile.timbre,
    );
    await _playBytes(bytes);
  }

  /// Plays the rising 3-note fanfare when finishing a workout.
  Future<void> playWorkoutFinish({
    required bool soundEnabled,
    required bool hapticsEnabled,
  }) async {
    if (hapticsEnabled) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
    if (!soundEnabled) return;
    final bytes = _bytesFor(
      'workout_finish',
      () => const <ToneNote>[
        ToneNote(freqHz: 880, durationSec: 0.12, startOffsetSec: 0),
        ToneNote(freqHz: 1109, durationSec: 0.12, startOffsetSec: 0.13),
        ToneNote(freqHz: 1319, durationSec: 0.30, startOffsetSec: 0.26),
      ],
      peak: 0.55,
      timbre: 'bright',
    );
    await _playBytes(bytes);
  }

  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
