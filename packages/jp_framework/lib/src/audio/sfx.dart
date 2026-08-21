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
/// Levels sit near full scale. The first version peaked around -13dB once the
/// player's own 0.6 multiplier and the envelope were applied, which on a phone
/// speaker is close to inaudible - the platform reported a successful play and
/// nothing was heard. Loud is recoverable with a volume control; inaudible reads
/// as broken.
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
    // 110ms, not 40.
    //
    // Forty milliseconds is shorter than a camera shutter click. The emulator
    // log confirmed the platform delivering exactly 1764 frames — the whole
    // sound — for a real tile move, so the pipeline was working perfectly and
    // still produced nothing anyone would call audio. Most games fire only this
    // one sound during play, so if the move sound is imperceptible the app is
    // silent in practice however healthy the plumbing.
    //
    // Two tones a fifth apart rather than one: a single pure tone at this length
    // reads as a beep, while a tiny interval reads as a click with pitch to it.
    Sfx.tap => const [
        Tone(hz: g5, milliseconds: 45, volume: 0.80),
        Tone(hz: c6, milliseconds: 65, volume: 0.70),
      ],
    Sfx.gain => const [
        Tone(hz: e5, milliseconds: 55, volume: 0.90),
        Tone(hz: a5, milliseconds: 75, volume: 0.88),
      ],
    // Down a step and soft-edged. A refusal should read as "not that"
    // rather than as a punishment.
    Sfx.reject => const [
        Tone(hz: 220, milliseconds: 90, volume: 0.75, wave: Wave.triangle),
      ],
    Sfx.win => const [
        Tone(hz: c5, milliseconds: 80, volume: 0.92),
        Tone(hz: e5, milliseconds: 80, volume: 0.92),
        Tone(hz: g5, milliseconds: 80, volume: 0.92),
        Tone(hz: c6, milliseconds: 220, volume: 1.0),
      ],
    // Falling, in a minor third — the interval every culture reads as
    // disappointment. Short, so it never feels like being told off.
    Sfx.lose => const [
        Tone(hz: d5, milliseconds: 110, volume: 0.80, wave: Wave.triangle),
        Tone(hz: 392, milliseconds: 170, volume: 0.78, wave: Wave.triangle),
      ],
    Sfx.star => const [Tone(hz: c6, milliseconds: 90, volume: 0.92)],
  };
}
