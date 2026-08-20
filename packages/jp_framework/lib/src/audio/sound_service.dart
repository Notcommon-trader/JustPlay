import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'sfx.dart';

export 'sfx.dart';

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

  final List<AudioPlayer> _players = [];
  int _next = 0;

  /// Whether the players are built and ready.
  ///
  /// Exposed so a caller can tell "no sound because it is off" from "no sound
  /// because it broke" — a distinction this class could not make when it shipped
  /// mute, twice.
  bool get isReady => _ready;
  bool _ready = false;

  /// Whatever went wrong during [initialise], kept rather than swallowed.
  ///
  /// Silence is the least debuggable failure there is: it looks exactly like
  /// working correctly with the volume down.
  Object? get lastError => _lastError;
  Object? _lastError;

  /// A small pool, cycled.
  ///
  /// One player cuts off its own previous sound, which is wrong when two things
  /// happen close together — a merge landing as a stage clears. Four is enough
  /// to overlap without a phone struggling to mix them.
  static const int _poolSize = 4;

  /// Folder holding the generated WAVs, **without** a leading `assets/`.
  ///
  /// audioplayers prepends its own `assets/` prefix before looking a source up,
  /// so passing `assets/sfx/win.wav` makes it search for
  /// `assets/assets/sfx/win.wav`. That is exactly what shipped: the files were
  /// present and correct in the APK, the lookup failed, the error went into
  /// [lastError], and nothing ever read it. Three silent releases came out of one
  /// duplicated path segment.
  ///
  /// [assetKey] exists so a test can check the *resolved* key against the bundle
  /// rather than the one handed to the plugin.
  static const String _folder = 'sfx';

  /// The bundle key a sound really resolves to, prefix included.
  static String assetKey(Sfx sound) => 'assets/$_folder/${sound.name}.wav';

  @override
  Future<void> initialise() async {
    if (_ready) return;

    for (var i = 0; i < _poolSize; i++) {
      _players.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
    }

    // Ready before the optional part, not after.
    //
    // The audio context is a nicety — it ducks a podcast instead of stopping it.
    // Previously it sat inside the same try block that set `_ready`, so a device
    // that refused the context left the whole app mute for the sake of a
    // courtesy. Failing to be polite is not a reason to be silent.
    _ready = true;

    try {
      for (final player in _players) {
        await player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.game,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
          ),
        );
      }
    } on Object catch (error) {
      _lastError = error;
    }
  }

  @override
  void play(Sfx sound) {
    if (haptics) _haptic(sound);
    if (!enabled || !_ready) return;

    final player = _players[_next];
    _next = (_next + 1) % _players.length;

    // Deliberately not awaited, but no longer silently swallowed: audio is the
    // least important thing on screen and must never throw into a game loop, and
    // a failure that leaves no trace is how this bug survived two releases.
    unawaited(
      player
          .play(AssetSource('$_folder/${sound.name}.wav'), volume: 0.6)
          .catchError((Object error) => _lastError = error),
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

  @override
  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
    _players.clear();
  }
}
