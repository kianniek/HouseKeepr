import 'dart:math' as math;
import 'dart:typed_data';

/// Specification for a single synthesized note in a sequence.
class ToneNote {
  const ToneNote({
    required this.freqHz,
    required this.durationSec,
    this.startOffsetSec = 0,
    this.endFreqHz,
  });

  final double freqHz;
  final double durationSec;
  final double startOffsetSec;
  final double? endFreqHz;
}

/// Pure-Dart 44.1 kHz 16-bit mono PCM WAV synthesizer.
///
/// Mirrors the harmonic timbres (`bright`, `bell`, `sine`) and note sequences
/// from `openGym` `sound.js` and `rest-sounds.js` without needing external audio
/// asset files.
class WavSynthesizer {
  WavSynthesizer._();

  static const int sampleRate = 44100;

  static const Map<String, List<double>> timbres = <String, List<double>>{
    'sine': <double>[1.0],
    'bright': <double>[1.0, 0.6, 0.35, 0.2],
    'bell': <double>[1.0, 0.25, 0.5, 0.1, 0.3],
  };

  /// Synthesizes [notes] into an in-memory WAV byte buffer.
  static Uint8List synthesize(
    List<ToneNote> notes, {
    double peak = 0.55,
    double holdFraction = 0.0,
    String timbre = 'sine',
  }) {
    if (notes.isEmpty) return Uint8List(44);

    double totalSec = 0;
    for (final n in notes) {
      final end = n.startOffsetSec + n.durationSec;
      if (end > totalSec) totalSec = end;
    }

    final totalSamples = (totalSec * sampleRate).ceil().clamp(1, sampleRate * 10);
    final mix = Float64List(totalSamples);
    final harmonics = timbres[timbre] ?? timbres['sine']!;
    final harmonicSum = harmonics.fold<double>(0, (s, h) => s + h);

    for (final note in notes) {
      final startSample = (note.startOffsetSec * sampleRate).round();
      final noteSamples = (note.durationSec * sampleRate).round();
      if (noteSamples <= 0) continue;

      final attackSamples = (0.015 * sampleRate).round().clamp(1, noteSamples);
      final holdEndSample = (noteSamples * holdFraction).round();

      double phase = 0;
      for (var i = 0; i < noteSamples; i++) {
        final idx = startSample + i;
        if (idx < 0 || idx >= totalSamples) continue;

        final tNorm = i / noteSamples;
        final freq = note.endFreqHz != null
            ? note.freqHz + (note.endFreqHz! - note.freqHz) * tNorm
            : note.freqHz;

        phase += 2 * math.pi * freq / sampleRate;

        double wave = 0;
        for (var h = 0; h < harmonics.length; h++) {
          wave += harmonics[h] * math.sin(phase * (h + 1));
        }
        wave /= harmonicSum;

        double env;
        if (i < attackSamples) {
          env = i / attackSamples;
        } else if (i < holdEndSample) {
          env = 1.0;
        } else {
          final decayLen = (noteSamples - math.max(attackSamples, holdEndSample))
              .clamp(1, noteSamples);
          final decayPos = i - math.max(attackSamples, holdEndSample);
          env = math.pow(0.002, decayPos / decayLen).toDouble();
        }

        mix[idx] += wave * peak * env;
      }
    }

    final byteData = ByteData(44 + totalSamples * 2);
    // RIFF header
    byteData.setUint8(0, 0x52); // R
    byteData.setUint8(1, 0x49); // I
    byteData.setUint8(2, 0x46); // F
    byteData.setUint8(3, 0x46); // F
    byteData.setUint32(4, 36 + totalSamples * 2, Endian.little);
    byteData.setUint8(8, 0x57); // W
    byteData.setUint8(9, 0x41); // A
    byteData.setUint8(10, 0x56); // V
    byteData.setUint8(11, 0x45); // E
    // fmt chunk
    byteData.setUint8(12, 0x66); // f
    byteData.setUint8(13, 0x6D); // m
    byteData.setUint8(14, 0x74); // t
    byteData.setUint8(15, 0x20); // space
    byteData.setUint32(16, 16, Endian.little); // PCM chunk size
    byteData.setUint16(20, 1, Endian.little); // PCM format
    byteData.setUint16(22, 1, Endian.little); // mono
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    byteData.setUint16(32, 2, Endian.little); // block align
    byteData.setUint16(34, 16, Endian.little); // bits per sample
    // data chunk
    byteData.setUint8(36, 0x64); // d
    byteData.setUint8(37, 0x61); // a
    byteData.setUint8(38, 0x74); // t
    byteData.setUint8(39, 0x61); // a
    byteData.setUint32(40, totalSamples * 2, Endian.little);

    for (var i = 0; i < totalSamples; i++) {
      final clamped = mix[i].clamp(-1.0, 1.0);
      byteData.setInt16(44 + i * 2, (clamped * 32767).round(), Endian.little);
    }

    return byteData.buffer.asUint8List();
  }
}
