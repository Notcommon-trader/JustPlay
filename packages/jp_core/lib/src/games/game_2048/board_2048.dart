import 'dart:math';

/// Direction of a swipe.
enum SlideDirection { up, down, left, right }

/// Outcome of attempting a move.
///
/// [changed] is the important one: 2048 only spawns a new tile when the board
/// actually moved. Spawning on a no-op move is the classic implementation bug —
/// it lets a player fill the board by swiping into a wall.
class MoveResult {
  const MoveResult({
    required this.board,
    required this.changed,
    required this.scoreGained,
    required this.mergedIndices,
  });

  final Board2048 board;
  final bool changed;
  final int scoreGained;

  /// Indices that merged this move, so the UI can animate exactly those tiles.
  /// Presentation concern, but the rules layer is the only place that knows.
  final List<int> mergedIndices;
}

/// Immutable 2048 board.
///
/// Immutable rather than mutable-in-place so that undo, replay and save/restore
/// are a matter of keeping references, and so a UI can hold the previous board
/// to animate from. The cost is one 16-element list allocation per move, which
/// is irrelevant at this scale.
///
/// Tiles are stored row-major, `0` meaning empty. Values are the face value
/// (2, 4, 8 …) rather than exponents — exponents are marginally more compact and
/// consistently harder to debug.
class Board2048 {
  Board2048._(this.tiles, this.score, this.size);

  /// Creates an empty board. [size] is configurable because the same rules drive
  /// 4x4 (classic), 5x5 (easier) and 3x3 (much harder) variants — three games'
  /// worth of content from one implementation.
  factory Board2048.empty({int size = 4}) {
    assert(size >= 2, 'A board smaller than 2x2 cannot merge.');
    return Board2048._(List<int>.filled(size * size, 0), 0, size);
  }

  /// Creates a board from explicit tiles. Used by tests and by save/restore.
  factory Board2048.fromTiles(List<int> tiles, {int score = 0}) {
    final size = sqrt(tiles.length).round();
    assert(size * size == tiles.length, 'Tiles must form a square board.');
    return Board2048._(List<int>.unmodifiable(tiles), score, size);
  }

  /// A new game: an empty board with the two starting tiles.
  factory Board2048.newGame({int size = 4, Random? random}) {
    final rng = random ?? Random();
    return Board2048.empty(size: size).spawnTile(rng).spawnTile(rng);
  }

  final List<int> tiles;
  final int score;
  final int size;

  int get length => tiles.length;

  int tileAt(int row, int column) => tiles[row * size + column];

  bool get hasEmptyCell => tiles.contains(0);

  /// Highest tile on the board. Drives the "you reached 512" style goals.
  int get highestTile => tiles.fold(0, max);

  /// True when no move in any direction would change anything.
  ///
  /// Checked by attempting all four moves rather than by reasoning about
  /// adjacency. Slower, and impossible to get subtly wrong — and it runs once
  /// per move on 16 cells.
  bool get isGameOver {
    if (hasEmptyCell) return false;
    return SlideDirection.values.every((d) => !move(d).changed);
  }

  /// Applies a move. Does **not** spawn a new tile — that is the caller's job via
  /// [spawnTile], because spawning needs randomness and keeping it out of here
  /// makes every rule below deterministically testable.
  MoveResult move(SlideDirection direction) {
    final next = List<int>.from(tiles);
    final merged = <int>[];
    var gained = 0;
    var changed = false;

    for (var line = 0; line < size; line++) {
      final indices = _lineIndices(line, direction);
      final values = [for (final i in indices) next[i]];

      final collapsed = _collapse(values);
      gained += collapsed.scoreGained;

      for (var i = 0; i < indices.length; i++) {
        if (next[indices[i]] != collapsed.values[i]) changed = true;
        next[indices[i]] = collapsed.values[i];
      }
      for (final position in collapsed.mergedPositions) {
        merged.add(indices[position]);
      }
    }

    return MoveResult(
      board: Board2048._(List<int>.unmodifiable(next), score + gained, size),
      changed: changed,
      scoreGained: gained,
      mergedIndices: List<int>.unmodifiable(merged),
    );
  }

  /// Adds one tile to a random empty cell: 90% a 2, 10% a 4 — the standard
  /// distribution from the original game.
  ///
  /// Returns the same board when full, rather than throwing. A caller that
  /// spawns after a no-op move has a bug, but crashing the game is a worse
  /// response than doing nothing.
  Board2048 spawnTile(Random random) {
    final empty = <int>[
      for (var i = 0; i < tiles.length; i++)
        if (tiles[i] == 0) i,
    ];
    if (empty.isEmpty) return this;

    final next = List<int>.from(tiles);
    next[empty[random.nextInt(empty.length)]] = random.nextInt(10) == 0 ? 4 : 2;
    return Board2048._(List<int>.unmodifiable(next), score, size);
  }

  /// Indices of one row or column, ordered so that index 0 is the end the tiles
  /// travel *towards*. Collapsing then always works front-to-back regardless of
  /// direction, which removes four near-identical code paths.
  List<int> _lineIndices(int line, SlideDirection direction) {
    return switch (direction) {
      SlideDirection.left => [for (var c = 0; c < size; c++) line * size + c],
      SlideDirection.right => [for (var c = size - 1; c >= 0; c--) line * size + c],
      SlideDirection.up => [for (var r = 0; r < size; r++) r * size + line],
      SlideDirection.down => [for (var r = size - 1; r >= 0; r--) r * size + line],
    };
  }

  /// Slides one line towards index 0 and merges equal neighbours.
  ///
  /// A tile produced by a merge cannot merge again in the same move: `[2,2,4]`
  /// becomes `[4,4,0]`, never `[8,0,0]`. That single rule is what most naive
  /// implementations get wrong, and it is why merging advances the cursor by two.
  static _CollapsedLine _collapse(List<int> values) {
    final packed = [for (final v in values) if (v != 0) v];
    final result = <int>[];
    final mergedPositions = <int>[];
    var gained = 0;

    for (var i = 0; i < packed.length; i++) {
      if (i + 1 < packed.length && packed[i] == packed[i + 1]) {
        final value = packed[i] * 2;
        mergedPositions.add(result.length);
        result.add(value);
        gained += value;
        i++; // consume the partner so it cannot merge again
      } else {
        result.add(packed[i]);
      }
    }

    while (result.length < values.length) {
      result.add(0);
    }

    return _CollapsedLine(result, gained, mergedPositions);
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        buffer.write(tileAt(r, c).toString().padLeft(5));
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}

class _CollapsedLine {
  const _CollapsedLine(this.values, this.scoreGained, this.mergedPositions);

  final List<int> values;
  final int scoreGained;
  final List<int> mergedPositions;
}
