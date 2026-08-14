import 'dart:math';

/// The classic 15-puzzle, at any square size.
///
/// Tiles are 1..n-1 with `0` marking the blank, stored row-major.
///
/// **Half of all random arrangements of a 15-puzzle are unsolvable.** Shuffling
/// by permutation and hoping is the defining bug of this game, and a player can
/// spend twenty minutes on a board that was never winnable. This class avoids it
/// by construction — [shuffled] walks backwards from the solved state using
/// legal moves only — and [isSolvable] exists as an independent check so tests
/// can verify that claim rather than trust it.
class SlidingPuzzle {
  SlidingPuzzle._(this.tiles, this.size);

  /// The solved arrangement: 1..n-1 in order, blank last.
  factory SlidingPuzzle.solved({int size = 4}) {
    assert(size >= 2, 'A puzzle smaller than 2x2 has no moves.');
    final count = size * size;
    return SlidingPuzzle._(
      List<int>.unmodifiable([for (var i = 1; i < count; i++) i, 0]),
      size,
    );
  }

  factory SlidingPuzzle.fromTiles(List<int> tiles) {
    final size = sqrt(tiles.length).round();
    assert(size * size == tiles.length, 'Tiles must form a square board.');
    return SlidingPuzzle._(List<int>.unmodifiable(tiles), size);
  }

  /// A shuffled but **always solvable** board.
  ///
  /// Produced by making random legal moves from the solved state, which cannot
  /// reach an unsolvable arrangement. [moves] defaults to a value that scales
  /// with board area — too few and the puzzle is trivially close to solved.
  factory SlidingPuzzle.shuffled({int size = 4, Random? random, int? moves}) {
    final rng = random ?? Random();
    var puzzle = SlidingPuzzle.solved(size: size);
    final target = moves ?? size * size * 20;

    var lastBlank = -1;
    for (var i = 0; i < target; i++) {
      final options = puzzle.movableTiles.where((t) => t != lastBlank).toList();
      if (options.isEmpty) continue;

      final chosen = options[rng.nextInt(options.length)];
      lastBlank = puzzle.blankIndex;
      puzzle = puzzle.move(chosen) ?? puzzle;
    }

    // A shuffle that lands back on solved is legal but a terrible board to hand
    // someone, so nudge it once more.
    if (puzzle.isSolved) {
      final options = puzzle.movableTiles;
      puzzle = puzzle.move(options[rng.nextInt(options.length)]) ?? puzzle;
    }

    return puzzle;
  }

  final List<int> tiles;
  final int size;

  int get blankIndex => tiles.indexOf(0);

  bool get isSolved {
    for (var i = 0; i < tiles.length - 1; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return tiles.last == 0;
  }

  int tileAt(int row, int column) => tiles[row * size + column];

  /// Board indices whose tile is orthogonally adjacent to the blank, and can
  /// therefore be tapped to move.
  List<int> get movableTiles {
    final blank = blankIndex;
    final blankRow = blank ~/ size;
    final blankCol = blank % size;

    return [
      for (var i = 0; i < tiles.length; i++)
        if (i != blank && _isAdjacent(i ~/ size, i % size, blankRow, blankCol)) i,
    ];
  }

  bool canMove(int index) => movableTiles.contains(index);

  /// Slides the tile at [index] into the blank.
  ///
  /// Returns null when the move is illegal, rather than silently returning an
  /// unchanged board — a caller that counts moves needs to distinguish "moved"
  /// from "tapped a tile that cannot move", and a bool-plus-out-param is worse.
  SlidingPuzzle? move(int index) {
    if (index < 0 || index >= tiles.length || !canMove(index)) return null;

    final next = List<int>.from(tiles);
    final blank = blankIndex;
    next[blank] = next[index];
    next[index] = 0;

    return SlidingPuzzle._(List<int>.unmodifiable(next), size);
  }

  /// Whether this arrangement can be solved at all.
  ///
  /// Independent of how the board was produced, so tests can confirm that
  /// [shuffled] never emits an unsolvable board. Standard parity rule:
  /// odd-width boards need an even inversion count; even-width boards need the
  /// inversion count plus the blank's row from the bottom to be odd.
  bool get isSolvable {
    final values = tiles.where((t) => t != 0).toList();

    var inversions = 0;
    for (var i = 0; i < values.length; i++) {
      for (var j = i + 1; j < values.length; j++) {
        if (values[i] > values[j]) inversions++;
      }
    }

    if (size.isOdd) return inversions.isEven;

    final blankRowFromBottom = size - (blankIndex ~/ size);
    return (inversions + blankRowFromBottom).isOdd;
  }

  static bool _isAdjacent(int row, int col, int otherRow, int otherCol) {
    return (row == otherRow && (col - otherCol).abs() == 1) ||
        (col == otherCol && (row - otherRow).abs() == 1);
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = tileAt(r, c);
        buffer.write((v == 0 ? '.' : '$v').padLeft(4));
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
