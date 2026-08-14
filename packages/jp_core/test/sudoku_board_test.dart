import 'dart:math';

import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

/// Whether [digits] is a complete, legal sudoku grid.
bool isValidGrid(List<int> digits) {
  bool nineDistinct(Iterable<int> cells) => cells.toSet().length == 9;

  for (var i = 0; i < 9; i++) {
    if (!nineDistinct([for (var c = 0; c < 9; c++) digits[i * 9 + c]])) return false;
    if (!nineDistinct([for (var r = 0; r < 9; r++) digits[r * 9 + i]])) return false;

    final boxRow = (i ~/ 3) * 3;
    final boxColumn = (i % 3) * 3;
    if (!nineDistinct([
      for (var r = 0; r < 3; r++)
        for (var c = 0; c < 3; c++) digits[(boxRow + r) * 9 + boxColumn + c],
    ])) {
      return false;
    }
  }
  return true;
}

/// Counts the answers to [puzzle], stopping at [limit].
///
/// Deliberately a separate, plainer solver than the generator's: checking the
/// uniqueness promise with the same code that makes it would only prove the code
/// agrees with itself.
int countSolutions(List<int?> puzzle, {int limit = 2}) {
  final grid = List<int?>.of(puzzle);
  var found = 0;

  bool legal(int index, int digit) {
    final row = index ~/ 9;
    final column = index % 9;
    for (var i = 0; i < 9; i++) {
      if (grid[row * 9 + i] == digit) return false;
      if (grid[i * 9 + column] == digit) return false;
    }
    final boxRow = (row ~/ 3) * 3;
    final boxColumn = (column ~/ 3) * 3;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        if (grid[(boxRow + r) * 9 + boxColumn + c] == digit) return false;
      }
    }
    return true;
  }

  void search(int index) {
    if (found >= limit) return;
    if (index == 81) {
      found++;
      return;
    }
    if (grid[index] != null) {
      search(index + 1);
      return;
    }
    for (var digit = 1; digit <= 9; digit++) {
      if (!legal(index, digit)) continue;
      grid[index] = digit;
      search(index + 1);
      grid[index] = null;
    }
  }

  search(0);
  return found;
}

/// The first empty cell of [board], for tests that need a writable one.
int firstEmpty(SudokuBoard board) =>
    List<int>.generate(81, (i) => i).firstWhere((i) => board.entries[i] == null);

