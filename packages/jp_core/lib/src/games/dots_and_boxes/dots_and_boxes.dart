import 'dart:math';

/// Which side of an edge grid a line belongs to.
enum EdgeOrientation { horizontal, vertical }

/// A drawable line between two adjacent dots.
class Edge {
  const Edge(this.orientation, this.index);

  final EdgeOrientation orientation;

  /// Position within that orientation's grid. Horizontal edges form a
  /// `(rows + 1) x columns` grid; vertical edges form `rows x (columns + 1)`.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is Edge && other.orientation == orientation && other.index == index;

  @override
  int get hashCode => Object.hash(orientation, index);

  @override
  String toString() => '${orientation.name}[$index]';
}

enum BoxOwner { none, one, two }

/// Dots and boxes.
///
/// Two rules drive everything and are easy to get subtly wrong:
///
/// **Completing a box grants another turn.** A player who closes a box moves
/// again, and can chain several closures in one turn. Passing the turn after a
/// scoring move destroys the entire strategy of the game.
///
/// **A move can complete two boxes at once.** An edge between two boxes closes
/// both if each was on its last side, and both must be scored.
class DotsAndBoxes {
  DotsAndBoxes._({
    required this.rows,
    required this.columns,
    required this.horizontal,
    required this.vertical,
    required this.owners,
    required this.currentPlayer,
  });

  /// An empty board of `rows x columns` boxes.
  factory DotsAndBoxes.empty({int rows = 4, int columns = 4}) {
    assert(rows >= 1 && columns >= 1, 'A board needs at least one box.');
    return DotsAndBoxes._(
      rows: rows,
      columns: columns,
      horizontal: List<bool>.unmodifiable(List<bool>.filled((rows + 1) * columns, false)),
      vertical: List<bool>.unmodifiable(List<bool>.filled(rows * (columns + 1), false)),
      owners: List<BoxOwner>.unmodifiable(List<BoxOwner>.filled(rows * columns, BoxOwner.none)),
      currentPlayer: BoxOwner.one,
    );
  }

  final int rows;
  final int columns;

  /// Drawn state of each horizontal line, in a `(rows + 1) x columns` grid.
  final List<bool> horizontal;

  /// Drawn state of each vertical line, in a `rows x (columns + 1)` grid.
  final List<bool> vertical;

  final List<BoxOwner> owners;
  final BoxOwner currentPlayer;

  int get boxCount => rows * columns;

  int scoreFor(BoxOwner player) => owners.where((o) => o == player).length;

  bool get isComplete => !owners.contains(BoxOwner.none);

  /// Winner, or [BoxOwner.none] for a draw. Only meaningful once complete.
  BoxOwner get winner {
    final one = scoreFor(BoxOwner.one);
    final two = scoreFor(BoxOwner.two);
    if (one == two) return BoxOwner.none;
    return one > two ? BoxOwner.one : BoxOwner.two;
  }

  bool isDrawn(Edge edge) => switch (edge.orientation) {
        EdgeOrientation.horizontal => horizontal[edge.index],
        EdgeOrientation.vertical => vertical[edge.index],
      };

  /// Every edge not yet drawn.
  List<Edge> get availableEdges => [
        for (var i = 0; i < horizontal.length; i++)
          if (!horizontal[i]) Edge(EdgeOrientation.horizontal, i),
        for (var i = 0; i < vertical.length; i++)
          if (!vertical[i]) Edge(EdgeOrientation.vertical, i),
      ];

  /// The four edges of the box at [boxIndex].
  List<Edge> edgesOfBox(int boxIndex) {
    final r = boxIndex ~/ columns;
    final c = boxIndex % columns;

    return [
      Edge(EdgeOrientation.horizontal, r * columns + c), // top
      Edge(EdgeOrientation.horizontal, (r + 1) * columns + c), // bottom
      Edge(EdgeOrientation.vertical, r * (columns + 1) + c), // left
      Edge(EdgeOrientation.vertical, r * (columns + 1) + c + 1), // right
    ];
  }

  /// How many of a box's four sides are already drawn.
  int drawnSidesOf(int boxIndex) =>
      edgesOfBox(boxIndex).where(isDrawn).length;

  /// Boxes that [edge] forms a side of — one for a border edge, two otherwise.
  List<int> boxesTouching(Edge edge) {
    final result = <int>[];
    for (var box = 0; box < boxCount; box++) {
      if (edgesOfBox(box).contains(edge)) result.add(box);
    }
    return result;
  }

