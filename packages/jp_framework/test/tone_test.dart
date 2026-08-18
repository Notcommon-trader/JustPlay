import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jp_framework/jp_framework.dart';

String ascii(Uint8List bytes, int start, int length) =>
    String.fromCharCodes(bytes.sublist(start, start + length));

int uint32(Uint8List bytes, int offset) =>
    bytes.buffer.asByteData().getUint32(offset, Endian.little);

int uint16(Uint8List bytes, int offset) =>
    bytes.buffer.asByteData().getUint16(offset, Endian.little);

void main() {
  group('the WAV container', () {
    // A malformed header does not throw — the device simply plays nothing, and
    // silence is indistinguishable from "sound is off". So the bytes get checked
    // here rather than discovered on a phone.
    final wav = ToneSynth.wav(const [Tone(hz: 440, milliseconds: 100)]);

    test('is RIFF/WAVE', () {
      expect(ascii(wav, 0, 4), 'RIFF');
      expect(ascii(wav, 8, 4), 'WAVE');
      expect(ascii(wav, 12, 4), 'fmt ');
      expect(ascii(wav, 36, 4), 'data');
    });

    test('declares mono 16-bit PCM at 44.1kHz', () {
      expect(uint16(wav, 20), 1, reason: 'format should be PCM');
      expect(uint16(wav, 22), 1, reason: 'channels');
      expect(uint32(wav, 24), 44100, reason: 'sample rate');
      expect(uint16(wav, 34), 16, reason: 'bits per sample');
    });

    test('declares sizes that match the bytes actually present', () {
      // The one field that is easy to get wrong and impossible to hear.
      expect(uint32(wav, 4), wav.length - 8, reason: 'RIFF chunk size');
      expect(uint32(wav, 40), wav.length - 44, reason: 'data chunk size');
    });

    test('holds the right number of samples for its duration', () {
      // 100ms at 44100Hz, 2 bytes each.
      expect(uint32(wav, 40), 44100 * 100 ~/ 1000 * 2);
    });
  });

  group('the waveform', () {
    test('starts and ends near silence', () {
      // A tone that begins at full amplitude clicks, and a string of clicks is
      // what makes generated audio sound cheap.
      final wav = ToneSynth.wav(const [Tone(hz: 440, milliseconds: 200)]);
      final data = wav.buffer.asByteData();

      final first = data.getInt16(44, Endian.little);
      final last = data.getInt16(wav.length - 2, Endian.little);

      expect(first.abs(), lessThan(500), reason: 'attack should ramp in');
      expect(last.abs(), lessThan(500), reason: 'release should ramp out');
    });

    test('actually contains sound', () {
      final wav = ToneSynth.wav(const [Tone(hz: 440, milliseconds: 100)]);
      final data = wav.buffer.asByteData();

      var peak = 0;
      for (var i = 44; i < wav.length - 1; i += 2) {
        peak = peak > data.getInt16(i, Endian.little).abs()
            ? peak
            : data.getInt16(i, Endian.little).abs();
      }

      expect(peak, greaterThan(1000), reason: 'the tone is silent');
    });

    test('never clips', () {
      // Two loud tones at once is where a synthesised sound turns into a buzz.
      final wav = ToneSynth.wav(const [
        Tone(hz: 440, milliseconds: 50, volume: 1),
        Tone(hz: 880, milliseconds: 50, volume: 1, wave: Wave.triangle),
      ]);
      final data = wav.buffer.asByteData();

      for (var i = 44; i < wav.length - 1; i += 2) {
        expect(data.getInt16(i, Endian.little).abs(), lessThanOrEqualTo(32767));
      }
    });

    test('a sequence is as long as its parts combined', () {
      final one = ToneSynth.wav(const [Tone(hz: 440, milliseconds: 100)]);
      final three = ToneSynth.wav(const [
        Tone(hz: 440, milliseconds: 100),
        Tone(hz: 550, milliseconds: 100),
        Tone(hz: 660, milliseconds: 100),
      ]);

      expect(uint32(three, 40), uint32(one, 40) * 3);
    });
  });

  group('the silent service', () {
    test('plays nothing and never throws', () async {
      // Every test in the app runs against this; it has to be inert.
      final sounds = SilentSounds();
      await sounds.initialise();

      for (final sfx in Sfx.values) {
        sounds.play(sfx);
      }

      expect(sounds.enabled, isFalse);
      await sounds.dispose();
    });
  });
}
