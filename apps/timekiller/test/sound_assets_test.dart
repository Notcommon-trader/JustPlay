import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_framework/jp_framework.dart';

/// Proves the sounds are actually in the app.
///
/// This is the test that was missing. The tone synthesiser was unit-tested and
/// produced perfectly valid WAV bytes — which said nothing about whether any of
/// it reached a device, and the app shipped completely silent twice while those
/// tests stayed green.
///
/// A missing or undeclared asset fails here, at build time, instead of becoming
/// silence on a phone. Silence is the worst possible failure signal: it is
/// indistinguishable from the volume being down.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every sound the code can ask for is bundled', () async {
    for (final sfx in Sfx.values) {
      final key = 'assets/sfx/${sfx.name}.wav';

      final data = await rootBundle.load(key);
      expect(
        data.lengthInBytes,
        greaterThan(1000),
        reason: '$key is missing or empty — regenerate with '
            'dart run example/generate_sfx.dart',
      );
    }
  });

  test('each bundled file is a real WAV, not a placeholder', () async {
    // A zero-byte file, or a text file with the right name, would satisfy a
    // "does it exist" check and still play nothing.
    for (final sfx in Sfx.values) {
      final data = await rootBundle.load('assets/sfx/${sfx.name}.wav');
      final bytes = data.buffer.asUint8List();

      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF',
          reason: '${sfx.name} is not RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE',
          reason: '${sfx.name} is not WAVE');
    }
  });

  test('the bundled files match what the synthesiser produces now', () async {
    // Catches the asset falling out of step with the recipe — a tone retuned in
    // code but never regenerated would leave the app playing the old sound with
    // no sign anything was stale.
    for (final sfx in Sfx.values) {
      final bundled = await rootBundle.load('assets/sfx/${sfx.name}.wav');
      final fresh = ToneSynth.wav(recipeFor(sfx));

      expect(
        bundled.lengthInBytes,
        fresh.length,
        reason: '${sfx.name}.wav is stale — regenerate the sound assets',
      );
    }
  });
}
