import 'dart:math';

/// The result of one player move, including everything that fell out of it.
///
/// A move is not a single change. It is a swap, then a clear, then a collapse,
/// then possibly another clear — and the player wants to *watch* each step. So
/// the rules hand back the whole sequence rather than just the final board, and
/// the view animates through it.
class CascadeResult {
  const CascadeResult({
    required this.steps,
    required this.board,
    required this.scoreGained,
  });

  /// Every intermediate board, in order. Empty when the move was illegal.
  final List<CascadeStep> steps;

  /// Where the board ended up.
  final CascadeBoard board;

  final int scoreGained;

  bool get isLegal => steps.isNotEmpty;

  /// How many separate clears happened. Two or more is a cascade, and the whole
  /// reason this game exists.
  int get chainLength => steps.where((s) => s.cleared.isNotEmpty).length;
}

/// One frame of a cascade.
class CascadeStep {
  const CascadeStep({
    required this.board,
    required this.cleared,
    required this.chain,
    required this.scoreGained,
  });

  /// The board *before* the cleared cells are removed, so the view can show
  /// them lighting up and then vanishing.
  final CascadeBoard board;

  /// Cells removed in this step.
  final Set<int> cleared;

  /// 1 for the player's own match, 2+ for what fell out of it. Drives the
  /// escalating pitch and the multiplier, which is where the pleasure is.
  final int chain;

  final int scoreGained;
}

/// A match-three board that pays out in chains.
///
/// **The cascade is the point.** Every other game in this catalogue is
/// deliberate: you make a considered move and exactly the expected thing
/// happens. That is a low-arousal loop however much polish is applied to it.
/// Here, one swap can clear a line, drop new tiles, clear again, and keep going
/// — an unplanned reward the player did not earn on purpose, which is the most
/// reinforcing thing a casual game can do and the one mechanic the catalogue
/// completely lacked.
class CascadeBoard {
  const CascadeBoard._({
    required this.columns,
    required this.rows,
    required this.tiles,
    required this.colours,
  });

  /// Number of distinct tile colours.
  ///
  /// Five is the genre standard and it is not arbitrary: four makes accidental
  /// matches so common the board solves itself, six makes them rare enough that
  /// cascades stop happening and the game turns into work.
  static const int defaultColours = 5;

  /// An empty cell, mid-collapse.
  static const int empty = -1;

  /// Deals a board with no matches already on it and at least one move
  /// available.
  ///
  /// Both conditions matter. A board that starts mid-cascade robs the player of
  /// the first payout, and a board with no legal move is a dead game before the
  /// first tap.
  factory CascadeBoard.deal({
    int columns = 7,
    int rows = 8,
    int colours = defaultColours,
    Random? random,
  }) {
    final rng = random ?? Random();

    while (true) {
      final tiles = List<int>.generate(
        columns * rows,
        (_) => rng.nextInt(colours),
      );

      var board = CascadeBoard._(
        columns: columns,
        rows: rows,
        tiles: List<int>.unmodifiable(tiles),
        colours: colours,
      );

      // Re-roll any tile that completes a run, rather than reshuffling: a
      // targeted fix converges in a handful of passes where a reshuffle can
      // loop for a long time on a small board.
      var guard = 0;
      while (board._matches().isNotEmpty && guard++ < 200) {
        final next = [...board.tiles];
        for (final index in board._matches()) {
          next[index] = rng.nextInt(colours);
        }
        board = board._withTiles(next);
      }

      if (board._matches().isEmpty && board.hasMove) return board;
    }
  }

  /// Builds a board from an explicit layout. For tests.
  factory CascadeBoard.fromTiles(
    List<int> tiles, {
    required int columns,
    int colours = defaultColours,
  }) {
    return CascadeBoard._(
      columns: columns,
      rows: tiles.length ~/ columns,
      tiles: List<int>.unmodifiable(tiles),
      colours: colours,
    );
  }

  final int columns;
  final int rows;

  /// Colour index per cell, row-major. [empty] while collapsing.
  final List<int> tiles;

  final int colours;

  int get cellCount => tiles.length;

  int indexOf(int row, int column) => row * columns + column;
  int rowOf(int index) => index ~/ columns;
  int columnOf(int index) => index % columns;

  int tileAt(int row, int column) => tiles[indexOf(row, column)];

  /// Whether [a] and [b] are side by side.
  bool areAdjacent(int a, int b) {
    if (a < 0 || b < 0 || a >= cellCount || b >= cellCount) return false;

    final sameRow = rowOf(a) == rowOf(b) && (columnOf(a) - columnOf(b)).abs() == 1;
    final sameColumn =
        columnOf(a) == columnOf(b) && (rowOf(a) - rowOf(b)).abs() == 1;
    return sameRow || sameColumn;
  }

  /// Swaps two tiles and resolves everything that follows.
  ///
  /// Returns an illegal result when the cells are not adjacent, or when the swap
  /// matches nothing — refusing a pointless swap is what stops the player
  /// shuffling the board aimlessly, and it is the rule every match-three shares.
  CascadeResult swap(int a, int b) {
    if (!areAdjacent(a, b)) return _illegal();

    final swapped = [...tiles];
    swapped[a] = tiles[b];
    swapped[b] = tiles[a];

    final after = _withTiles(swapped);
    if (after._matches().isEmpty) return _illegal();

    return after._resolve();
  }

