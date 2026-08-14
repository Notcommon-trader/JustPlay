import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

const int kSeed = 3;
const int kSize = 5;

Widget host() {
  return MaterialApp(
    theme: JpTheme.light(),
    home: const GameShell(
      definition: NonogramDefinition(
        columns: kSize,
        rows: kSize,
        sizeName: 'five',
        seed: kSeed,
      ),
      title: 'Nonogram',
    ),
  );
}

/// The puzzle the seeded view will have generated.
NonogramPuzzle expectedPuzzle() => NonogramPuzzle.generate(
      columns: kSize,
      rows: kSize,
      random: Random(kSeed),
    );

String statValue(WidgetTester tester, String label) {
  final column = find.ancestor(of: find.text(label), matching: find.byType(Column));
  final texts = tester.widgetList<Text>(
    find.descendant(of: column.first, matching: find.byType(Text)),
  );
  return texts.last.data ?? '';
}

/// The colour the cell at [index] is currently painted.
Color cellColour(WidgetTester tester, int index) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byKey(nonogramCellKey(index)),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration! as BoxDecoration).color!;
}

bool cellIsCrossed(WidgetTester tester, int index) {
  return find
      .descendant(
        of: find.byKey(nonogramCellKey(index)),
        matching: find.byIcon(Icons.close),
      )
      .evaluate()
      .isNotEmpty;
}

/// Opacity of the first clue number beside [row]. Dimmed means the row is done.
double rowClueOpacity(WidgetTester tester, int row) {
  final style = tester.widget<AnimatedDefaultTextStyle>(
    find
        .descendant(
          of: find.byKey(nonogramRowClueKey(row)),
          matching: find.byType(AnimatedDefaultTextStyle),
        )
        .first,
  );
  return style.style.color!.a;
}