void main() {
  group('generation', () {
    test('the solution is a legal complete grid', () {
      for (var seed = 0; seed < 8; seed++) {
        final board = SudokuBoard.generate(random: Random(seed));
        expect(isValidGrid(board.solution), isTrue, reason: 'seed $seed');
      }
    });

    test('every puzzle has exactly one answer', () {
      // The promise the whole generator exists to keep. A sudoku with two
      // answers cannot be reasoned out, only guessed at, and the player finds
      // that out only after a long dead end.
      for (var seed = 0; seed < 8; seed++) {
        final board = SudokuBoard.generate(random: Random(seed));
        expect(countSolutions(board.givens), 1, reason: 'seed $seed');
      }
    });

    test('every given matches the solution', () {
      final board = SudokuBoard.generate(random: Random(1));
      for (var i = 0; i < SudokuBoard.cellCount; i++) {
        if (board.givens[i] == null) continue;
        expect(board.givens[i], board.solution[i]);
      }
    });

    test('the board starts as its givens', () {
      final board = SudokuBoard.generate(random: Random(2));
      expect(board.entries, board.givens);
      expect(board.notes.every((n) => n.isEmpty), isTrue);
    });

    test('harder difficulties leave fewer givens', () {
      final easy = SudokuBoard.generate(
        difficulty: SudokuDifficulty.easy,
        random: Random(3),
      );
      final hard = SudokuBoard.generate(
        difficulty: SudokuDifficulty.hard,
        random: Random(3),
      );

      expect(hard.filledCount, lessThan(easy.filledCount));
    });

    test('never removes more than the difficulty asks for', () {
      // The generator may stop early when uniqueness blocks a removal, but it
      // must never dig past the target — that would silently hand the player a
      // harder puzzle than the one they chose.
      for (final difficulty in SudokuDifficulty.values) {
        final board = SudokuBoard.generate(
          difficulty: difficulty,
          random: Random(4),
        );
        expect(board.filledCount, greaterThanOrEqualTo(difficulty.givens));
      }
    });

    test('is reproducible for a given seed', () {
      expect(
        SudokuBoard.generate(random: Random(5)).givens,
        SudokuBoard.generate(random: Random(5)).givens,
      );
    });

    test('different seeds produce different puzzles', () {
      expect(
        SudokuBoard.generate(random: Random(6)).givens,
        isNot(SudokuBoard.generate(random: Random(7)).givens),
      );
    });
  });

  group('entering digits', () {
    test('writes into an empty cell', () {
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);

      expect(board.setDigit(index, 5).entries[index], 5);
    });

    test('clears a cell when given null', () {
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);

      final written = board.setDigit(index, 5);
      expect(written.setDigit(index, null).entries[index], isNull);
    });

    test('refuses to overwrite a given', () {
      final board = SudokuBoard.generate(random: Random(1));
      final given = List<int>.generate(81, (i) => i)
          .firstWhere((i) => board.givens[i] != null);

      expect(board.setDigit(given, 5), same(board));
    });

    test('ignores an out-of-range index', () {
      final board = SudokuBoard.generate(random: Random(1));
      expect(board.setDigit(-1, 5), same(board));
      expect(board.setDigit(81, 5), same(board));
    });

    test('does not mutate the board it came from', () {
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);

      board.setDigit(index, 5);
      expect(board.entries[index], isNull);
    });

    test('clearEntries restores the puzzle to its givens', () {
      final board = SudokuBoard.generate(random: Random(1));
      final played = board.setDigit(firstEmpty(board), 5);

      expect(played.clearEntries().entries, board.givens);
    });
  });

  group('pencil marks', () {
    test('toggle on and off', () {
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);

      final noted = board.toggleNote(index, 3);
      expect(noted.notes[index], {3});
      expect(noted.toggleNote(index, 3).notes[index], isEmpty);
    });

    test('several marks live in one cell', () {
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);

      final noted = board.toggleNote(index, 3).toggleNote(index, 7);
      expect(noted.notes[index], {3, 7});
    });

    test('writing a digit clears that cell\'s marks', () {
      // The marks were the working out for a decision that has now been made.
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);

      final noted = board.toggleNote(index, 3).toggleNote(index, 7);
      expect(noted.setDigit(index, 3).notes[index], isEmpty);
    });

    test('are refused on a filled cell and on givens', () {
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);
      final given = List<int>.generate(81, (i) => i)
          .firstWhere((i) => board.givens[i] != null);

      final filled = board.setDigit(index, 4);
      expect(filled.toggleNote(index, 9), same(filled));
      expect(board.toggleNote(given, 9), same(board));
    });

    test('reject digits outside 1..9', () {
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);

      expect(board.toggleNote(index, 0), same(board));
      expect(board.toggleNote(index, 10), same(board));
    });
  });

  group('conflicts', () {
    test('a fresh puzzle has none', () {
      final board = SudokuBoard.generate(random: Random(1));
      expect(board.conflicts, isEmpty);
    });

    test('report both cells in a clash, not just the newer one', () {
      // Highlighting only the cell just typed implies the older one is right,
      // and the older one is often the mistake.
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);
      final row = board.rowOf(index);

      // Copy a digit already in this row into the empty cell.
      final duplicate = List<int>.generate(9, (c) => row * 9 + c)
          .firstWhere((i) => i != index && board.entries[i] != null);

      final clashing = board.setDigit(index, board.entries[duplicate]);
      expect(clashing.conflicts, containsAll([index, duplicate]));
    });

    test('a repeat in the same box is a conflict', () {
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);
      final box = board.boxOf(index);

      final sameBox = List<int>.generate(81, (i) => i).firstWhere(
        (i) => i != index && board.boxOf(i) == box && board.entries[i] != null,
      );

      final clashing = board.setDigit(index, board.entries[sameBox]);
      expect(clashing.conflicts, containsAll([index, sameBox]));
    });
  });

  group('finishing', () {
    test('filling in the solution solves the puzzle', () {
      var board = SudokuBoard.generate(random: Random(1));
      for (var i = 0; i < SudokuBoard.cellCount; i++) {
        board = board.setDigit(i, board.solution[i]);
      }

      expect(board.isComplete, isTrue);
      expect(board.isSolved, isTrue);
      expect(board.firstUnsolvedIndex, isNull);
    });

    test('a full grid with a clash is complete but not solved', () {
      var board = SudokuBoard.generate(random: Random(1));
      for (var i = 0; i < SudokuBoard.cellCount; i++) {
        board = board.setDigit(i, board.solution[i]);
      }

      final index = firstEmpty(SudokuBoard.generate(random: Random(1)));
      final wrong = board.solution[index] % 9 + 1;
      board = board.setDigit(index, wrong);

      expect(board.isComplete, isTrue);
      expect(board.isSolved, isFalse);
    });

    test('countOf tracks how many of a digit are placed', () {
      final board = SudokuBoard.generate(random: Random(1));
      final placed = board.countOf(1);

      final index = List<int>.generate(81, (i) => i)
          .firstWhere((i) => board.entries[i] == null);

      expect(board.setDigit(index, 1).countOf(1), placed + 1);
    });
  });

  group('hints', () {
    test('reveal the correct digit', () {
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);

      expect(board.revealHint(index).entries[index], board.solution[index]);
    });

    test('do nothing to a given', () {
      final board = SudokuBoard.generate(random: Random(1));
      final given = List<int>.generate(81, (i) => i)
          .firstWhere((i) => board.givens[i] != null);

      expect(board.revealHint(given), same(board));
    });

    test('firstUnsolvedIndex finds a wrong entry, not only an empty one', () {
      final board = SudokuBoard.generate(random: Random(1));
      final index = firstEmpty(board);
      final wrong = board.solution[index] % 9 + 1;

      expect(board.setDigit(index, wrong).firstUnsolvedIndex, isNotNull);
    });
  });
}
