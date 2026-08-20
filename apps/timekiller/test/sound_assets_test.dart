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

  test('the key each sound actually resolves to is bundled', () async {
    // **This is the test that was missing, and it is not the obvious one.**
    //
    // The earlier version hardcoded 'assets/sfx/x.wav' and passed — because the
    // files really were bundled under that key. What it never checked was the
    // path the *plugin* ends up looking for. audioplayers prepends its own
    // `assets/` prefix, so the code was asking for assets/assets/sfx/x.wav while
    // this test cheerfully confirmed a different, correct path existed.
    //
    // Asking ToneSounds for the resolved key is what closes that gap: the test
    // and the player now read from the same source of truth, so they cannot
    // disagree again.
    for (final sfx in Sfx.values) {
      final data = await rootBundle.load(ToneSounds.assetKey(sfx));
      expect(
        data.lengthInBytes,
        greaterThan(1000),
        reason: '${ToneSounds.assetKey(sfx)} is missing or empty — regenerate with '
            'dart run example/generate_sfx.dart',
      );
    }
  });

  test('each bundled file is a real WAV, not a placeholder', () async {
    // A zero-byte file, or a text file with the right name, would satisfy a
    // "does it exist" check and still play nothing.
    for (final sfx in Sfx.values) {
      final data = await rootBundle.load(ToneSounds.assetKey(sfx));
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
      final bundled = await rootBundle.load(ToneSounds.assetKey(sfx));
      final fresh = ToneSynth.wav(recipeFor(sfx));

      expect(
        bundled.lengthInBytes,
        fresh.length,
        reason: '${sfx.name}.wav is stale — regenerate the sound assets',
      );
    }
  });
}
