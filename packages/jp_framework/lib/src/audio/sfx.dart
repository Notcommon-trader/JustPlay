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

/// The sounds themselves.
///
/// **Pure Dart, with no Flutter import anywhere in this file or [tone.dart].**
/// That is what lets the build-time generator run under plain `dart run` — the
/// first attempt put these next to the audio plugin, and the generator could not
/// execute at all because importing it dragged in the whole Flutter binding.
///
/// Tuned to a pentatonic scale, which is why they sit together rather than
/// clashing: on a five-note scale there is no combination that sounds wrong, so
/// sounds landing on top of each other stay pleasant.
List<Tone> recipeFor(Sfx sound) {
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
    // Falling, in a minor third — the interval every culture reads as
    // disappointment. Short, so it never feels like being told off.
    Sfx.lose => const [
        Tone(hz: d5, milliseconds: 110, volume: 0.26, wave: Wave.triangle),
        Tone(hz: 392, milliseconds: 170, volume: 0.24, wave: Wave.triangle),
      ],
    Sfx.star => const [Tone(hz: c6, milliseconds: 90, volume: 0.34)],
  };
}
