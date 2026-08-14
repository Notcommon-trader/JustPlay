import 'dart:math';

/// What the player has done to a cell.
enum NonogramMark {
  /// Untouched.
  blank,

  /// Claimed as part of the picture.
  filled,

  /// Ruled out. Bookkeeping only — crosses never affect whether the puzzle is
  /// solved, but solving a nonogram without them is close to impossible.
  crossed,
}

/// Nonogram (picross).
///
/// **A nonogram is solved when every row and column matches its clues** — not
/// when the player's grid equals the one the generator happened to draw.
/// Comparing against the stored solution would reject a genuinely correct answer
/// on any puzzle with more than one, and the player would have no way to tell
/// what they had done wrong. [isSolved] therefore re-derives the clues from what
/// the player has filled and compares those.
///
/// Separately, [generate] only ships puzzles a line solver can finish from
/// blank. A puzzle that needs a guess is not a harder puzzle, it is a coin
/// flip — and the player cannot distinguish the two, so they blame themselves.
class NonogramPuzzle {
  const NonogramPuzzle._({
    required this.columns,
    required this.rows,
    required this.rowClues,
    required this.columnClues,
    required this.marks,
  });

  /// Builds a puzzle that is solvable by line logic alone.
  ///
  /// [density] is the share of cells filled in the generated picture. Around
  /// half is where nonograms read best: much sparser and the clues are all ones,
  /// much denser and every row is a single long run.
  ///
  /// If no attempt produces a line-solvable picture the last candidate is
  /// returned anyway rather than looping forever. That is a real (if unlikely)
  /// outcome, not a promise — [isLineSolvable] lets tests measure how often it
  /// happens instead of assuming.
  factory NonogramPuzzle.generate({
    int columns = 10,
    int rows = 10,
    Random? random,
    double density = 0.55,
    int attempts = 60,
  }) {
    final rng = random ?? Random();
    late List<bool> picture;

    for (var attempt = 0; attempt < attempts; attempt++) {
      picture = _drawPicture(columns, rows, density, rng);
      final rowClues = _cluesForRows(picture, columns, rows);
      final columnClues = _cluesForColumns(picture, columns, rows);

      if (isLineSolvable(
        rowClues: rowClues,
        columnClues: columnClues,
        columns: columns,
        rows: rows,
      )) {
        return NonogramPuzzle._(
          columns: columns,
          rows: rows,
          rowClues: rowClues,
          columnClues: columnClues,
          marks: List<NonogramMark>.filled(columns * rows, NonogramMark.blank),
        );
      }
    }

    return NonogramPuzzle._(
      columns: columns,
      rows: rows,
      rowClues: _cluesForRows(picture, columns, rows),
      columnClues: _cluesForColumns(picture, columns, rows),
      marks: List<NonogramMark>.filled(columns * rows, NonogramMark.blank),
    );
  }

  /// Builds the puzzle whose answer is [picture], read row by row.
  ///
  /// The generator uses random pictures, but a fixed one is what makes the rules
  /// testable — and a hand-drawn picture is how a themed puzzle pack would be
  /// authored later.
  factory NonogramPuzzle.fromPicture({
    required List<bool> picture,
    required int columns,
  }) {
    final rows = picture.length ~/ columns;
    return NonogramPuzzle._(
      columns: columns,
      rows: rows,
      rowClues: _cluesForRows(picture, columns, rows),
      columnClues: _cluesForColumns(picture, columns, rows),
      marks: List<NonogramMark>.filled(columns * rows, NonogramMark.blank),
    );
  }

  final int columns;
  final int rows;

  /// Run lengths for each row, top to bottom. An empty line is `[0]` so the UI
  /// always has something to draw.
  final List<List<int>> rowClues;

  final List<List<int>> columnClues;

  final List<NonogramMark> marks;

  int get cellCount => marks.length;

  int indexOf(int row, int column) => row * columns + column;

  NonogramMark markAt(int row, int column) => marks[indexOf(row, column)];

  /// Cycles blank → filled → crossed → blank.
  ///
  /// One control for both states. A separate fill/cross mode toggle costs a trip
  /// to a toolbar for every cross, and crosses are the majority of the moves.
  NonogramPuzzle cycle(int index) {
    final next = switch (marks[index]) {
      NonogramMark.blank => NonogramMark.filled,
      NonogramMark.filled => NonogramMark.crossed,
      NonogramMark.crossed => NonogramMark.blank,
    };
    return setMark(index, next);
  }