  /// Whether any legal move exists.
  ///
  /// Checked after every cascade: a board with no move is a dead end, and the
  /// game shuffles rather than letting the player hunt for something that is not
  /// there.
  bool get hasMove {
    for (var index = 0; index < cellCount; index++) {
      final right = index + 1;
      if (columnOf(right) != 0 && right < cellCount && _swapMatches(index, right)) {
        return true;
      }

      final down = index + columns;
      if (down < cellCount && _swapMatches(index, down)) return true;
    }
    return false;
  }

  /// Reshuffles in place, preserving the tiles already on the board.
  ///
  /// Keeps the same multiset of colours rather than dealing fresh ones, so a
  /// shuffle feels like the board rearranging rather than the game quietly
  /// giving up and starting over.
  CascadeBoard shuffled(Random random) {
    var guard = 0;
    while (guard++ < 200) {
      final next = [...tiles]..shuffle(random);
      final board = _withTiles(next);
      if (board._matches().isEmpty && board.hasMove) return board;
    }
    return this;
  }

  bool _swapMatches(int a, int b) {
    final swapped = [...tiles];
    swapped[a] = tiles[b];
    swapped[b] = tiles[a];
    return _withTiles(swapped)._matches().isNotEmpty;
  }

  CascadeResult _illegal() =>
      CascadeResult(steps: const [], board: this, scoreGained: 0);

  /// Clears, collapses and refills until the board is stable.
  CascadeResult _resolve() {
    final steps = <CascadeStep>[];
    var board = this;
    var chain = 1;
    var total = 0;

    // A hard ceiling on the chain.
    //
    // Refilled tiles can match, clear, refill and match again, and there is no
    // mathematical guarantee that stops. The first version had no bound and hung
    // the test suite outright — an infinite cascade is a frozen game on a phone,
    // which is far worse than a chain that quietly stops paying at twenty. No
    // real board comes close to this.
    const maxChain = 20;

    while (chain <= maxChain) {
      final matched = board._matches();
      if (matched.isEmpty) break;

      // The multiplier is the whole reward. A three-tile match is worth 30 on
      // its own and 90 as the third link of a chain the player did not plan —
      // that gap is what makes a cascade feel like a windfall rather than
      // arithmetic.
      final gained = matched.length * 10 * chain;
      total += gained;

      steps.add(
        CascadeStep(
          board: board,
          cleared: matched,
          chain: chain,
          scoreGained: gained,
        ),
      );

      board = board._collapse(matched);
      chain++;
    }

    return CascadeResult(steps: steps, board: board, scoreGained: total);
  }

  /// Every cell that is part of a run of three or more.
  Set<int> _matches() {
    final matched = <int>{};

    for (var row = 0; row < rows; row++) {
      var run = 1;
      for (var column = 1; column <= columns; column++) {
        final same = column < columns &&
            tileAt(row, column) != empty &&
            tileAt(row, column) == tileAt(row, column - 1);

        if (same) {
          run++;
          continue;
        }
        if (run >= 3) {
          for (var k = column - run; k < column; k++) {
            matched.add(indexOf(row, k));
          }
        }
        run = 1;
      }
    }

    for (var column = 0; column < columns; column++) {
      var run = 1;
      for (var row = 1; row <= rows; row++) {
        final same = row < rows &&
            tileAt(row, column) != empty &&
            tileAt(row, column) == tileAt(row - 1, column);

        if (same) {
          run++;
          continue;
        }
        if (run >= 3) {
          for (var k = row - run; k < row; k++) {
            matched.add(indexOf(k, column));
          }
        }
        run = 1;
      }
    }

    return matched;
  }

  /// Removes [cleared], drops what is above into the gaps, and refills the top.
  ///
  /// Refill is deterministic per board state rather than random, so a replayed
  /// seed produces the same cascade — which is what makes a bug in a chain
  /// reproducible instead of a story about something that happened once.
  CascadeBoard _collapse(Set<int> cleared) {
    final next = [...tiles];
    for (final index in cleared) {
      next[index] = empty;
    }

    final rng = Random(Object.hash(next.join(','), cleared.length));

    for (var column = 0; column < columns; column++) {
      // Walk upward, pulling the next surviving tile down into each gap.
      var write = rows - 1;
      for (var read = rows - 1; read >= 0; read--) {
        final value = next[read * columns + column];
        if (value == empty) continue;
        next[write * columns + column] = value;
        write--;
      }
      while (write >= 0) {
        next[write * columns + column] = rng.nextInt(colours);
        write--;
      }
    }

    return _withTiles(next);
  }

  CascadeBoard _withTiles(List<int> next) => CascadeBoard._(
        columns: columns,
        rows: rows,
        tiles: List<int>.unmodifiable(next),
        colours: colours,
      );

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final tile = tileAt(row, column);
        buffer.write(tile == empty ? '.' : '$tile');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
