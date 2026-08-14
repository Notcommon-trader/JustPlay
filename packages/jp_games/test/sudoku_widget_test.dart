import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

const int kSeed = 5;

Widget host() {
  return MaterialApp(
    theme: JpTheme.light(),
    home: const GameShell(
      definition: SudokuDefinition(
        difficulty: SudokuDifficulty.easy,
        seed: kSeed,
      ),
      title: 'Sudoku',
    ),
  );
}

/// The board the seeded view will have generated.
SudokuBoard expectedBoard() => SudokuBoard.generate(
      difficulty: SudokuDifficulty.easy,
      random: Random(kSeed),
    );

int firstEmpty(SudokuBoard board) =>
    List<int>.generate(81, (i) => i).firstWhere((i) => board.entries[i] == null);

String statValue(WidgetTester tester, String label) {
  final column = find.ancestor(of: find.text(label), matching: find.byType(Column));
  final texts = tester.widgetList<Text>(
    find.descendant(of: column.first, matching: find.byType(Text)),
  );
  return texts.last.data ?? '';
}

/// The digit currently drawn in a cell, or null if it is empty.
///
/// Scoped to the cell so pencil marks and the number pad cannot be mistaken for
/// the cell's own digit.
String? cellDigit(WidgetTester tester, int index) {
  final texts = tester.widgetList<Text>(
    find.descendant(
      of: find.byKey(sudokuCellKey(index)),
      matching: find.byType(Text),
    ),
  );
  if (texts.isEmpty) return null;
  return texts.length == 1 ? texts.single.data : null;
}

/// Pencil marks drawn in a cell.
Set<String> cellNotes(WidgetTester tester, int index) {
  final texts = tester.widgetList<Text>(
    find.descendant(
      of: find.byKey(sudokuCellKey(index)),
      matching: find.byType(Text),
    ),
  );
  // A cell holding a digit renders exactly one Text; notes render one per mark.
  return texts.length > 1 ? {for (final t in texts) t.data!} : const {};
}

Color cellColour(WidgetTester tester, int index) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byKey(sudokuCellKey(index)),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration! as BoxDecoration).color!;
}

Future<void> phoneSurface(WidgetTester tester) async {
  // Taller than the usual phone golden: the sudoku screen carries a grid, a
  // control row and a number pad, and a short surface would overflow.
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> tapCell(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(sudokuCellKey(index)));
  await tester.pumpAndSettle();
}

Future<void> tapDigit(WidgetTester tester, int digit) async {
  await tester.tap(find.byKey(sudokuPadKey(digit)));
  await tester.pumpAndSettle();
}

