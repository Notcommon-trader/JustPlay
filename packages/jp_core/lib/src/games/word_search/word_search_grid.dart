import 'dart:math';

/// A word placed into the grid, with the exact cells it occupies.
class PlacedWord {
  const PlacedWord({required this.word, required this.cells});

  final String word;

  /// Board indices the word runs through, in reading order.
  final List<int> cells;

  int get start => cells.first;
  int get end => cells.last;

  @override
  String toString() => '$word @ $start->$end';
}

/// Word search.
///
/// The generator is the whole game. Two rules govern it:
///
/// **Overlaps are allowed only where the letters already agree.** Words crossing
/// at a shared letter is what makes a grid feel dense and hand-made; overwriting
/// a letter to force a fit silently breaks whichever word was there first.
///
/// **Every placed word must be findable.** A word the generator claims to have
/// placed but which cannot be read off the grid makes the game unwinnable, and
/// the player has no way to know. [verifyPlacements] exists so tests can assert
/// that rather than trust it.
class WordSearchGrid {
  const WordSearchGrid._({
    required this.size,
    required this.letters,
    required this.words,
    required this.found,
  });

  /// All eight directions: the four orthogonals and the four diagonals.
  static const List<(int, int)> _directions = [
    (0, 1), (0, -1), (1, 0), (-1, 0), //
    (1, 1), (1, -1), (-1, 1), (-1, -1),
  ];

  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// Builds a grid containing as many of [words] as will fit.
  ///
  /// Words that cannot be placed after [attemptsPerWord] tries are dropped
  /// rather than forced. A dropped word is better than a corrupted grid, and the
  /// caller can see what actually made it in via [words].
  factory WordSearchGrid.generate({
    required List<String> words,
    int size = 10,
    Random? random,
    int attemptsPerWord = 200,
  }) {
    final rng = random ?? Random();
    final grid = List<String?>.filled(size * size, null);
    final placed = <PlacedWord>[];

    // Longest first. A long word has far fewer legal positions, so placing it
    // while the grid is empty is the difference between fitting and dropping it.
    final ordered = [...words.map((w) => w.toUpperCase())]
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final word in ordered) {
      if (word.length > size) continue;

      for (var attempt = 0; attempt < attemptsPerWord; attempt++) {
        final direction = _directions[rng.nextInt(_directions.length)];
        final row = rng.nextInt(size);
        final column = rng.nextInt(size);

        final cells = _cellsFor(word.length, row, column, direction, size);
        if (cells == null) continue;
        if (!_fits(grid, word, cells)) continue;

        for (var i = 0; i < word.length; i++) {
          grid[cells[i]] = word[i];
        }
        placed.add(PlacedWord(word: word, cells: cells));
        break;
      }
    }

    // Fill the gaps. Random letters rather than a fixed filler, so the eye
    // cannot pick out the words by texture alone.
    final letters = [
      for (var i = 0; i < grid.length; i++)
        grid[i] ?? _alphabet[rng.nextInt(_alphabet.length)],
    ];

    return WordSearchGrid._(
      size: size,
      letters: List<String>.unmodifiable(letters),
      words: List<PlacedWord>.unmodifiable(placed),
      found: const {},
    );
  }

  final int size;
  final List<String> letters;
  final List<PlacedWord> words;

  /// Words the player has already located.
  final Set<String> found;

  int get cellCount => letters.length;

  bool get isComplete => words.every((w) => found.contains(w.word));

  int get remainingCount => words.length - found.length;

  String letterAt(int row, int column) => letters[row * size + column];

  /// Cells belonging to words the player has found, for highlighting.
  Set<int> get foundCells => {
        for (final word in words)
          if (found.contains(word.word)) ...word.cells,
      };

  /// The straight line of cells from [from] to [to], or null if the two are not
  /// on a shared row, column or diagonal.
  ///
  /// This is what constrains selection to legal shapes — without it a player
  /// could drag any wandering path and match letters that do not form a line.
  List<int>? lineBetween(int from, int to) {
    if (from < 0 || from >= cellCount || to < 0 || to >= cellCount) return null;

    final fromRow = from ~/ size;
    final fromCol = from % size;
    final toRow = to ~/ size;
    final toCol = to % size;

    final rowDelta = toRow - fromRow;
    final colDelta = toCol - fromCol;

    if (rowDelta == 0 && colDelta == 0) return [from];

    final isStraight = rowDelta == 0 ||
        colDelta == 0 ||
        rowDelta.abs() == colDelta.abs();
    if (!isStraight) return null;

    final steps = max(rowDelta.abs(), colDelta.abs());
    final rowStep = rowDelta.sign;
    final colStep = colDelta.sign;

    return [
      for (var i = 0; i <= steps; i++)
        (fromRow + rowStep * i) * size + (fromCol + colStep * i),
    ];
  }

  /// The word matching a drag from [from] to [to], or null.
  ///
  /// Matches in either direction: a player who drags from the last letter to the
  /// first has still found the word, and refusing that is needless cruelty.
  PlacedWord? wordForSelection(int from, int to) {
    final line = lineBetween(from, to);
    if (line == null) return null;

    for (final word in words) {
      if (found.contains(word.word)) continue;
      if (word.cells.length != line.length) continue;

      final forward = _sameCells(word.cells, line);
      final backward = _sameCells(word.cells, line.reversed.toList());
      if (forward || backward) return word;
    }

    return null;
  }

  WordSearchGrid markFound(String word) {
    if (found.contains(word)) return this;
    return WordSearchGrid._(
      size: size,
      letters: letters,
      words: words,
      found: Set<String>.unmodifiable({...found, word}),
    );
  }

  /// Points awarded for finding [word].
  ///
  /// Linear in length, with a flat base. A long word is harder to spot but not
  /// exponentially so, and a quadratic scale would make the last two words worth
  /// more than the rest of the grid combined.
  static int pointsFor(String word) => 20 + word.length * 10;

  /// Reads every placed word back off the grid and checks it is really there.
  ///
  /// Exists so tests can prove the generator, rather than assuming it. A grid
  /// claiming a word it does not contain is unwinnable and invisible.
  bool verifyPlacements() {
    for (final placed in words) {
      final read = placed.cells.map((i) => letters[i]).join();
      if (read != placed.word) return false;
    }
    return true;
  }

  static List<int>? _cellsFor(
    int length,
    int row,
    int column,
    (int, int) direction,
    int size,
  ) {
    final (rowStep, colStep) = direction;
    final endRow = row + rowStep * (length - 1);
    final endCol = column + colStep * (length - 1);

    if (endRow < 0 || endRow >= size || endCol < 0 || endCol >= size) return null;

    return [
      for (var i = 0; i < length; i++)
        (row + rowStep * i) * size + (column + colStep * i),
    ];
  }

  /// A word fits where every cell is empty or already holds the same letter.
  static bool _fits(List<String?> grid, String word, List<int> cells) {
    for (var i = 0; i < word.length; i++) {
      final existing = grid[cells[i]];
      if (existing != null && existing != word[i]) return false;
    }
    return true;
  }

  static bool _sameCells(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        buffer.write('${letterAt(r, c)} ');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