  NonogramPuzzle setMark(int index, NonogramMark mark) {
    if (index < 0 || index >= cellCount) return this;
    if (marks[index] == mark) return this;

    final next = [...marks]..[index] = mark;
    return NonogramPuzzle._(
      columns: columns,
      rows: rows,
      rowClues: rowClues,
      columnClues: columnClues,
      marks: List<NonogramMark>.unmodifiable(next),
    );
  }

  NonogramPuzzle clearMarks() => NonogramPuzzle._(
        columns: columns,
        rows: rows,
        rowClues: rowClues,
        columnClues: columnClues,
        marks: List<NonogramMark>.filled(cellCount, NonogramMark.blank),
      );

  /// Clues implied by what the player has filled in [row].
  List<int> filledRowClues(int row) => _runsOf([
        for (var c = 0; c < columns; c++) markAt(row, c) == NonogramMark.filled,
      ]);

  List<int> filledColumnClues(int column) => _runsOf([
        for (var r = 0; r < rows; r++) markAt(r, column) == NonogramMark.filled,
      ]);

  /// Whether [row] currently matches its clues.
  ///
  /// Drives dimming the clue numbers once a line is done — the single most
  /// useful piece of feedback in the game, and one the player would otherwise
  /// have to recheck by hand on every move.
  bool isRowSatisfied(int row) => _sameClues(filledRowClues(row), rowClues[row]);

  bool isColumnSatisfied(int column) =>
      _sameClues(filledColumnClues(column), columnClues[column]);

  bool get isSolved {
    for (var r = 0; r < rows; r++) {
      if (!isRowSatisfied(r)) return false;
    }
    for (var c = 0; c < columns; c++) {
      if (!isColumnSatisfied(c)) return false;
    }
    return true;
  }

  /// Cells the player has filled, right or wrong.
  int get filledCount =>
      marks.where((m) => m == NonogramMark.filled).length;

  /// Total cells the finished picture contains, read off the clues.
  int get pictureSize =>
      rowClues.fold(0, (sum, clue) => sum + clue.fold(0, (a, b) => a + b));

  static List<bool> _drawPicture(
    int columns,
    int rows,
    double density,
    Random rng,
  ) {
    final picture = [
      for (var i = 0; i < columns * rows; i++) rng.nextDouble() < density,
    ];

    // An empty row or column is legal but reads as a mistake, and a solid one
    // gives the puzzle away. Nudge both back toward something in between.
    for (var r = 0; r < rows; r++) {
      final line = [for (var c = 0; c < columns; c++) picture[r * columns + c]];
      if (!line.contains(true)) picture[r * columns + rng.nextInt(columns)] = true;
      if (!line.contains(false)) picture[r * columns + rng.nextInt(columns)] = false;
    }

    return picture;
  }

  static List<List<int>> _cluesForRows(
    List<bool> picture,
    int columns,
    int rows,
  ) {
    return [
      for (var r = 0; r < rows; r++)
        _runsOf([for (var c = 0; c < columns; c++) picture[r * columns + c]]),
    ];
  }

  static List<List<int>> _cluesForColumns(
    List<bool> picture,
    int columns,
    int rows,
  ) {
    return [
      for (var c = 0; c < columns; c++)
        _runsOf([for (var r = 0; r < rows; r++) picture[r * columns + c]]),
    ];
  }

  /// Run lengths in [line]. An all-empty line yields `[0]`.
  static List<int> _runsOf(List<bool> line) {
    final runs = <int>[];
    var run = 0;
    for (final filled in line) {
      if (filled) {
        run++;
      } else if (run > 0) {
        runs.add(run);
        run = 0;
      }
    }
    if (run > 0) runs.add(run);
    return runs.isEmpty ? const [0] : List<int>.unmodifiable(runs);
  }

