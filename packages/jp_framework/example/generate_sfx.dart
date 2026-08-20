// A build-time generator whose entire job is to write files and report.
//
// The relative imports are deliberate and the lint is wrong here: a `package:`
// import of this library would resolve through jp_framework's public entry
// point, which pulls in the audio plugin and therefore the Flutter binding —
// and plain `dart run` cannot start one. Importing the two pure-Dart files
// directly is what makes this script runnable at all.
// ignore_for_file: avoid_print, avoid_relative_lib_imports

import 'dart:io';

// Imported by path, not through package:jp_framework. The package's public
// library pulls in the audio plugin and therefore the whole Flutter binding,
// which plain `dart run` cannot start. These two files are deliberately pure
// Dart so this script can run without one.
import '../lib/src/audio/sfx.dart';
import '../lib/src/audio/tone.dart';

/// Writes the app's sound effects as WAV files.
///
///   dart run example/generate_sfx.dart ../../apps/timekiller/assets/sfx
///
/// The tones are still generated rather than recorded — same arithmetic, same
/// zero licensing — but they are baked at build time and shipped as assets
/// rather than synthesised on first launch.
///
/// That is not a stylistic preference. Runtime generation put the audio path
/// behind a temporary directory, a file write and a plugin call, all inside an
/// un-awaited future during startup. Any one of them failing left the app
/// permanently and silently mute, which is exactly what shipped — twice. An
/// asset is either present or the build fails.
void main(List<String> args) {
  final target = args.isEmpty ? 'assets/sfx' : args.first;
  Directory(target).createSync(recursive: true);

  for (final sfx in Sfx.values) {
    final bytes = ToneSynth.wav(recipeFor(sfx));
    final file = File('$target/${sfx.name}.wav')..writeAsBytesSync(bytes);
    print('${file.path}  ${bytes.length} bytes');
  }

  print('\n${Sfx.values.length} sounds written to $target');
}
