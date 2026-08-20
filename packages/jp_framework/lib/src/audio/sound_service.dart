import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'tone.dart';

/// Every sound the app makes.
///
/// A closed set, deliberately. A game that plays a slightly different noise at
/// forty different moments sounds like noise; the same six sounds, used
/// consistently, become a language a player stops noticing and starts relying
/// on.
enum Sfx {
  /// A move landed. The most frequent sound in the app, so the quietest and
  /// shortest — anything characterful becomes unbearable by the hundredth time.
  tap,

  /// Something good happened mid-game: a merge, a matched pair, a found word.
  gain,

  /// A move was refused.
  reject,

  /// A stage or game was cleared.
  win,

  /// A stage was failed.
  lose,

  /// A star was awarded. Played once per star, in sequence.
  star,
}

/// Plays the app's sounds.
abstract class SoundService {
  Future<void> initialise();

  /// Fire and forget: a sound that fails must never interrupt a game.
  void play(Sfx sound);

  bool get enabled;
  set enabled(bool value);

  Future<void> dispose();
}

/// Silence. Used in tests, and when a player turns sound off.
class SilentSounds implements SoundService {
  @override
  bool enabled = false;

  @override
  Future<void> initialise() async {}

  @override
  void play(Sfx sound) {}

  @override
  Future<void> dispose() async {}
}

/// Generated tones, plus haptics.
///
/// Haptics matter as much as the audio here and cost nothing: a player with the
/// phone on silent — which is most players, most of the time — still feels the
/// difference between a move that worked and one that did not.
class ToneSounds implements SoundService {
  ToneSounds({this.haptics = true});

  final bool haptics;

  @override
  bool enabled = true;

  /// Paths to the generated WAV files, one per sound.
  ///
  /// Files rather than raw bytes. The first version played a `BytesSource` in
  /// `PlayerMode.lowLatency`, and on Android that mode is backed by SoundPool,
  /// which will not take a byte buffer — so every call failed silently and the
  /// app shipped completely mute. A failure that produces silence is
  /// indistinguishable from "sound is switched off", which is why it survived
  /// all the way to a device.
  final Map<Sfx, String> _files = {};

  final List<AudioPlayer> _players = [];
  int _next = 0;

  /// Whether [initialise] actually got as far as writing playable files.
  ///
  /// Exposed so a caller can tell "no sound because it is off" from "no sound
  /// because it broke" — the distinction this class previously could not make.
  bool get isReady => _ready;
  bool _ready = false;

  /// A small pool, cycled.
  ///
  /// One player cuts off its own previous sound, which is wrong when two things
  /// happen close together — a merge landing as a stage clears. Four is enough
  /// to overlap without a phone struggling to mix them.
  static const int _poolSize = 4;

  @override
  Future<void> initialise() async {
    if (_ready) return;

    final directory = await getTemporaryDirectory();

    for (final sound in Sfx.values) {
      final file = File('${directory.path}/jp_${sound.name}.wav');
      await file.writeAsBytes(ToneSynth.wav(_recipe(sound)), flush: true);
      _files[sound] = file.path;
    }

    for (var i = 0; i < _poolSize; i++) {
      _players.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
    }

    _ready = true;
  }

  @override
  void play(Sfx sound) {
    if (haptics) _haptic(sound);
    if (!enabled || !_ready) return;

    final path = _files[sound];
    if (path == null) return;

    final player = _players[_next];
    _next = (_next + 1) % _players.length;

    // Deliberately not awaited, and deliberately swallowing failures. Audio is
    // the least important thing happening on screen; a device with no audio
    // route, or one that refuses to play during a call, must not throw into a
    // game loop.
    unawaited(
      player.play(DeviceFileSource(path), volume: 0.6).catchError((Object _) {}),
    );
  }

  void _haptic(Sfx sound) {
    switch (sound) {
      case Sfx.tap:
        unawaited(HapticFeedback.selectionClick().catchError((Object _) {}));
      case Sfx.gain:
      case Sfx.star:
        unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
      case Sfx.win:
        unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
      case Sfx.reject:
      case Sfx.lose:
        unawaited(HapticFeedback.heavyImpact().catchError((Object _) {}));
    }
  }

  /// The sounds themselves.
  ///
  /// Tuned to a pentatonic scale, which is why they sit together rather than
  /// clashing: on a five-note scale there is no combination that sounds wrong,
  /// so sounds landing on top of each other stay pleasant.
  static List<Tone> _recipe(Sfx sound) {
    const c5 = 523.25;
    const d5 = 587.33;
    const e5 = 659.25;
    const g5 = 783.99;
    const a5 = 880.00;
    const c6 = 1046.50;

    return switch (sound) {
      Sfx.tap => const [Tone(hz: g5, milliseconds: 40, volume: 0.22)],
      Sfx.gain => const [
          Tone(hz: e5, milliseconds: 55, volume: 0.32),
          Tone(hz: a5, milliseconds: 75, volume: 0.30),
        ],
      // Down a step, quiet, and soft-edged. A refusal should read as "not that"
      // rather than as a punishment.
      Sfx.reject => const [
          Tone(hz: 220, milliseconds: 90, volume: 0.22, wave: Wave.triangle),
        ],
      Sfx.win => const [
          Tone(hz: c5, milliseconds: 80, volume: 0.34),
          Tone(hz: e5, milliseconds: 80, volume: 0.34),
          Tone(hz: g5, milliseconds: 80, volume: 0.34),
          Tone(hz: c6, milliseconds: 220, volume: 0.38),
        ],
      // Falling, and in a minor third, which is the interval every culture reads
      // as disappointment. Short, so it never feels like being told off.
      Sfx.lose => const [
          Tone(hz: d5, milliseconds: 110, volume: 0.26, wave: Wave.triangle),
          Tone(hz: 392, milliseconds: 170, volume: 0.24, wave: Wave.triangle),
        ],
      Sfx.star => const [Tone(hz: c6, milliseconds: 90, volume: 0.34)],
    };
  }

  @override
  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
    _players.clear();
  }
}
