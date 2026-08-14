import 'dart:math';

import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

/// Draws a sequence of edges, asserting each is legal.
DotsAndBoxes drawAll(DotsAndBoxes board, List<Edge> edges) {
  var current = board;
  for (final edge in edges) {
    final next = current.draw(edge);
    expect(next, isNotNull, reason: 'edge $edge should have been legal');
    current = next!;
  }
  return current;
}

/// Closes the box at [boxIndex] by drawing all four of its sides in order.
DotsAndBoxes closeBox(DotsAndBoxes board, int boxIndex) =>
    drawAll(board, board.edgesOfBox(boxIndex));

void main() {
  group('geometry', () {
    test('a 1x1 board has four distinct edges', () {
      final board = DotsAndBoxes.empty(rows: 1, columns: 1);
      expect(board.horizontal.length, 2);
      expect(board.vertical.length, 2);
      expect(board.edgesOfBox(0).toSet().length, 4);
      expect(board.availableEdges.length, 4);
    });

    test('a 2x2 board has twelve edges', () {
      // 3 rows of 2 horizontals, plus 2 rows of 3 verticals.
      final board = DotsAndBoxes.empty(rows: 2, columns: 2);
      expect(board.horizontal.length, 6);
      expect(board.vertical.length, 6);
      expect(board.availableEdges.length, 12);
    });

    test('an interior edge borders two boxes, a border edge only one', () {
      final board = DotsAndBoxes.empty(rows: 2, columns: 2);

      // The horizontal line between the top-left and bottom-left boxes.
      const shared = Edge(EdgeOrientation.horizontal, 2);
      expect(board.boxesTouching(shared).length, 2);

      // The very top edge of the top-left box.
      const border = Edge(EdgeOrientation.horizontal, 0);
      expect(board.boxesTouching(border).length, 1);
    });
  });

  group('drawing', () {
    test('an edge cannot be drawn twice', () {
      final board = DotsAndBoxes.empty(rows: 2, columns: 2);
      final once = board.draw(const Edge(EdgeOrientation.horizontal, 0))!;
      expect(once.draw(const Edge(EdgeOrientation.horizontal, 0)), isNull);
    });

    test('out-of-range edges are rejected rather than throwing', () {
      final board = DotsAndBoxes.empty(rows: 2, columns: 2);
      expect(board.draw(const Edge(EdgeOrientation.horizontal, -1)), isNull);
      expect(board.draw(const Edge(EdgeOrientation.horizontal, 99)), isNull);
    });

    test('the source board is never mutated', () {
      final board = DotsAndBoxes.empty(rows: 2, columns: 2);
      board.draw(const Edge(EdgeOrientation.horizontal, 0));
      expect(board.horizontal.every((d) => !d), isTrue);
    });

    test('a non-scoring move passes the turn', () {
      final board = DotsAndBoxes.empty(rows: 2, columns: 2);
      expect(board.currentPlayer, BoxOwner.one);

      final next = board.draw(const Edge(EdgeOrientation.horizontal, 0))!;
      expect(next.currentPlayer, BoxOwner.two);
    });
  });

  group('scoring', () {
    test('completing a box claims it for the mover', () {
      final board = closeBox(DotsAndBoxes.empty(rows: 1, columns: 1), 0);

      expect(board.owners[0], isNot(BoxOwner.none));
      expect(board.isComplete, isTrue);
    });

    test('completing a box grants another turn', () {
      // Without this the whole strategy of the game disappears.
      var board = DotsAndBoxes.empty(rows: 1, columns: 1);
      final edges = board.edgesOfBox(0);

      board = drawAll(board, edges.take(3).toList());
      final beforeClosing = board.currentPlayer;

      board = board.draw(edges[3])!;
      expect(board.currentPlayer, beforeClosing,
          reason: 'the player who closed the box keeps the turn');
      expect(board.owners[0], beforeClosing);
    });

    test('one edge can complete two boxes at once', () {
      // An edge between two boxes closes both if each was on its last side.
      // Scoring only the first is a classic off-by-one in this game.
      var board = DotsAndBoxes.empty(rows: 2, columns: 1);

      const shared = Edge(EdgeOrientation.horizontal, 1);

      // Draw every edge except the shared one.
      final everythingElse = board.availableEdges.where((e) => e != shared).toList();
      board = drawAll(board, everythingElse);

      expect(board.owners.every((o) => o == BoxOwner.none), isTrue,
          reason: 'nothing should be closed yet');

      final mover = board.currentPlayer;
      board = board.draw(shared)!;

      expect(board.scoreFor(mover), 2, reason: 'both boxes belong to the mover');
      expect(board.isComplete, isTrue);
    });

    test('scores sum to the number of boxes once complete', () {
      var board = DotsAndBoxes.empty(rows: 2, columns: 2);
      final rng = Random(5);

      while (!board.isComplete) {
        final edges = board.availableEdges;
        board = board.draw(edges[rng.nextInt(edges.length)])!;
      }

      expect(
        board.scoreFor(BoxOwner.one) + board.scoreFor(BoxOwner.two),
        board.boxCount,
      );
    });
  });

  group('completion', () {
    test('no moves are accepted once every box is claimed', () {
      final board = closeBox(DotsAndBoxes.empty(rows: 1, columns: 1), 0);
      expect(board.availableEdges, isEmpty);
      expect(board.draw(const Edge(EdgeOrientation.horizontal, 0)), isNull);
    });

    test('the winner is whoever holds more boxes', () {
      var board = DotsAndBoxes.empty(rows: 1, columns: 2);
      final rng = Random(2);

      while (!board.isComplete) {
        final edges = board.availableEdges;
        board = board.draw(edges[rng.nextInt(edges.length)])!;
      }

      final one = board.scoreFor(BoxOwner.one);
      final two = board.scoreFor(BoxOwner.two);
      final expected = one == two
          ? BoxOwner.none
          : (one > two ? BoxOwner.one : BoxOwner.two);

      expect(board.winner, expected);
    });
  });

  group('AI', () {
    test('always returns a legal edge', () {
      for (final level in DotsAiLevel.values) {
        var board = DotsAndBoxes.empty(rows: 3, columns: 3);
        final rng = Random(9);

        while (!board.isComplete) {
          final edge = DotsAndBoxesAi.chooseEdge(board, level, rng);
          expect(board.isDrawn(edge), isFalse, reason: '$level chose a drawn edge');
          board = board.draw(edge)!;
        }
      }
    });

    test('smart always takes a free box when one is available', () {
      // Missing a free box is the most obvious way an opponent looks broken.
      var board = DotsAndBoxes.empty(rows: 2, columns: 2);
      final edges = board.edgesOfBox(0);
      board = drawAll(board, edges.take(3).toList());

      final chosen = DotsAndBoxesAi.chooseEdge(board, DotsAiLevel.smart, Random(1));
      final next = board.draw(chosen)!;

      expect(next.scoreFor(board.currentPlayer), 1,
          reason: 'the smart AI should have closed the box on offer');
    });

    test('smart avoids handing over a box when a safe move exists', () {
      // Drawing the third side of a box gifts it to the opponent.
      var board = DotsAndBoxes.empty(rows: 3, columns: 3);
      final edges = board.edgesOfBox(0);
      board = drawAll(board, edges.take(2).toList());

      final chosen = DotsAndBoxesAi.chooseEdge(board, DotsAiLevel.smart, Random(3));

      final wouldGiveAway = board.boxesTouching(chosen).any(
            (b) => board.owners[b] == BoxOwner.none && board.drawnSidesOf(b) == 2,
          );
      expect(wouldGiveAway, isFalse);
    });

    test('smart beats easy over repeated games', () {
      // A heuristic that cannot beat random is not a heuristic. This is the
      // honest bar for this AI â€” it is explicitly not a solved player, and a
      // human who understands chain parity will still beat it.
      var smartWins = 0;
      var easyWins = 0;

      for (var seed = 0; seed < 30; seed++) {
        var board = DotsAndBoxes.empty(rows: 3, columns: 3);
        final rng = Random(seed);

        while (!board.isComplete) {
          final level = board.currentPlayer == BoxOwner.one
              ? DotsAiLevel.smart
              : DotsAiLevel.easy;
          board = board.draw(DotsAndBoxesAi.chooseEdge(board, level, rng))!;
        }

        if (board.winner == BoxOwner.one) smartWins++;
        if (board.winner == BoxOwner.two) easyWins++;
      }

      expect(smartWins, greaterThan(easyWins),
          reason: 'smart won $smartWins, easy won $easyWins over 30 games');
    });

    test('throws rather than returning nonsense on a finished board', () {
      final board = closeBox(DotsAndBoxes.empty(rows: 1, columns: 1), 0);
      expect(
        () => DotsAndBoxesAi.chooseEdge(board, DotsAiLevel.smart, Random(1)),
        throwsStateError,
      );
    });
  });
}