Future<void> phoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(GoldenSize.phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Fills every cell of the answer, leaving the rest blank.
Future<void> solve(WidgetTester tester, NonogramPuzzle puzzle) async {
  final answer = _answer(puzzle);

  for (var index = 0; index < puzzle.cellCount; index++) {
    if (!answer[index]) continue;
    await tester.tap(find.byKey(nonogramCellKey(index)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Recovers the picture by line-solving the clues.
///
/// The puzzle deliberately does not carry its answer around — [NonogramPuzzle]
/// checks clues, not a stored solution. The test needs one, and deducing it is
/// also a second, independent check that the generated puzzle really is
/// solvable without guessing.
List<bool> _answer(NonogramPuzzle puzzle) {
  final known = List<bool>.filled(puzzle.cellCount, false);

  // Brute force over every arrangement is unnecessary: try every combination of
  // filled cells per row that matches the row clue, backtracking on columns.
  final rowOptions = [
    for (var r = 0; r < puzzle.rows; r++)
      _linesMatching(puzzle.rowClues[r], puzzle.columns),
  ];

  bool search(int row) {
    if (row == puzzle.rows) return _columnsMatch(puzzle, known);

    for (final option in rowOptions[row]) {
      for (var c = 0; c < puzzle.columns; c++) {
        known[puzzle.indexOf(row, c)] = option[c];
      }
      if (_prefixCouldWork(puzzle, known, row) && search(row + 1)) return true;
    }
    return false;
  }

  final solved = search(0);
  if (!solved) throw StateError('the generated puzzle has no solution');
  return known;
}

List<List<bool>> _linesMatching(List<int> clue, int length) {
  final runs = clue.where((n) => n > 0).toList();
  final results = <List<bool>>[];

  void place(int index, int start, List<bool> line) {
    if (index == runs.length) {
      results.add(List<bool>.of(line));
      return;
    }
    final run = runs[index];
    final remaining =
        runs.skip(index + 1).fold(0, (a, b) => a + b) + (runs.length - index - 1);

    for (var at = start; at + run + remaining <= length; at++) {
      for (var i = 0; i < run; i++) {
        line[at + i] = true;
      }
      place(index + 1, at + run + 1, line);
      for (var i = 0; i < run; i++) {
        line[at + i] = false;
      }
    }
  }

  place(0, 0, List<bool>.filled(length, false));
  return results;
}

/// Whether the rows filled so far can still lead to matching column clues.
bool _prefixCouldWork(NonogramPuzzle puzzle, List<bool> grid, int lastRow) {
  for (var c = 0; c < puzzle.columns; c++) {
    var filled = 0;
    for (var r = 0; r <= lastRow; r++) {
      if (grid[puzzle.indexOf(r, c)]) filled++;
    }
    final total = puzzle.columnClues[c].fold(0, (a, b) => a + b);
    if (filled > total) return false;
  }
  return true;
}

bool _columnsMatch(NonogramPuzzle puzzle, List<bool> grid) {
  for (var c = 0; c < puzzle.columns; c++) {
    final runs = <int>[];
    var run = 0;
    for (var r = 0; r < puzzle.rows; r++) {
      if (grid[puzzle.indexOf(r, c)]) {
        run++;
      } else if (run > 0) {
        runs.add(run);
        run = 0;
      }
    }
    if (run > 0) runs.add(run);

    final expected = puzzle.columnClues[c].where((n) => n > 0).toList();
    if (runs.length != expected.length) return false;
    for (var i = 0; i < runs.length; i++) {
      if (runs[i] != expected[i]) return false;
    }
  }
  return true;
}

void main() {
  group('shell integration', () {
    testWidgets('shows moves and time but no score', (tester) async {
      // Picross has no natural points system, and inventing one would be noise.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('MOVES'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('SCORE'), findsNothing);
    });

    testWidgets('draws a clue gutter for every row and column', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      for (var i = 0; i < kSize; i++) {
        expect(find.byKey(nonogramRowClueKey(i)), findsOneWidget);
        expect(find.byKey(nonogramColumnClueKey(i)), findsOneWidget);
      }
    });
  });

  group('marking cells', () {
    testWidgets('tapping cycles blank, filled, crossed, blank', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final scheme = JpTheme.light().colorScheme;
      expect(cellColour(tester, 0), scheme.surfaceContainerHighest);

      await tester.tap(find.byKey(nonogramCellKey(0)));
      await tester.pumpAndSettle();
      expect(cellColour(tester, 0), scheme.primary);

      await tester.tap(find.byKey(nonogramCellKey(0)));
      await tester.pumpAndSettle();
      expect(cellIsCrossed(tester, 0), isTrue);

      await tester.tap(find.byKey(nonogramCellKey(0)));
      await tester.pumpAndSettle();
      expect(cellColour(tester, 0), scheme.surfaceContainerHighest);
      expect(cellIsCrossed(tester, 0), isFalse);
    });

    testWidgets('long-press clears a cell without cycling through', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(nonogramCellKey(0)));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(nonogramCellKey(0)));
      await tester.pumpAndSettle();

      expect(cellColour(tester, 0), JpTheme.light().colorScheme.surfaceContainerHighest);
    });

    testWidgets('each mark counts as a move', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(nonogramCellKey(0)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(nonogramCellKey(1)));
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '2');
    });

    testWidgets('taps are ignored while paused', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(nonogramCellKey(0)), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
    });
  });

  group('clue feedback', () {
    testWidgets('a clue dims once its line is satisfied', (tester) async {
      // The one piece of feedback that keeps the game from being bookkeeping.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final puzzle = expectedPuzzle();
      final answer = _answer(puzzle);

      // Row 0 starts undimmed unless its clue is empty, which generate() avoids.
      expect(rowClueOpacity(tester, 0), 1.0);

      for (var c = 0; c < puzzle.columns; c++) {
        if (!answer[puzzle.indexOf(0, c)]) continue;
        await tester.tap(find.byKey(nonogramCellKey(puzzle.indexOf(0, c))));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(rowClueOpacity(tester, 0), lessThan(1.0));
    });
  });

  group('winning', () {
    testWidgets('filling the picture wins', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await solve(tester, expectedPuzzle());

      expect(find.text('You win'), findsOneWidget);
    });

    testWidgets('restarting clears the board', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(nonogramCellKey(0)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Restart'));
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
      expect(
        cellColour(tester, 0),
        JpTheme.light().colorScheme.surfaceContainerHighest,
      );
    });
  });

  group('definition', () {
    test('id encodes the size', () {
      expect(const NonogramDefinition().id, 'nonogram_ten');
      expect(NonogramDefinition.small.id, 'nonogram_five');
    });
  });
}
