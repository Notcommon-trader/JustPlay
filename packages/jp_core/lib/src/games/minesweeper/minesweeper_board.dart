import 'dart:math';

/// What the player has done to a cell. Whether it hides a mine is separate —
/// see [MinesweeperBoard.mines].
enum CellState { hidden, revealed, flagged }

/// Minesweeper.
///
/// Two rules make or break an implementation of this game:
///
/// **First-click safety.** Losing on the very first tap is pure bad luck and
/// feels broken. Mines are therefore not placed until the first reveal, and are
/// then placed avoiding that cell *and its neighbours* — so the opening tap
/// always clears a region rather than a single number.
///
/// **Flood fill.** Revealing a cell with no adjacent mines must cascade outward
/// until it hits numbered cells. Without it the game is unplayable: every empty
/// square has to be tapped individually.
class MinesweeperBoard {
  MinesweeperBoard._({
    required this.columns,
    required this.rows,
    required this.mineCount,
    required this.mines,
    required this.states,
    required this.minesPlaced,
    required this.hitMineIndex,
  });

  /// A fresh board. Mines are not placed yet — see the class comment.
  factory MinesweeperBoard.empty({
    int columns = 9,
    int rows = 9,
    int mineCount = 10,
  }) {
    final cells = columns * rows;
    assert(mineCount > 0 && mineCount < cells, 'Mine count must fit the board.');

    return MinesweeperBoard._(
      columns: columns,
      rows: rows,
      mineCount: mineCount,
      mines: List<bool>.unmodifiable(List<bool>.filled(cells, false)),
      states: List<CellState>.unmodifiable(
        List<CellState>.filled(cells, CellState.hidden),
      ),
      minesPlaced: false,
      hitMineIndex: null,
    );
  }

  final int columns;
  final int rows;
  final int mineCount;

  /// True where a mine sits. All false until the first reveal.
  final List<bool> mines;

  final List<CellState> states;
  final bool minesPlaced;

  /// The mine the player detonated, so the view can highlight it. Null unless
  /// the game was lost.
  final int? hitMineIndex;

  int get cellCount => columns * rows;

  bool get isLost => hitMineIndex != null;

  /// Won when every cell that is not a mine has been revealed. Flags are
  /// irrelevant — a player who clears the board without flagging anything has
  /// still won, and requiring correct flags is a common and infuriating bug.
  bool get isWon {
    if (isLost || !minesPlaced) return false;
    for (var i = 0; i < cellCount; i++) {
      if (!mines[i] && states[i] != CellState.revealed) return false;
    }
    return true;
  }

  bool get isOver => isWon || isLost;

  int get flagsPlaced => states.where((s) => s == CellState.flagged).length;

  /// Mines minus flags. Can go negative if the player over-flags, which is
  /// standard and a useful signal to them.
  int get minesRemaining => mineCount - flagsPlaced;

  /// Number of mines touching [index], including diagonals.
  int adjacentMines(int index) {
    var count = 0;
    for (final n in neighbours(index)) {
      if (mines[n]) count++;
    }
    return count;
  }

  /// The up-to-eight cells touching [index].
  ///
  /// Computed from row/column rather than by offsetting the flat index, which is
  /// what stops neighbours wrapping from the end of one row to the start of the
  /// next.
  List<int> neighbours(int index) {
    final row = index ~/ columns;
    final col = index % columns;
    final result = <int>[];

    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final r = row + dr;
        final c = col + dc;
        if (r < 0 || r >= rows || c < 0 || c >= columns) continue;
        result.add(r * columns + c);
      }
    }

    return result;
  }

  /// Reveals a cell, cascading through empty regions.
  ///
  /// Returns null for a tap that does nothing — an already-revealed cell, a
  /// flagged cell, or any tap once the game is over — so a caller counting moves
  /// can tell the difference.
  MinesweeperBoard? reveal(int index, {Random? random}) {
    if (isOver) return null;
    if (index < 0 || index >= cellCount) return null;
    if (states[index] != CellState.hidden) return null;

    var board = this;

    // Mines are placed on the first reveal so the opening tap is always safe.
    if (!board.minesPlaced) {
      board = board._placeMines(safeIndex: index, random: random ?? Random());
    }

    if (board.mines[index]) {
      final next = List<CellState>.from(board.states)..[index] = CellState.revealed;
      return MinesweeperBoard._(
        columns: columns,
        rows: rows,
        mineCount: mineCount,
        mines: board.mines,
        states: List<CellState>.unmodifiable(next),
        minesPlaced: true,
        hitMineIndex: index,
      );
    }

    final next = List<CellState>.from(board.states);

    // Iterative flood fill. Recursion would be more concise and would blow the
    // stack on a large board with one big empty region.
    final queue = <int>[index];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (next[current] == CellState.revealed) continue;
      // A flagged cell stops the cascade. The player marked it deliberately and
      // wiping that out mid-cascade loses real work.
      if (next[current] == CellState.flagged) continue;

      next[current] = CellState.revealed;

      if (board.adjacentMines(current) == 0) {
        queue.addAll(board.neighbours(current));
      }
    }

    return MinesweeperBoard._(
      columns: columns,
      rows: rows,
      mineCount: mineCount,
      mines: board.mines,
      states: List<CellState>.unmodifiable(next),
      minesPlaced: true,
      hitMineIndex: null,
    );
  }

  /// Flags or unflags a hidden cell. Revealed cells cannot be flagged.
  MinesweeperBoard? toggleFlag(int index) {
    if (isOver) return null;
    if (index < 0 || index >= cellCount) return null;
    if (states[index] == CellState.revealed) return null;

    final next = List<CellState>.from(states);
    next[index] =
        next[index] == CellState.flagged ? CellState.hidden : CellState.flagged;

    return MinesweeperBoard._(
      columns: columns,
      rows: rows,
      mineCount: mineCount,
      mines: mines,
      states: List<CellState>.unmodifiable(next),
      minesPlaced: minesPlaced,
      hitMineIndex: hitMineIndex,
    );
  }

  /// Places mines, keeping [safeIndex] and its neighbours clear.
  ///
  /// Falls back to allowing neighbours if the board is too dense for a full
  /// safe pocket — on a 5x5 with 20 mines there is nowhere else to put them, and
  /// refusing to deal is worse than a slightly less generous opening.
  MinesweeperBoard _placeMines({required int safeIndex, required Random random}) {
    final excluded = {safeIndex, ...neighbours(safeIndex)};
    final available = [
      for (var i = 0; i < cellCount; i++)
        if (!excluded.contains(i)) i,
    ];

    final pool = available.length >= mineCount
        ? available
        : [
            for (var i = 0; i < cellCount; i++)
              if (i != safeIndex) i,
          ];

    pool.shuffle(random);

    final placed = List<bool>.filled(cellCount, false);
    for (var i = 0; i < mineCount; i++) {
      placed[pool[i]] = true;
    }

    return MinesweeperBoard._(
      columns: columns,
      rows: rows,
      mineCount: mineCount,
      mines: List<bool>.unmodifiable(placed),
      states: states,
      minesPlaced: true,
      hitMineIndex: null,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final i = r * columns + c;
        final glyph = switch (states[i]) {
          CellState.hidden => '#',
          CellState.flagged => 'F',
          CellState.revealed => mines[i] ? '*' : '${adjacentMines(i)}',
        };
        buffer.write(glyph.padLeft(2));
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
