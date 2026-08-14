import 'dart:math';

/// A themed set of words to hide in a grid.
///
/// Themed rather than a general dictionary because a grid whose words share a
/// subject is measurably easier to scan — the player primes on the category and
/// the letters start to suggest candidates. A random sample from a dictionary
/// also produces obscure words nobody can spot, which reads as unfair rather
/// than hard.
class WordPack {
  const WordPack({required this.id, required this.name, required this.words});

  final String id;

  /// Shown to the player as the puzzle's subject.
  final String name;

  final List<String> words;

  /// Picks [count] distinct words, biased toward nothing in particular.
  ///
  /// Words longer than [maxLength] are excluded outright: a word that cannot fit
  /// the grid would be silently dropped by the generator, and the player would
  /// see a list entry they can never find.
  List<String> sample(int count, {required int maxLength, Random? random}) {
    final rng = random ?? Random();
    final pool = [
      for (final word in words)
        if (word.length <= maxLength) word,
    ]..shuffle(rng);

    return pool.take(count).toList();
  }
}

/// Every pack that ships. Words are 3–9 letters so they fit a 10×10 grid.
const List<WordPack> wordPacks = [
  WordPack(
    id: 'animals',
    name: 'Animals',
    words: [
      'TIGER', 'PANDA', 'OTTER', 'FALCON', 'GECKO', 'WALRUS', 'BADGER',
      'JACKAL', 'IGUANA', 'MEERKAT', 'PELICAN', 'DOLPHIN', 'GIRAFFE',
      'LEOPARD', 'OSTRICH', 'RACCOON', 'ANTELOPE', 'PORPOISE', 'HEDGEHOG',
      'MONGOOSE', 'WOMBAT', 'LEMUR', 'BISON', 'MOOSE', 'CRANE',
    ],
  ),
  WordPack(
    id: 'food',
    name: 'Food',
    words: [
      'MANGO', 'OLIVE', 'BASIL', 'PEPPER', 'WALNUT', 'GINGER', 'LENTIL',
      'PAPRIKA', 'AVOCADO', 'APRICOT', 'CABBAGE', 'PUMPKIN', 'NOODLE',
      'PASTRY', 'SAFFRON', 'CARDAMOM', 'CINNAMON', 'TAMARIND', 'PISTACHIO',
      'ALMOND', 'CHERRY', 'RADISH', 'TURMERIC', 'VANILLA',
    ],
  ),
  WordPack(
    id: 'space',
    name: 'Space',
    words: [
      'COMET', 'ORBIT', 'LUNAR', 'SOLAR', 'PLANET', 'GALAXY', 'METEOR',
      'NEBULA', 'PULSAR', 'QUASAR', 'ECLIPSE', 'GRAVITY', 'STELLAR',
      'ASTEROID', 'TELESCOPE', 'SATURN', 'NEPTUNE', 'VENUS', 'COSMOS',
      'CRATER', 'ROCKET', 'SHUTTLE', 'AURORA', 'PHOTON',
    ],
  ),
  WordPack(
    id: 'weather',
    name: 'Weather',
    words: [
      'CLOUD', 'STORM', 'FROST', 'HUMID', 'BREEZE', 'THUNDER', 'DRIZZLE',
      'MONSOON', 'CYCLONE', 'BLIZZARD', 'RAINBOW', 'SUNRISE', 'TEMPEST',
      'HAILSTONE', 'OVERCAST', 'SLEET', 'GUSTY', 'MIST', 'SQUALL',
      'TYPHOON', 'DROUGHT', 'TORNADO', 'ICICLE', 'VAPOUR',
    ],
  ),
  WordPack(
    id: 'music',
    name: 'Music',
    words: [
      'TEMPO', 'CHORD', 'SCALE', 'BANJO', 'VIOLIN', 'GUITAR', 'RHYTHM',
      'MELODY', 'HARMONY', 'OCTAVE', 'SONATA', 'CONCERT', 'TRUMPET',
      'CLARINET', 'ORCHESTRA', 'CYMBAL', 'ENCORE', 'LYRIC', 'BALLAD',
      'TREBLE', 'MINOR', 'MAJOR', 'PIANO', 'FLUTE',
    ],
  ),
];

/// The pack matching [id], or the first pack if there is no such id.
WordPack packById(String id) =>
    wordPacks.firstWhere((p) => p.id == id, orElse: () => wordPacks.first);
