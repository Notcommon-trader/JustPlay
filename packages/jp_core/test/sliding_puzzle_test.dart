import 'dart:math';

import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

void main() {
  group('solved state', () {
    test('is 1..n-1 with the blank last', () {
      final puzzle = SlidingPuzzle.solved();
      expect(puzzle.tiles, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0]);
      expect(puzzle.isSolved, isTrue);
    });

    test('a board one move away is not solved', () {
      final puzzle = SlidingPuzzle.fromTiles([
        1, 2, 3, 4, //
        5, 6, 7, 8, //
        9, 10, 11, 12, //
        13, 14, 0, 15, //
      ]);
      expect(puzzle.isSolved, isFalse);
    });
  });

  group('moving', () {
    test('only tiles adjacent to the blank can move', () {
      final puzzle = SlidingPuzzle.solved();
      // Blank is index 15 (bottom-right). Its neighbours are 11 (above) and
      // 14 (left) — nothing else.
      expect(puzzle.movableTiles..sort(), [11, 14]);
    });

    test('an illegal move returns null rather than an unchanged board', () {
      // A caller counting moves must be able to tell "moved" from "tapped a
      // tile that cannot move".
      final puzzle = SlidingPuzzle.solved();
      expect(puzzle.move(0), isNull);
      expect(puzzle.move(-1), isNull);
      expect(puzzle.move(999), isNull);
    });

    test('a legal move swaps the tile with the blank', () {
      final puzzle = SlidingPuzzle.solved();
      final moved = puzzle.move(14)!;

      expect(moved.tiles[14], 0);
      expect(moved.tiles[15], 15);
      expect(moved.blankIndex, 14);
    });

    test('the source board is never mutated', () {
      final puzzle = SlidingPuzzle.solved();
      puzzle.move(14);
      expect(puzzle.tiles.last, 0, reason: 'the original must be untouched');
    });

    test('moving a tile and moving it back returns the original board', () {
      final puzzle = SlidingPuzzle.solved();
      final round = puzzle.move(14)!.move(15)!;
      expect(round.tiles, puzzle.tiles);
    });

    test('tiles do not wrap around row edges', () {
      // Index 3 is the end of row 0 and index 4 the start of row 1. They are
      // adjacent in the flat list but not on the board — a classic off-by-one
      // that lets tiles teleport across the puzzle.
      final puzzle = SlidingPuzzle.fromTiles([
        1, 2, 3, 0, //
        5, 6, 7, 8, //
        9, 10, 11, 12, //
        13, 14, 15, 4, //
      ]);

      expect(puzzle.canMove(4), isFalse, reason: 'index 4 is on the row below, not beside');
      expect(puzzle.canMove(2), isTrue);
      expect(puzzle.canMove(7), isTrue);
    });
  });

  group('solvability', () {
    test('the solved board is solvable', () {
      expect(SlidingPuzzle.solved().isSolvable, isTrue);
    });

    test('swapping two tiles makes a 4x4 board unsolvable', () {
      // The textbook unsolvable position: 14 and 15 transposed. If this reads as
      // solvable, the parity rule is wrong and shuffling could hand a player a
      // board they can never finish.
      final puzzle = SlidingPuzzle.fromTiles([
        1, 2, 3, 4, //
        5, 6, 7, 8, //
        9, 10, 11, 12, //
        13, 15, 14, 0, //
      ]);

      expect(puzzle.isSolvable, isFalse);
    });

    test('solvability is unaffected by legal moves', () {
      var puzzle = SlidingPuzzle.solved();
      final rng = Random(11);

      for (var i = 0; i < 200; i++) {
        final options = puzzle.movableTiles;
        puzzle = puzzle.move(options[rng.nextInt(options.length)])!;
        expect(puzzle.isSolvable, isTrue, reason: 'a legal move cannot break solvability');
      }
    });

    test('the odd-width rule holds for a 3x3 board', () {
      expect(SlidingPuzzle.solved(size: 3).isSolvable, isTrue);

      final swapped = SlidingPuzzle.fromTiles([
        2, 1, 3, //
        4, 5, 6, //
        7, 8, 0, //
      ]);
      expect(swapped.isSolvable, isFalse);
    });
  });

  group('shuffling', () {
    test('always produces a solvable board', () {
      // The whole reason shuffling walks legal moves instead of permuting: half
      // of all random permutations are unwinnable.
      for (var seed = 0; seed < 50; seed++) {
        final puzzle = SlidingPuzzle.shuffled(random: Random(seed));
        expect(puzzle.isSolvable, isTrue, reason: 'seed $seed produced an unsolvable board');
      }
    });

    test('does not hand the player an already-solved board', () {
      for (var seed = 0; seed < 25; seed++) {
        expect(SlidingPuzzle.shuffled(random: Random(seed)).isSolved, isFalse);
      }
    });

    test('is reproducible for a given seed', () {
      expect(
        SlidingPuzzle.shuffled(random: Random(42)).tiles,
        SlidingPuzzle.shuffled(random: Random(42)).tiles,
      );
    });

    test('keeps every tile exactly once', () {
      final puzzle = SlidingPuzzle.shuffled(random: Random(5));
      final sorted = [...puzzle.tiles]..sort();
      expect(sorted, [for (var i = 0; i < 16; i++) i]);
    });

    test('works at other board sizes', () {
      for (final size in [3, 5]) {
        final puzzle = SlidingPuzzle.shuffled(size: size, random: Random(3));
        expect(puzzle.size, size);
        expect(puzzle.isSolvable, isTrue);
        expect(puzzle.tiles.length, size * size);
      }
    });
  });
}
