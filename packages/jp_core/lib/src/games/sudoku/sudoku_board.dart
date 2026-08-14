import 'dart:math';

/// How many digits a puzzle starts with.
///
/// Given count is a crude proxy for difficulty — a 30-given puzzle can be easier
/// than a 34-given one depending on which cells were removed — but it is the
/// proxy every sudoku app uses, and building a real difficulty grader means
/// writing a human-style solver that scores technique depth. That is worth doing
/// later; it is not worth blocking the game on.
enum SudokuDifficulty {
  easy(givens: 42),
  medium(givens: 34),
  hard(givens: 28);

  const SudokuDifficulty({required this.givens});

  final int givens;
}

/// Classic 9×9 sudoku.
///
/// **Every puzzle has exactly one solution.** Cells are removed one at a time and
/// the removal is undone if it leaves the puzzle with two answers. A sudoku with
/// two solutions cannot be solved by reasoning, only by guessing, and the player
/// discovers this only after a long dead end.
class SudokuBoard {
  const SudokuBoard._({
    required this.givens,
    required this.entries,
    required this.notes,
    required this.solution,
  });

  static const int size = 9;
  static const int cellCount = size * size;

  /// Builds a puzzle of the requested [difficulty].
  ///
  /// If [difficulty]'s given count cannot be reached without creating a second
  /// solution, generation stops at the fewest givens it could reach. The puzzle
  /// is still valid and still unique — it is just easier than asked for, which
  /// is the right way to fail.
  factory SudokuBoard.generate({
    SudokuDifficulty difficulty = SudokuDifficulty.medium,
    Random? random,
  }) {
    final rng = random ?? Random();
    final solution = _completeGrid(rng);
    final puzzle = List<int?>.of(solution);

    final order = List<int>.generate(cellCount, (i) => i)..shuffle(rng);
    var remaining = cellCount;

    for (final index in order) {
      if (remaining <= difficulty.givens) break;

      final removed = puzzle[index];
      puzzle[index] = null;

      if (_countSolutions(puzzle, limit: 2) == 1) {
        remaining--;
      } else {
        puzzle[index] = removed;
      }
    }

    return SudokuBoard._(
      givens: List<int?>.unmodifiable(puzzle),
      entries: List<int?>.unmodifiable(puzzle),
      notes: List<Set<int>>.unmodifiable([
        for (var i = 0; i < cellCount; i++) const <int>{},
      ]),
      solution: List<int>.unmodifiable(solution),
    );
  }

  /// The digits the puzzle started with. Null where the player must fill in.
  final List<int?> givens;

  /// What is on the board now, givens included.
  final List<int?> entries;

  /// Pencil marks per cell. Empty for a cell holding a digit.
  final List<Set<int>> notes;

  /// The one correct answer. Used for hints and for checking a finished grid;
  /// never for deciding whether a *move* is right, because a sudoku is solved by
  /// reasoning from the board, not by being told.
  final List<int> solution;

  bool isGiven(int index) => givens[index] != null;

  int rowOf(int index) => index ~/ size;
  int columnOf(int index) => index % size;
  int boxOf(int index) => (rowOf(index) ~/ 3) * 3 + columnOf(index) ~/ 3;

  int get filledCount => entries.where((e) => e != null).length;

  int get emptyCount => cellCount - filledCount;

  /// Cells that clash with another cell in their row, column or box.
  ///
  /// Both cells in a clash are reported: highlighting only the newer one implies
  /// the older one is right, which it may not be.
  Set<int> get conflicts {
    final clashes = <int>{};

    for (var a = 0; a < cellCount; a++) {
      final digit = entries[a];
      if (digit == null) continue;

      for (var b = a + 1; b < cellCount; b++) {
        if (entries[b] != digit) continue;
        if (rowOf(a) == rowOf(b) ||
            columnOf(a) == columnOf(b) ||
            boxOf(a) == boxOf(b)) {
          clashes
            ..add(a)
            ..add(b);
        }
      }
    }

    return clashes;
  }

  bool get isComplete => entries.every((e) => e != null);

  bool get isSolved => isComplete && conflicts.isEmpty;

  /// How many of [digit] are already placed. Drives greying out a number pad
  /// button once all nine are down.
  int countOf(int digit) => entries.where((e) => e == digit).length;

