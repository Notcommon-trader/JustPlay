import 'dart:math';

import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

void main() {
  group('neighbours', () {
    test('a middle cell has eight', () {
      final board = MinesweeperBoard.empty(columns: 3, rows: 3, mineCount: 1);
      expect(board.neighbours(4)..sort(), [0, 1, 2, 3, 5, 6, 7, 8]);
    });

    test('a corner has three', () {
      final board = MinesweeperBoard.empty(columns: 3, rows: 3, mineCount: 1);
      expect(board.neighbours(0)..sort(), [1, 3, 4]);
    });

    test('neighbours never wrap across row edges', () {
      // Index 2 ends row 0 and index 3 starts row 1. They are adjacent in the
      // flat list but not on the board â€” the classic off-by-one that makes mine
      // counts wrong in ways players notice and developers do not.
      final board = MinesweeperBoard.empty(columns: 3, rows: 3, mineCount: 1);
      expect(board.neighbours(2).contains(3), isFalse);
      expect(board.neighbours(3).contains(2), isFalse);
    });
  });

  group('first-click safety', () {
    test('the first reveal never hits a mine', () {
      // Losing on the opening tap is pure bad luck and reads as a bug.
      for (var seed = 0; seed < 40; seed++) {
        final board = MinesweeperBoard.empty(columns: 9, rows: 9, mineCount: 10);
        final next = board.reveal(40, random: Random(seed))!;
        expect(next.isLost, isFalse, reason: 'seed $seed detonated on the first tap');
      }
    });

    test('the first reveal opens a region, not a single number', () {
      // Mines avoid the tapped cell *and* its neighbours, so the opening tap
      // always has zero adjacent mines and cascades.
      for (var seed = 0; seed < 20; seed++) {
        final board = MinesweeperBoard.empty(columns: 9, rows: 9, mineCount: 10);
        final next = board.reveal(40, random: Random(seed))!;
        final revealed =
            next.states.where((s) => s == CellState.revealed).length;
        expect(revealed, greaterThan(1), reason: 'seed $seed opened only one cell');
      }
    });

    test('mines are not placed until the first reveal', () {
      final board = MinesweeperBoard.empty();
      expect(board.minesPlaced, isFalse);
      expect(board.mines.every((m) => !m), isTrue);
    });

    test('exactly the requested number of mines is placed', () {
      final board = MinesweeperBoard.empty(columns: 9, rows: 9, mineCount: 10)
          .reveal(40, random: Random(2))!;
      expect(board.mines.where((m) => m).length, 10);
    });

    test('a dense board still deals rather than refusing', () {
      // 5x5 with 20 mines leaves nowhere for a full safe pocket. The opening tap
      // must still be safe, even if its neighbours cannot be.
      final board = MinesweeperBoard.empty(columns: 5, rows: 5, mineCount: 20)
          .reveal(12, random: Random(1))!;

      expect(board.isLost, isFalse);
      expect(board.mines.where((m) => m).length, 20);
    });
  });

  group('flood fill', () {
    test('revealing an empty cell cascades to numbered edges', () {
      // A board with a single mine in the far corner: tapping the opposite
      // corner should open almost everything.
      final board = MinesweeperBoard.empty(columns: 5, rows: 5, mineCount: 1)
          .reveal(24, random: Random(3))!;

      final revealed = board.states.where((s) => s == CellState.revealed).length;
      expect(revealed, greaterThan(10), reason: 'the cascade should be wide');
    });

    test('a numbered cell does not cascade', () {
      final board = MinesweeperBoard.empty(columns: 9, rows: 9, mineCount: 10)
          .reveal(40, random: Random(5))!;

      // Find a still-hidden cell that touches a mine; revealing it must open
      // exactly one cell.
      final numbered = List.generate(board.cellCount, (i) => i).firstWhere(
        (i) =>
            board.states[i] == CellState.hidden &&
            !board.mines[i] &&
            board.adjacentMines(i) > 0,
      );

      final before = board.states.where((s) => s == CellState.revealed).length;
      final after = board.reveal(numbered)!;
      final revealed = after.states.where((s) => s == CellState.revealed).length;

      expect(revealed, before + 1);
    });

    test('the cascade stops at flags rather than wiping them out', () {
      // A flag is deliberate work. A cascade that erases it loses the player's
      // reasoning silently.
      var board = MinesweeperBoard.empty(columns: 9, rows: 9, mineCount: 5)
          .reveal(0, random: Random(7))!;

      final hidden = List.generate(board.cellCount, (i) => i).firstWhere(
        (i) => board.states[i] == CellState.hidden && !board.mines[i],
      );

      board = board.toggleFlag(hidden)!;
      expect(board.states[hidden], CellState.flagged);

      // Reveal elsewhere and let any cascade run.
      final other = List.generate(board.cellCount, (i) => i).firstWhere(
        (i) => board.states[i] == CellState.hidden && !board.mines[i],
      );
      board = board.reveal(other) ?? board;

      expect(board.states[hidden], CellState.flagged,
          reason: 'a flag must survive a nearby cascade');
    });
  });

  group('flags', () {
    test('toggle on and off', () {
      var board = MinesweeperBoard.empty();
      board = board.toggleFlag(0)!;
      expect(board.states[0], CellState.flagged);

      board = board.toggleFlag(0)!;
      expect(board.states[0], CellState.hidden);
    });

    test('a flagged cell cannot be revealed', () {
      // Otherwise a mis-tap on a known mine ends the game.
      final board = MinesweeperBoard.empty().toggleFlag(0)!;
      expect(board.reveal(0), isNull);
    });

    test('a revealed cell cannot be flagged', () {
      final board = MinesweeperBoard.empty(columns: 9, rows: 9, mineCount: 10)
          .reveal(40, random: Random(1))!;

      final revealed = List.generate(board.cellCount, (i) => i)
          .firstWhere((i) => board.states[i] == CellState.revealed);

      expect(board.toggleFlag(revealed), isNull);
    });

    test('minesRemaining counts down as flags are placed', () {
      var board = MinesweeperBoard.empty(mineCount: 10);
      expect(board.minesRemaining, 10);

      board = board.toggleFlag(0)!;
      expect(board.minesRemaining, 9);
    });

    test('over-flagging goes negative rather than clamping', () {
      // A negative count tells the player they have flagged too many, which is
      // information. Clamping at zero hides a real mistake.
      var board = MinesweeperBoard.empty(columns: 5, rows: 5, mineCount: 1);
      board = board.toggleFlag(0)!.toggleFlag(1)!;
      expect(board.minesRemaining, -1);
    });
  });

  group('losing', () {
    test('revealing a mine ends the game and records which one', () {
      final board = MinesweeperBoard.empty(columns: 9, rows: 9, mineCount: 10)
          .reveal(40, random: Random(4))!;

      final mine = List.generate(board.cellCount, (i) => i)
          .firstWhere((i) => board.mines[i]);

      final lost = board.reveal(mine)!;
      expect(lost.isLost, isTrue);
      expect(lost.hitMineIndex, mine);
      expect(lost.isWon, isFalse);
    });

    test('no further moves are accepted once lost', () {
      final board = MinesweeperBoard.empty(columns: 9, rows: 9, mineCount: 10)
          .reveal(40, random: Random(4))!;
      final mine = List.generate(board.cellCount, (i) => i)
          .firstWhere((i) => board.mines[i]);
      final lost = board.reveal(mine)!;

      final anyHidden = List.generate(lost.cellCount, (i) => i)
          .firstWhere((i) => lost.states[i] == CellState.hidden);

      expect(lost.reveal(anyHidden), isNull);
      expect(lost.toggleFlag(anyHidden), isNull);
    });
  });

  group('winning', () {
    test('clearing every safe cell wins, regardless of flags', () {
      // Requiring correct flags to win is a common and infuriating bug.
      var board = MinesweeperBoard.empty(columns: 5, rows: 5, mineCount: 3)
          .reveal(12, random: Random(8))!;

      for (var i = 0; i < board.cellCount; i++) {
        if (board.mines[i]) continue;
        board = board.reveal(i) ?? board;
      }

      expect(board.isWon, isTrue);
      expect(board.isLost, isFalse);
      expect(board.flagsPlaced, 0, reason: 'won without flagging anything');
    });

    test('is not won while a safe cell is still hidden', () {
      final board = MinesweeperBoard.empty(columns: 9, rows: 9, mineCount: 10)
          .reveal(40, random: Random(6))!;
      expect(board.isWon, isFalse);
    });

    test('an untouched board is neither won nor lost', () {
      final board = MinesweeperBoard.empty();
      expect(board.isWon, isFalse);
      expect(board.isLost, isFalse);
      expect(board.isOver, isFalse);
    });
  });

  group('immutability', () {
    test('the source board is never mutated', () {
      final board = MinesweeperBoard.empty();
      board.reveal(0, random: Random(1));
      board.toggleFlag(1);

      expect(board.states.every((s) => s == CellState.hidden), isTrue);
      expect(board.minesPlaced, isFalse);
    });
  });
}

