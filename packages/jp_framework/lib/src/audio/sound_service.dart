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

  /// Whether the service believes it can play anything.
  bool get isReady;

  /// The last failure, if any.
  Object? get lastError;

  /// Plays [sound] and **waits**, returning whatever went wrong or null.
  ///
  /// Part of the interface rather than a debug afterthought, because this class
  /// of bug is not visible any other way. Every audio failure so far produced
  /// silence, which is indistinguishable from working correctly with the volume
  /// down — so four broken builds passed every green test and reached a phone.
  /// A path that surfaces the exception is the only way to tell those apart.
  Future<Object?> playAndReport(Sfx sound);

  Future<void> dispose();
}

/// Silence. Used in tests, and when a player turns sound off.
class SilentSounds implements SoundService {
  @override
  bool enabled = false;

  @override
  bool get isReady => false;

  @override
  Object? get lastError => null;

  @override
  Future<void> initialise() async {}

  @override
  void play(Sfx sound) {}

  @override
  Future<Object?> playAndReport(Sfx sound) async => 'sound is disabled';

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
  @override
  bool get isReady => _ready;
  bool _ready = false;

  /// Whatever went wrong during [initialise], kept rather than swallowed.
  ///
  /// Silence is the least debuggable failure there is: it looks exactly like
  /// working correctly with the volume down.
  @override
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

    // No custom AudioContext.
    //
    // The previous version asked for contentType sonification with a ducking
    // focus request, which on Android can route a sound somewhere other than the
    // media stream — audible in theory, silent in practice, and reported as a
    // successful play either way. The plugin's default is ordinary media
    // playback, which is the well-trodden path. Politeness towards other audio
    // is not worth a fifth silent release.
    _ready = true;
  }

  /// How many sounds the app has asked for, and how many were dropped.
  ///
  /// Counters rather than logs, because the question is asked *after* a game —
  /// the player comes back to the sound check and it says whether anything was
  /// requested at all. That distinguishes "the games never called play" from
  /// "play was called and refused" from "it played and you could not hear it",
  /// which no amount of listening can.
  int get requested => _requested;
  int _requested = 0;

  int get dropped => _dropped;
  int _dropped = 0;

  Sfx? get lastRequested => _lastRequested;
  Sfx? _lastRequested;

  @override
  void play(Sfx sound) {
    _requested++;
    _lastRequested = sound;

    if (haptics) _haptic(sound);

    // **No `_ready` check.**
    //
    // This gate is why the sound-check button worked while the games stayed
    // mute: playAndReport only ever required a player to exist, while this path
    // also demanded a flag that the diagnostic never consulted. Two code paths
    // to the same speaker, with different preconditions, and only one of them
    // was being tested. The condition that actually matters is whether there is
    // a player to play through.
    if (!enabled || _players.isEmpty) {
      _dropped++;
      return;
    }

    final player = _players[_next];
    _next = (_next + 1) % _players.length;

    // Deliberately not awaited, but no longer silently swallowed: audio is the
    // least important thing on screen and must never throw into a game loop, and
    // a failure that leaves no trace is how this bug survived two releases.
    unawaited(
      player
          .play(AssetSource('$_folder/${sound.name}.wav'), volume: 1)
          .catchError((Object error) => _lastError = error),
    );
  }

  @override
  Future<Object?> playAndReport(Sfx sound) async {
    if (_players.isEmpty) {
      return 'no audio players were created; initialise() ran: $_ready'
          '${_lastError == null ? '' : ', last error: $_lastError'}';
    }

    try {
      // Awaited, unlike [play]. The whole point is to see the exception rather
      // than let it disappear into a future nobody holds.
      await _players.first.play(
        AssetSource('$_folder/${sound.name}.wav'),
        volume: 1,
      );
      return null;
    } on Object catch (error) {
      _lastError = error;
      return error;
    }
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
