import 'dart:math';

import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

/// Builds a 4x4 board from a readable literal.
Board2048 board(List<int> tiles) => Board2048.fromTiles(tiles);

void main() {
  group('sliding', () {
    test('packs tiles towards the direction of travel', () {
      final result = board([
        0, 0, 0, 2, //
        0, 0, 4, 0, //
        0, 8, 0, 0, //
        16, 0, 0, 0, //
      ]).move(SlideDirection.left);

      expect(result.board.tiles, [
        2, 0, 0, 0, //
        4, 0, 0, 0, //
        8, 0, 0, 0, //
        16, 0, 0, 0, //
      ]);
      expect(result.changed, isTrue);
    });

    test('slides right without disturbing order', () {
      final result = board([
        2, 4, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ]).move(SlideDirection.right);

      expect(result.board.tiles.sublist(0, 4), [0, 0, 2, 4]);
    });

    test('slides up and down along columns', () {
      final source = board([
        0, 0, 0, 0, //
        2, 0, 0, 0, //
        0, 0, 0, 0, //
        4, 0, 0, 0, //
      ]);

      expect(source.move(SlideDirection.up).board.tiles[0], 2);
      expect(source.move(SlideDirection.up).board.tiles[4], 4);
      expect(source.move(SlideDirection.down).board.tiles[12], 4);
      expect(source.move(SlideDirection.down).board.tiles[8], 2);
    });
  });

  group('merging', () {
    test('merges equal neighbours and scores the resulting value', () {
      final result = board([
        2, 2, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ]).move(SlideDirection.left);

      expect(result.board.tiles.sublist(0, 4), [4, 0, 0, 0]);
      expect(result.scoreGained, 4);
      expect(result.board.score, 4);
    });

    test('a tile created by a merge cannot merge again in the same move', () {
      // The single most-failed rule in 2048 implementations. [2,2,4] must become
      // [4,4] — not [8], which would happen if the new 4 merged with the old one.
      final result = board([
        2, 2, 4, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ]).move(SlideDirection.left);

      expect(result.board.tiles.sublist(0, 4), [4, 4, 0, 0]);
      expect(result.scoreGained, 4, reason: 'Only the first pair merged.');
    });

    test('merges two independent pairs in one line', () {
      final result = board([
        2, 2, 4, 4, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ]).move(SlideDirection.left);

      expect(result.board.tiles.sublist(0, 4), [4, 8, 0, 0]);
      expect(result.scoreGained, 12);
    });

    test('merges the pair nearest the direction of travel first', () {
      // Sliding right, the rightmost pair merges. [4,2,2,2] -> [0,4,2,4]:
      // the two 2s nearest the right wall combine, and the leftmost 2 slides up
      // behind them rather than merging.
      final result = board([
        4, 2, 2, 2, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ]).move(SlideDirection.right);

      expect(result.board.tiles.sublist(0, 4), [0, 4, 2, 4]);
    });

    test('reports which indices merged, for animation', () {
      final result = board([
        2, 2, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ]).move(SlideDirection.left);

      expect(result.mergedIndices, [0]);
    });
  });

  group('move validity', () {
    test('a move that changes nothing is reported as unchanged', () {
      // Why it matters: the caller spawns a tile only when changed is true.
      // Spawning on a no-op lets a player fill the board by swiping into a wall.
      final result = board([
        2, 4, 8, 16, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ]).move(SlideDirection.left);

      expect(result.changed, isFalse);
      expect(result.scoreGained, 0);
    });

    test('a move is changed when only a merge occurs, with no sliding', () {
      final result = board([
        2, 2, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ]).move(SlideDirection.left);

      expect(result.changed, isTrue);
    });

    test('the source board is never mutated', () {
      final source = board([
        2, 2, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ]);
      source.move(SlideDirection.left);

      expect(source.tiles.sublist(0, 4), [2, 2, 0, 0]);
      expect(source.score, 0);
    });
  });

  group('game over', () {
    test('is false while an empty cell remains', () {
      expect(board(List<int>.filled(16, 0)).isGameOver, isFalse);
    });

    test('is false on a full board that still has a legal merge', () {
      final full = board([
        2, 4, 2, 4, //
        4, 2, 4, 2, //
        2, 4, 2, 4, //
        4, 2, 4, 4, // the bottom-right pair can still merge
      ]);

      expect(full.hasEmptyCell, isFalse);
      expect(full.isGameOver, isFalse);
    });

    test('is true on a full board with no legal merge', () {
      final locked = board([
        2, 4, 2, 4, //
        4, 2, 4, 2, //
        2, 4, 2, 4, //
        4, 2, 4, 2, //
      ]);

      expect(locked.isGameOver, isTrue);
    });
  });

  group('spawning', () {
    test('adds exactly one tile to an empty cell', () {
      final spawned = board(List<int>.filled(16, 0)).spawnTile(Random(1));
      expect(spawned.tiles.where((t) => t != 0).length, 1);
    });

    test('only ever spawns a 2 or a 4', () {
      var current = Board2048.empty();
      final rng = Random(7);
      for (var i = 0; i < 16; i++) {
        current = current.spawnTile(rng);
      }
      expect(current.tiles.every((t) => t == 2 || t == 4), isTrue);
    });

    test('leaves a full board untouched rather than throwing', () {
      final full = board(List<int>.filled(16, 2));
      expect(() => full.spawnTile(Random(1)), returnsNormally);
      expect(full.spawnTile(Random(1)).tiles, full.tiles);
    });

    test('spawning does not change the score', () {
      final spawned = Board2048.empty().spawnTile(Random(3));
      expect(spawned.score, 0);
    });
  });

  group('new game', () {
    test('starts with exactly two tiles', () {
      final game = Board2048.newGame(random: Random(42));
      expect(game.tiles.where((t) => t != 0).length, 2);
      expect(game.score, 0);
    });

    test('is reproducible for a given seed', () {
      // Seeded reproducibility is what makes a "daily challenge" mode possible:
      // every player gets the same board from the same seed.
      expect(
        Board2048.newGame(random: Random(99)).tiles,
        Board2048.newGame(random: Random(99)).tiles,
      );
    });
  });

  group('board sizes', () {
    test('supports a 5x5 variant with the same rules', () {
      final wide = Board2048.fromTiles([
        2, 2, 0, 0, 0, //
        0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, //
      ]);

      final result = wide.move(SlideDirection.left);
      expect(result.board.size, 5);
      expect(result.board.tiles.sublist(0, 5), [4, 0, 0, 0, 0]);
    });

    test('supports a 3x3 variant', () {
      final small = Board2048.fromTiles([
        4, 4, 0, //
        0, 0, 0, //
        0, 0, 0, //
      ]);

      expect(small.move(SlideDirection.left).board.tiles.sublist(0, 3), [8, 0, 0]);
    });
  });

  group('highest tile', () {
    test('reports the largest value present', () {
      expect(board([2, 4, 8, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]).highestTile, 16);
    });

    test('is zero on an empty board', () {
      expect(Board2048.empty().highestTile, 0);
    });
  });
}