void main() {
  group('shell integration', () {
    testWidgets('shows moves and time but no score', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('MOVES'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('SCORE'), findsNothing);
    });

    testWidgets('draws all 81 cells and a full number pad', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.byKey(sudokuCellKey(80)), findsOneWidget);
      for (var digit = 1; digit <= 9; digit++) {
        expect(find.byKey(sudokuPadKey(digit)), findsOneWidget);
      }
    });
  });

  group('entering digits', () {
    testWidgets('a digit goes into the selected cell', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final index = firstEmpty(expectedBoard());
      await tapCell(tester, index);
      await tapDigit(tester, 5);

      expect(cellDigit(tester, index), '5');
      expect(statValue(tester, 'MOVES'), '1');
    });

    testWidgets('a digit with nothing selected does nothing', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tapDigit(tester, 5);
      expect(statValue(tester, 'MOVES'), '0');
    });

    testWidgets('tapping the same digit again clears the cell', (tester) async {
      // Correcting a mistake should not require finding the erase button for
      // something the player has already pointed at.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final index = firstEmpty(expectedBoard());
      await tapCell(tester, index);
      await tapDigit(tester, 5);
      await tapDigit(tester, 5);

      expect(cellDigit(tester, index), isNull);
    });

    testWidgets('givens cannot be overwritten', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final board = expectedBoard();
      final given =
          List<int>.generate(81, (i) => i).firstWhere((i) => board.isGiven(i));
      final was = cellDigit(tester, given);

      await tapCell(tester, given);
      await tapDigit(tester, board.givens[given]! % 9 + 1);

      expect(cellDigit(tester, given), was);
      expect(statValue(tester, 'MOVES'), '0');
    });

    testWidgets('erase empties the selected cell', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final index = firstEmpty(expectedBoard());
      await tapCell(tester, index);
      await tapDigit(tester, 5);

      await tester.tap(find.byKey(sudokuEraseKey));
      await tester.pumpAndSettle();

      expect(cellDigit(tester, index), isNull);
    });
  });

  group('pencil marks', () {
    testWidgets('notes mode writes marks instead of digits', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final index = firstEmpty(expectedBoard());
      await tapCell(tester, index);

      await tester.tap(find.byKey(sudokuNotesKey));
      await tester.pumpAndSettle();

      await tapDigit(tester, 3);
      await tapDigit(tester, 7);

      expect(cellNotes(tester, index), {'3', '7'});
      expect(cellDigit(tester, index), isNull);
    });

    testWidgets('leaving notes mode writes digits again', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final index = firstEmpty(expectedBoard());
      await tapCell(tester, index);

      await tester.tap(find.byKey(sudokuNotesKey));
      await tester.pumpAndSettle();
      await tapDigit(tester, 3);

      await tester.tap(find.byKey(sudokuNotesKey));
      await tester.pumpAndSettle();
      await tapDigit(tester, 4);

      expect(cellDigit(tester, index), '4');
    });
  });

  group('highlighting', () {
    testWidgets('the selected cell is picked out from its peers', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final scheme = JpTheme.light().colorScheme;
      final board = expectedBoard();
      final index = firstEmpty(board);

      await tapCell(tester, index);

      expect(cellColour(tester, index), scheme.primaryContainer);

      // A cell in the same row is tinted, but not the same colour as the
      // selection — and a cell sharing nothing is left alone.
      final peer = List<int>.generate(9, (c) => board.rowOf(index) * 9 + c)
          .firstWhere((i) => i != index && board.entries[i] == null);
      expect(cellColour(tester, peer), isNot(scheme.primaryContainer));
      expect(cellColour(tester, peer), isNot(scheme.surface));
    });

    testWidgets('a clash paints both cells, not just the newer one', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final scheme = JpTheme.light().colorScheme;
      final board = expectedBoard();
      final index = firstEmpty(board);
      final row = board.rowOf(index);

      final duplicate = List<int>.generate(9, (c) => row * 9 + c)
          .firstWhere((i) => i != index && board.entries[i] != null);

      await tapCell(tester, index);
      await tapDigit(tester, board.entries[duplicate]!);

      expect(cellColour(tester, index), scheme.errorContainer);
      expect(cellColour(tester, duplicate), scheme.errorContainer);
    });
  });

  group('hints', () {
    testWidgets('fill the selected cell with the right digit', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final board = expectedBoard();
      final index = firstEmpty(board);

      await tapCell(tester, index);
      await tester.tap(find.byKey(sudokuHintKey));
      await tester.pumpAndSettle();

      expect(cellDigit(tester, index), '${board.solution[index]}');
    });

    testWidgets('with nothing selected, fill the first unsolved cell',
        (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final board = expectedBoard();
      final index = board.firstUnsolvedIndex!;

      await tester.tap(find.byKey(sudokuHintKey));
      await tester.pumpAndSettle();

      expect(cellDigit(tester, index), '${board.solution[index]}');
    });
  });

  group('finishing', () {
    testWidgets('completing the grid wins', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final board = expectedBoard();
      for (var index = 0; index < 81; index++) {
        if (board.isGiven(index)) continue;
        await tapCell(tester, index);
        await tester.tap(find.byKey(sudokuPadKey(board.solution[index])));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('You win'), findsOneWidget);
    });

    testWidgets('restarting clears the player\'s entries', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final index = firstEmpty(expectedBoard());
      await tapCell(tester, index);
      await tapDigit(tester, 5);

      await tester.tap(find.byTooltip('Restart'));
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
      expect(cellDigit(tester, index), isNull);
    });

    testWidgets('input is ignored while paused', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(sudokuCellKey(firstEmpty(expectedBoard()))),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(sudokuPadKey(5)), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
    });
  });

  group('definition', () {
    test('id encodes the difficulty', () {
      expect(const SudokuDefinition().id, 'sudoku_medium');
      expect(
        const SudokuDefinition(difficulty: SudokuDifficulty.hard).id,
        'sudoku_hard',
      );
    });
  });
}
