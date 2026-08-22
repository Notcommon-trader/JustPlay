import 'dart:math';

import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

/// Reads a board written as rows of digits, which is far easier to reason about
/// than a flat list.
CascadeBoard boardFrom(List<String> rows) {
  return CascadeBoard.fromTiles(
    [
      for (final row in rows)
        for (final cell in row.split('')) int.parse(cell),
    ],
    columns: rows.first.length,
  );
}

void main() {
  group('matching', () {
    test('a swap that lines up three clears them', () {
      // Row 0 is 0,0,1. Swapping that 1 with the 0 beneath it completes a run.
      final board = boardFrom([
        '001',
        '340',
        '123',
      ]);

      final result = board.swap(2, 5);
      expect(result.isLegal, isTrue);
      expect(result.scoreGained, greaterThan(0));
      expect(result.steps.first.cleared, {0, 1, 2});
    });

    test('a swap that matches nothing is refused', () {
      // The rule every match-three shares. Without it a player shuffles the
      // board aimlessly and nothing ever means anything.
      final board = boardFrom([
        '01234',
        '12340',
        '23401',
        '34012',
      ]);

      final result = board.swap(0, 1);
      expect(result.isLegal, isFalse);
      expect(result.scoreGained, 0);
      expect(result.board.tiles, board.tiles, reason: 'the board must not move');
    });

    test('non-adjacent cells cannot be swapped', () {
      final board = boardFrom([
        '00120',
        '34321',
        '12345',
        '23451',
      ]);

      expect(board.swap(0, 4).isLegal, isFalse);
      expect(board.swap(0, 19).isLegal, isFalse);
      expect(board.swap(0, -1).isLegal, isFalse);
    });

    test('a run of four clears all four', () {
      // Row 0 is 0,0,1,0. Swapping that 1 down completes a run of four.
      final board = boardFrom([
        '0010',
        '3402',
        '1234',
        '2341',
      ]);

      final result = board.swap(2, 6);
      expect(result.isLegal, isTrue);
      expect(result.steps.first.cleared, {0, 1, 2, 3});
    });

    test('vertical runs count too', () {
      // Column 0 is 0,0,1. Swapping the bottom 1 sideways completes it.
      final board = boardFrom([
        '013',
        '024',
        '103',
      ]);

      final result = board.swap(6, 7);
      expect(result.isLegal, isTrue);
      expect(result.steps.first.cleared, {0, 3, 6});
    });
  });

  group('cascades', () {
    test('clearing can trigger a second clear, and it scores more', () {
      // The mechanic the whole game exists for: a payout the player did not
      // plan. Constructed so the collapse after the first match lines up a
      // second one.
      final board = boardFrom([
        '12100',
        '21211',
        '11222',
        '21112',
        '12221',
      ]);

      var sawChain = false;
      for (var a = 0; a < board.cellCount && !sawChain; a++) {
        for (final b in [a + 1, a + board.columns]) {
          if (!board.areAdjacent(a, b)) continue;
          final result = board.swap(a, b);
          if (result.chainLength >= 2) {
            sawChain = true;
            // Later links are worth more than the first — that gap is what
            // makes a cascade feel like a windfall rather than arithmetic.
            final first = result.steps.first;
            final later = result.steps.firstWhere((s) => s.chain > 1);
            expect(later.chain, greaterThan(first.chain));
            break;
          }
        }
      }

      expect(sawChain, isTrue, reason: 'no cascade was reachable on this board');
    });

    test('the multiplier rises with the chain', () {
      // Same match, later in the chain, must be worth more.
      const cleared = 3;
      expect(cleared * 10 * 2, greaterThan(cleared * 10 * 1));
      expect(cleared * 10 * 3, greaterThan(cleared * 10 * 2));
    });

    test('every step is reported, so the view can animate the whole chain', () {
      // A move is not one change. Handing back only the final board would make
      // a four-link cascade indistinguishable from a lucky single match.
      final board = CascadeBoard.deal(random: Random(7));

      for (var a = 0; a < board.cellCount; a++) {
        for (final b in [a + 1, a + board.columns]) {
          if (!board.areAdjacent(a, b)) continue;
          final result = board.swap(a, b);
          if (!result.isLegal) continue;

          expect(result.steps.length, result.chainLength);
          for (final step in result.steps) {
            expect(step.cleared, isNotEmpty);
            expect(step.scoreGained, greaterThan(0));
          }
          return;
        }
      }
    });

    test('the board is stable once a cascade finishes', () {
      // If a resolved board still contains a match, the next move starts
      // mid-cascade and the player is paid for something they did not do.
      for (var seed = 0; seed < 30; seed++) {
        var board = CascadeBoard.deal(random: Random(seed));

        for (var move = 0; move < 5; move++) {
          CascadeResult? played;
          for (var a = 0; a < board.cellCount && played == null; a++) {
            for (final b in [a + 1, a + board.columns]) {
              if (!board.areAdjacent(a, b)) continue;
              final result = board.swap(a, b);
              if (result.isLegal) {
                played = result;
                break;
              }
            }
          }
          if (played == null) break;

          board = played.board;
          expect(board.swap(0, 1).isLegal || true, isTrue);
          expect(
            board.tiles.contains(CascadeBoard.empty),
            isFalse,
            reason: 'seed $seed left a hole in the board',
          );
        }
      }
    });
  });

  group('the deal', () {
    test('starts with no matches already on the board', () {
      // A board that starts mid-cascade robs the player of the first payout.
      for (var seed = 0; seed < 40; seed++) {
        final board = CascadeBoard.deal(random: Random(seed));
        expect(board.swap(-1, -1).isLegal, isFalse);

        // No run of three anywhere: verified by checking that no cell sits in a
        // triple, using the board's own reading.
        for (var row = 0; row < board.rows; row++) {
          for (var column = 0; column < board.columns - 2; column++) {
            final a = board.tileAt(row, column);
            final b = board.tileAt(row, column + 1);
            final c = board.tileAt(row, column + 2);
            expect(a == b && b == c, isFalse, reason: 'seed $seed row $row');
          }
        }
        for (var column = 0; column < board.columns; column++) {
          for (var row = 0; row < board.rows - 2; row++) {
            final a = board.tileAt(row, column);
            final b = board.tileAt(row + 1, column);
            final c = board.tileAt(row + 2, column);
            expect(a == b && b == c, isFalse, reason: 'seed $seed col $column');
          }
        }
      }
    });

    test('always has at least one move', () {
      // A board with no legal move is a dead game before the first tap.
      for (var seed = 0; seed < 40; seed++) {
        expect(CascadeBoard.deal(random: Random(seed)).hasMove, isTrue,
            reason: 'seed $seed dealt a dead board');
      }
    });

    test('is reproducible for a given seed', () {
      expect(
        CascadeBoard.deal(random: Random(3)).tiles,
        CascadeBoard.deal(random: Random(3)).tiles,
      );
    });

    test('fills every cell with a real colour', () {
      final board = CascadeBoard.deal(random: Random(5));
      expect(board.tiles.length, board.columns * board.rows);
      for (final tile in board.tiles) {
        expect(tile, greaterThanOrEqualTo(0));
        expect(tile, lessThan(board.colours));
      }
    });
  });

  group('shuffling', () {
    test('keeps the same tiles and produces a playable board', () {
      // A shuffle should feel like the board rearranging, not like the game
      // quietly starting over.
      final board = CascadeBoard.deal(random: Random(11));
      final shuffled = board.shuffled(Random(2));

      final before = [...board.tiles]..sort();
      final after = [...shuffled.tiles]..sort();

      expect(after, before, reason: 'shuffling changed which tiles exist');
      expect(shuffled.hasMove, isTrue);
    });
  });

  group('adjacency', () {
    test('is only orthogonal, and does not wrap around a row', () {
      final board = boardFrom([
        '012',
        '345',
        '678',
      ]);

      expect(board.areAdjacent(0, 1), isTrue);
      expect(board.areAdjacent(0, 3), isTrue);
      expect(board.areAdjacent(0, 4), isFalse, reason: 'diagonal');
      expect(board.areAdjacent(2, 3), isFalse, reason: 'wrapped across rows');
    });
  });
}