  static bool _sameClues(List<int> a, List<int> b) {
    // `[0]` and `[]` both mean "nothing in this line"; treat them as equal so an
    // untouched row does not read as a mismatch against a genuinely empty clue.
    final left = a.where((n) => n > 0).toList();
    final right = b.where((n) => n > 0).toList();
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  /// Whether these clues can be solved from blank by line logic alone.
  ///
  /// Repeatedly takes every row and column, works out which cells are filled (or
  /// empty) in *every* arrangement still consistent with what is known, and
  /// commits those. If that reaches a fully determined grid the puzzle needs no
  /// guessing — and, since every cell was forced, the solution is also unique.
  static bool isLineSolvable({
    required List<List<int>> rowClues,
    required List<List<int>> columnClues,
    required int columns,
    required int rows,
  }) {
    final known = List<bool?>.filled(columns * rows, null);
    final cache = <String, List<List<bool>>?>{};

    var changed = true;
    while (changed) {
      changed = false;

      for (var r = 0; r < rows; r++) {
        final line = [for (var c = 0; c < columns; c++) known[r * columns + c]];
        final deduced = _deduceLine(rowClues[r], line, cache);
        if (deduced == null) return false;

        for (var c = 0; c < columns; c++) {
          if (deduced[c] != null && known[r * columns + c] == null) {
            known[r * columns + c] = deduced[c];
            changed = true;
          }
        }
      }

      for (var c = 0; c < columns; c++) {
        final line = [for (var r = 0; r < rows; r++) known[r * columns + c]];
        final deduced = _deduceLine(columnClues[c], line, cache);
        if (deduced == null) return false;

        for (var r = 0; r < rows; r++) {
          if (deduced[r] != null && known[r * columns + c] == null) {
            known[r * columns + c] = deduced[r];
            changed = true;
          }
        }
      }
    }

    return known.every((cell) => cell != null);
  }

  /// Cells forced by [clues] given what is already [known].
  ///
  /// Returns null when no arrangement fits — a contradiction — or when the
  /// arrangement count is too large to enumerate. Both cases mean "do not ship
  /// this puzzle", which is the only decision the caller makes.
  static List<bool?>? _deduceLine(
    List<int> clues,
    List<bool?> known,
    Map<String, List<List<bool>>?> cache,
  ) {
    final key = '${clues.join(',')}|${known.length}';
    final all = cache.putIfAbsent(key, () => _arrangements(clues, known.length));
    if (all == null) return null;

    // Tri-state: true/false where every fitting arrangement agrees, null where
    // they differ. A plain bool accumulator cannot tell "all say empty" from
    // "they disagree", which is the whole distinction being computed here.
    final result = List<bool?>.filled(known.length, null);
    var seen = 0;

    for (final arrangement in all) {
      var fits = true;
      for (var i = 0; i < known.length; i++) {
        if (known[i] != null && known[i] != arrangement[i]) {
          fits = false;
          break;
        }
      }
      if (!fits) continue;

      if (seen == 0) {
        for (var i = 0; i < known.length; i++) {
          result[i] = arrangement[i];
        }
      } else {
        for (var i = 0; i < known.length; i++) {
          if (result[i] != null && result[i] != arrangement[i]) result[i] = null;
        }
      }
      seen++;
    }

    // No arrangement fits what is already known: the clues contradict the grid.
    if (seen == 0) return null;

    return result;
  }

  /// Every way [clues] can be laid out in a line of [length].
  ///
  /// Null if there are more than [cap] of them. Enumerating a 15-wide line with
  /// single-cell clues is tens of thousands of arrangements, and a generator
  /// that stalls is worse than one that rejects a candidate.
  static List<List<bool>>? _arrangements(
    List<int> clues,
    int length, {
    int cap = 30000,
  }) {
    final runs = clues.where((n) => n > 0).toList();
    final results = <List<bool>>[];

    bool place(int clueIndex, int start, List<bool> line) {
      if (clueIndex == runs.length) {
        results.add(List<bool>.of(line));
        return results.length <= cap;
      }

      final run = runs[clueIndex];
      // Everything still to place, plus one gap between each.
      final remaining = runs.skip(clueIndex + 1).fold(0, (a, b) => a + b) +
          (runs.length - clueIndex - 1);

      for (var at = start; at + run + remaining <= length; at++) {
        for (var i = 0; i < run; i++) {
          line[at + i] = true;
        }
        final ok = place(clueIndex + 1, at + run + 1, line);
        for (var i = 0; i < run; i++) {
          line[at + i] = false;
        }
        if (!ok) return false;
      }
      return true;
    }

    final within = place(0, 0, List<bool>.filled(length, false));
    if (!within) return null;
    return results;
  }
}
