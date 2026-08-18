import 'dart:math';
import 'dart:typed_data';

/// A note in a generated sound.
class Tone {
  const Tone({
    required this.hz,
    required this.milliseconds,
    this.volume = 0.5,
    this.wave = Wave.sine,
  });

  final double hz;
  final int milliseconds;

  /// 0–1, before the envelope.
  final double volume;

  final Wave wave;
}

/// Timbre. Sine is soft and neutral; triangle has a little edge without the
/// harshness of a square, which on a phone speaker turns into a buzz.
enum Wave { sine, triangle }

/// Builds playable WAV audio from arithmetic.
///
/// **No sound files ship with the app.** Every effect is a few hundred bytes of
/// generated PCM, which means nothing to license, nothing to attribute, nothing
/// added to the download, and a tone that can be retuned by changing a number
/// rather than by finding a new recording.
///
/// The trade is honest: this produces clean synthetic tones, not designed sound
/// effects. It is the difference between a tuned instrument and a foley studio.
/// Good enough that a win feels like something happened, and worth replacing
/// with recorded audio if the app ever earns the budget for it.
abstract final class ToneSynth {
  static const int _sampleRate = 44100;

  /// Renders [tones] in sequence as a mono 16-bit WAV.
  static Uint8List wav(List<Tone> tones) {
    final samples = <int>[];

    for (final tone in tones) {
      final count = (_sampleRate * tone.milliseconds / 1000).round();

      for (var i = 0; i < count; i++) {
        final t = i / _sampleRate;
        final phase = 2 * pi * tone.hz * t;

        final raw = switch (tone.wave) {
          Wave.sine => sin(phase),
          // A triangle from the sine's arcsine: cheap, and free of the aliasing
          // a naive sawtooth produces at these frequencies.
          Wave.triangle => 2 / pi * asin(sin(phase)),
        };

        // An envelope on every tone, without exception.
        //
        // A tone that starts and stops at full amplitude clicks at both ends —
        // the speaker is being asked to jump instantly — and a string of clicks
        // is exactly what makes generated audio sound cheap.
        final envelope = _envelope(i, count);
        final value = raw * tone.volume * envelope;

        samples.add((value * 32767).clamp(-32768, 32767).round());
      }
    }

    return _encode(samples);
  }

  /// Quick attack, gentle decay. Percussive enough to feel like a response to a
  /// tap rather than a note being held.
  static double _envelope(int i, int count) {
    const attack = 0.02;
    final position = i / count;

    if (position < attack) return position / attack;
    return pow(1 - (position - attack) / (1 - attack), 1.8).toDouble();
  }

  static Uint8List _encode(List<int> samples) {
    const channels = 1;
    const bitsPerSample = 16;
    final dataBytes = samples.length * 2;

    final bytes = BytesBuilder();

    void ascii(String s) => bytes.add(s.codeUnits);
    void uint32(int v) =>
        bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
    void uint16(int v) =>
        bytes.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

    ascii('RIFF');
    uint32(36 + dataBytes);
    ascii('WAVE');

    ascii('fmt ');
    uint32(16);
    uint16(1); // PCM
    uint16(channels);
    uint32(_sampleRate);
    uint32(_sampleRate * channels * bitsPerSample ~/ 8); // byte rate
    uint16(channels * bitsPerSample ~/ 8); // block align
    uint16(bitsPerSample);

    ascii('data');
    uint32(dataBytes);

    final pcm = Uint8List(dataBytes);
    final view = pcm.buffer.asByteData();
    for (var i = 0; i < samples.length; i++) {
      view.setInt16(i * 2, samples[i], Endian.little);
    }
    bytes.add(pcm);

    return bytes.toBytes();
  }
}
