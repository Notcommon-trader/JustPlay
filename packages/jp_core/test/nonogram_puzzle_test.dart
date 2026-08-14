import 'dart:math';

import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

/// Reads a picture written as rows of `#` and `.`, which is far easier to check
/// by eye than a flat list of booleans.
NonogramPuzzle puzzleFrom(List<String> rows) {
  final columns = rows.first.length;
  return NonogramPuzzle.fromPicture(
    picture: [
      for (final row in rows)
        for (final cell in row.split('')) cell == '#',
    ],
    columns: columns,
  );
}

NonogramPuzzle fill(NonogramPuzzle puzzle, List<String> rows) {
  var next = puzzle;
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      if (rows[r][c] == '#') {
        next = next.setMark(next.indexOf(r, c), NonogramMark.filled);
      }
    }
  }
  return next;
}

void main() {
  group('clues', () {
    test('are the run lengths of each line', () {
      final puzzle = puzzleFrom([
        '##.#.',
        '.....',
        '#####',
        '#..##',
        '.#.#.',
      ]);

      expect(puzzle.rowClues, [
        [2, 1],
        [0],
        [5],
        [1, 2],
        [1, 1],
      ]);

      expect(puzzle.columnClues, [
        [1, 2],
        [1, 1, 1],
        [1],
        [1, 3],
        [2],
      ]);
    });

    test('an empty line reads as [0] rather than nothing', () {
      // The UI needs something to draw in that gutter, and a bare zero is what
      // every printed nonogram uses.
      final puzzle = puzzleFrom(['..', '##']);
      expect(puzzle.rowClues.first, [0]);
    });
  });

  group('marking', () {
    test('cycles blank, filled, crossed, blank', () {
      var puzzle = puzzleFrom(['#.', '.#']);
      expect(puzzle.marks[0], NonogramMark.blank);

      puzzle = puzzle.cycle(0);
      expect(puzzle.marks[0], NonogramMark.filled);

      puzzle = puzzle.cycle(0);
      expect(puzzle.marks[0], NonogramMark.crossed);

      puzzle = puzzle.cycle(0);
      expect(puzzle.marks[0], NonogramMark.blank);
    });

    test('does not mutate the puzzle it came from', () {
      final puzzle = puzzleFrom(['#.', '.#']);
      puzzle.cycle(0);
      expect(puzzle.marks[0], NonogramMark.blank);
    });

    test('ignores an out-of-range index', () {
      final puzzle = puzzleFrom(['#.', '.#']);
      expect(puzzle.setMark(-1, NonogramMark.filled), same(puzzle));
      expect(puzzle.setMark(99, NonogramMark.filled), same(puzzle));
    });

    test('clearMarks resets every cell', () {
      final puzzle = fill(puzzleFrom(['#.', '.#']), ['##', '##']);
      expect(puzzle.filledCount, 4);
      expect(puzzle.clearMarks().filledCount, 0);
    });
  });

  group('solving', () {
    test('is not solved while blank', () {
      expect(puzzleFrom(['#.', '.#']).isSolved, isFalse);
    });

    test('is solved once the picture is filled in', () {
      final puzzle = puzzleFrom([
        '##.#.',
        '.....',
        '#####',
        '#..##',
        '.#.#.',
      ]);

      final solved = fill(puzzle, [
        '##.#.',
        '.....',
        '#####',
        '#..##',
        '.#.#.',
      ]);

      expect(solved.isSolved, isTrue);
    });

    test('accepts any grid matching the clues, not just the drawn one', () {
      // This puzzle has two answers: the leading diagonal and the other one.
      // Both satisfy every clue, so both are correct — checking against the
      // stored picture would reject a genuinely solved board and leave the
      // player with no way to see what was wrong.
      final puzzle = puzzleFrom(['#.', '.#']);
      final other = fill(puzzle, ['.#', '#.']);

      expect(other.isSolved, isTrue);
    });

    test('crossed cells are bookkeeping and never count as filled', () {
      var puzzle = fill(puzzleFrom(['##', '..']), ['##', '..']);
      expect(puzzle.isSolved, isTrue);

      puzzle = puzzle.setMark(puzzle.indexOf(1, 0), NonogramMark.crossed);
      expect(puzzle.isSolved, isTrue, reason: 'a cross changes nothing');
    });

    test('a wrong extra fill breaks the solve', () {
      final puzzle = fill(puzzleFrom(['##', '..']), ['##', '#.']);
      expect(puzzle.isSolved, isFalse);
    });
  });

  group('per-line feedback', () {
    test('a satisfied row is reported before the puzzle is done', () {
      final puzzle = fill(puzzleFrom(['##', '#.']), ['##', '..']);

      expect(puzzle.isRowSatisfied(0), isTrue);
      expect(puzzle.isRowSatisfied(1), isFalse);
      expect(puzzle.isSolved, isFalse);
    });

    test('a row with the right count but the wrong runs is not satisfied', () {
      // Two filled cells either side of a gap is not the same as a run of two,
      // and a count-only check would call it done.
      final puzzle = fill(puzzleFrom(['##.', '...', '...']), ['#.#', '...', '...']);
      expect(puzzle.isRowSatisfied(0), isFalse);
    });

    test('an untouched row whose clue is empty counts as satisfied', () {
      final puzzle = puzzleFrom(['..', '##']);
      expect(puzzle.isRowSatisfied(0), isTrue);
    });
  });

  group('generation', () {
    test('produces puzzles solvable without guessing', () {
      // The property that matters. A puzzle needing a guess is a coin flip the
      // player cannot distinguish from their own mistake.
      for (var seed = 0; seed < 20; seed++) {
        final puzzle = NonogramPuzzle.generate(
          columns: 10,
          rows: 10,
          random: Random(seed),
        );

        expect(
          NonogramPuzzle.isLineSolvable(
            rowClues: puzzle.rowClues,
            columnClues: puzzle.columnClues,
            columns: puzzle.columns,
            rows: puzzle.rows,
          ),
          isTrue,
          reason: 'seed $seed fell back to a guessy puzzle',
        );
      }
    });

    test('works at the small size too', () {
      for (var seed = 0; seed < 20; seed++) {
        final puzzle = NonogramPuzzle.generate(
          columns: 5,
          rows: 5,
          random: Random(seed),
        );
        expect(
          NonogramPuzzle.isLineSolvable(
            rowClues: puzzle.rowClues,
            columnClues: puzzle.columnClues,
            columns: puzzle.columns,
            rows: puzzle.rows,
          ),
          isTrue,
          reason: 'seed $seed fell back to a guessy puzzle',
        );
      }
    });

    test('starts blank and unsolved', () {
      final puzzle = NonogramPuzzle.generate(random: Random(1));
      expect(puzzle.filledCount, 0);
      expect(puzzle.isSolved, isFalse);
      expect(puzzle.marks.length, 100);
    });

    test('leaves no empty or solid row', () {
      final puzzle = NonogramPuzzle.generate(columns: 8, rows: 8, random: Random(5));
      for (final clue in puzzle.rowClues) {
        expect(clue.first, greaterThan(0), reason: 'an empty row reads as a bug');
        expect(clue.fold(0, (a, b) => a + b), lessThan(8),
            reason: 'a solid row gives itself away');
      }
    });

    test('is reproducible for a given seed', () {
      expect(
        NonogramPuzzle.generate(random: Random(9)).rowClues,
        NonogramPuzzle.generate(random: Random(9)).rowClues,
      );
    });

    test('pictureSize counts the cells the answer contains', () {
      final puzzle = puzzleFrom(['##.', '#..', '###']);
      expect(puzzle.pictureSize, 6);
    });
  });

  group('the line solver', () {
    test('rejects clues that no arrangement satisfies', () {
      // A run of three in a two-wide grid cannot be placed at all.
      expect(
        NonogramPuzzle.isLineSolvable(
          rowClues: const [
            [3],
            [0],
          ],
          columnClues: const [
            [1],
            [1],
          ],
          columns: 2,
          rows: 2,
        ),
        isFalse,
      );
    });

    test('rejects a puzzle with two answers', () {
      // The diagonal pair again: line logic can never decide it, and this is the
      // check that keeps such a puzzle out of the app.
      expect(
        NonogramPuzzle.isLineSolvable(
          rowClues: const [
            [1],
            [1],
          ],
          columnClues: const [
            [1],
            [1],
          ],
          columns: 2,
          rows: 2,
        ),
        isFalse,
      );
    });

    test('accepts a fully forced puzzle', () {
      final puzzle = puzzleFrom(['##', '#.']);
      expect(
        NonogramPuzzle.isLineSolvable(
          rowClues: puzzle.rowClues,
          columnClues: puzzle.columnClues,
          columns: 2,
          rows: 2,
        ),
        isTrue,
      );
    });
  });
}