  /// Draws [edge].
  ///
  /// Returns null if the edge is out of range or already drawn, so a caller can
  /// distinguish a real move from a repeated tap.
  DotsAndBoxes? draw(Edge edge) {
    if (isComplete) return null;

    final limit = edge.orientation == EdgeOrientation.horizontal
        ? horizontal.length
        : vertical.length;
    if (edge.index < 0 || edge.index >= limit) return null;
    if (isDrawn(edge)) return null;

    final nextHorizontal = List<bool>.from(horizontal);
    final nextVertical = List<bool>.from(vertical);

    if (edge.orientation == EdgeOrientation.horizontal) {
      nextHorizontal[edge.index] = true;
    } else {
      nextVertical[edge.index] = true;
    }

    final nextOwners = List<BoxOwner>.from(owners);
    var claimed = 0;

    final candidate = DotsAndBoxes._(
      rows: rows,
      columns: columns,
      horizontal: nextHorizontal,
      vertical: nextVertical,
      owners: nextOwners,
      currentPlayer: currentPlayer,
    );

    // An edge sits between two boxes, and can close both at once. Checking only
    // the first would leave a completed box unowned and the score wrong.
    for (final box in candidate.boxesTouching(edge)) {
      if (nextOwners[box] == BoxOwner.none && candidate.drawnSidesOf(box) == 4) {
        nextOwners[box] = currentPlayer;
        claimed++;
      }
    }

    // Closing a box grants another turn. Passing the turn here would remove the
    // chain play that the whole game is built on.
    final nextPlayer = claimed > 0
        ? currentPlayer
        : (currentPlayer == BoxOwner.one ? BoxOwner.two : BoxOwner.one);

    return DotsAndBoxes._(
      rows: rows,
      columns: columns,
      horizontal: List<bool>.unmodifiable(nextHorizontal),
      vertical: List<bool>.unmodifiable(nextVertical),
      owners: List<BoxOwner>.unmodifiable(nextOwners),
      currentPlayer: nextPlayer,
    );
  }
}

/// How hard the computer opponent plays.
enum DotsAiLevel {
  /// Picks at random. A genuine beginner opponent, not a fake one.
  easy,

  /// Takes free boxes, and otherwise avoids handing one over.
  ///
  /// **Honest limitation:** this is a good heuristic, not a solved player. It
  /// does not count chains or play the sacrifice that wins the endgame, so a
  /// player who understands chain parity will beat it consistently. Do not
  /// describe it as unbeatable.
  smart,
}

/// Computer opponent for [DotsAndBoxes].
abstract final class DotsAndBoxesAi {
  /// Chooses an edge to draw. Throws if the board is already complete, which is
  /// a caller bug rather than a state the AI should paper over.
  static Edge chooseEdge(DotsAndBoxes board, DotsAiLevel level, Random random) {
    final available = board.availableEdges;
    if (available.isEmpty) {
      throw StateError('No edges left to draw.');
    }

    if (level == DotsAiLevel.easy) {
      return available[random.nextInt(available.length)];
    }

    // Take a free box whenever one exists. Missing a free box is the single
    // most obvious way an opponent looks broken.
    final scoring = [
      for (final edge in available)
        if (_completesABox(board, edge)) edge,
    ];
    if (scoring.isNotEmpty) {
      return scoring[random.nextInt(scoring.length)];
    }

    // Otherwise prefer an edge that does not give the opponent a free box —
    // that is, one that leaves no adjacent box on three sides.
    final safe = [
      for (final edge in available)
        if (!_givesAwayABox(board, edge)) edge,
    ];
    if (safe.isNotEmpty) {
      return safe[random.nextInt(safe.length)];
    }

    // Every move gives something away, which is the normal endgame position.
    // A stronger AI would sacrifice the smallest chain here; this one picks at
    // random, which is where its ceiling comes from.
    return available[random.nextInt(available.length)];
  }

  static bool _completesABox(DotsAndBoxes board, Edge edge) {
    for (final box in board.boxesTouching(edge)) {
      if (board.owners[box] == BoxOwner.none && board.drawnSidesOf(box) == 3) {
        return true;
      }
    }
    return false;
  }

  static bool _givesAwayABox(DotsAndBoxes board, Edge edge) {
    for (final box in board.boxesTouching(edge)) {
      if (board.owners[box] == BoxOwner.none && board.drawnSidesOf(box) == 2) {
        return true;
      }
    }
    return false;
  }
}