  /// Writes [digit] into [index], or clears it when [digit] is null.
  ///
  /// Givens are immovable; a tap on one is a no-op rather than an error, because
  /// the player learns the rule from the board not responding.
  SudokuBoard setDigit(int index, int? digit) {
    if (index < 0 || index >= cellCount) return this;
    if (isGiven(index)) return this;
    if (entries[index] == digit) return this;

    final nextEntries = List<int?>.of(entries)..[index] = digit;
    // Writing a digit clears that cell's pencil marks: they were the working out
    // for a decision that has now been made.
    final nextNotes = List<Set<int>>.of(notes)..[index] = const <int>{};

    return _with(entries: nextEntries, notes: nextNotes);
  }

  /// Adds or removes a pencil mark. Ignored on a cell holding a digit.
  SudokuBoard toggleNote(int index, int digit) {
    if (index < 0 || index >= cellCount) return this;
    if (isGiven(index) || entries[index] != null) return this;
    if (digit < 1 || digit > size) return this;

    final marks = {...notes[index]};
    if (!marks.remove(digit)) marks.add(digit);

    final nextNotes = List<Set<int>>.of(notes)..[index] = Set.unmodifiable(marks);
    return _with(entries: entries, notes: nextNotes);
  }

  /// Fills [index] with its correct digit.
  ///
  /// Reveals the answer for one cell rather than pointing at a mistake: a hint
  /// that only says "something is wrong" sends the player back over work they
  /// have already checked.
  SudokuBoard revealHint(int index) {
    if (index < 0 || index >= cellCount) return this;
    if (isGiven(index)) return this;
    return setDigit(index, solution[index]);
  }

  /// The first empty or wrong cell, for a hint button with nothing selected.
  int? get firstUnsolvedIndex {
    for (var i = 0; i < cellCount; i++) {
      if (!isGiven(i) && entries[i] != solution[i]) return i;
    }
    return null;
  }

  SudokuBoard clearEntries() => _with(
        entries: List<int?>.of(givens),
        notes: [for (var i = 0; i < cellCount; i++) const <int>{}],
      );

  SudokuBoard _with({
    required List<int?> entries,
    required List<Set<int>> notes,
  }) {
    return SudokuBoard._(
      givens: givens,
      entries: List<int?>.unmodifiable(entries),
      notes: List<Set<int>>.unmodifiable(notes),
      solution: solution,
    );
  }

  /// A randomly filled, valid, complete grid.
  static List<int> _completeGrid(Random rng) {
    final grid = List<int?>.filled(cellCount, null);

    bool fill(int index) {
      if (index == cellCount) return true;

      final candidates = List<int>.generate(size, (i) => i + 1)..shuffle(rng);
      for (final digit in candidates) {
        if (!_canPlace(grid, index, digit)) continue;
        grid[index] = digit;
        if (fill(index + 1)) return true;
        grid[index] = null;
      }
      return false;
    }

    fill(0);
    return [for (final cell in grid) cell!];
  }

  /// Solutions of [grid], counted up to [limit].
  ///
  /// Stops early: the caller only ever asks "is this still unique", so counting
  /// past two is wasted work on the slowest step of generation.
  static int _countSolutions(List<int?> grid, {required int limit}) {
    final working = List<int?>.of(grid);
    var found = 0;

    bool search() {
      // Fewest candidates first. On a sparse grid, plain left-to-right
      // backtracking explores orders of magnitude more branches.
      var bestIndex = -1;
      var bestCandidates = <int>[];

      for (var i = 0; i < cellCount; i++) {
        if (working[i] != null) continue;

        final candidates = [
          for (var digit = 1; digit <= size; digit++)
            if (_canPlace(working, i, digit)) digit,
        ];

        if (candidates.isEmpty) return false;
        if (bestIndex == -1 || candidates.length < bestCandidates.length) {
          bestIndex = i;
          bestCandidates = candidates;
          if (candidates.length == 1) break;
        }
      }

      if (bestIndex == -1) {
        found++;
        return found >= limit;
      }

      for (final digit in bestCandidates) {
        working[bestIndex] = digit;
        if (search()) {
          working[bestIndex] = null;
          return true;
        }
        working[bestIndex] = null;
      }
      return false;
    }

    search();
    return found;
  }

  static bool _canPlace(List<int?> grid, int index, int digit) {
    final row = index ~/ size;
    final column = index % size;
    final boxRow = (row ~/ 3) * 3;
    final boxColumn = (column ~/ 3) * 3;

    for (var i = 0; i < size; i++) {
      if (grid[row * size + i] == digit) return false;
      if (grid[i * size + column] == digit) return false;
    }
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        if (grid[(boxRow + r) * size + boxColumn + c] == digit) return false;
      }
    }
    return true;
  }
}
