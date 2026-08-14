import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

const int kSeed = 4;

Widget host() {
  return MaterialApp(
    theme: JpTheme.light(),
    home: const GameShell(
      definition: MinesweeperDefinition(seed: kSeed),
      title: 'Minesweeper',
    ),
  );
}

String statValue(WidgetTester tester, String label) {
  final column = find.ancestor(of: find.text(label), matching: find.byType(Column));
  final texts = tester.widgetList<Text>(
    find.descendant(of: column.first, matching: find.byType(Text)),
  );
  return texts.last.data ?? '';
}

Future<void> phoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(GoldenSize.phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Taps a cell.
///
/// [covered] is for the paused case, where the shell's overlay sits over the
/// board and the tap legitimately does not reach a cell. Without it the test
/// framework warns about a missed hit test on every run, which trains everyone
/// to ignore that warning.
Future<void> tapCell(WidgetTester tester, int index, {bool covered = false}) async {
  await tester.tap(find.byKey(minesweeperCellKey(index)), warnIfMissed: !covered);
  await tester.pump();
}

Future<void> longPressCell(WidgetTester tester, int index) async {
  await tester.longPress(find.byKey(minesweeperCellKey(index)));
  await tester.pump();
}

/// The board the view will produce after an opening tap at [first], so a test
/// can locate a real mine rather than hunting for one by trial and error.
MinesweeperBoard openedBoard(int first) =>
    MinesweeperBoard.empty(columns: 9, rows: 9, mineCount: 10)
        .reveal(first, random: Random(kSeed))!;

void main() {
  group('shell integration', () {
    testWidgets('shows moves and timer but no score', (tester) async {
      // Minesweeper has never had a score, and inventing one would be noise.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('MOVES'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('SCORE'), findsNothing);
    });

    testWidgets('shows the mines-remaining counter', (tester) async {
      // Game-specific, so it lives with the board rather than the shell.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.byIcon(Icons.flag), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });
  });

  group('revealing', () {
    testWidgets('the opening tap never loses and opens a region', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tapCell(tester, 40);
      await tester.pumpAndSettle();

      expect(find.text('Out of moves'), findsNothing, reason: 'first tap must be safe');
      expect(statValue(tester, 'MOVES'), '1');
    });

    testWidgets('revealing a mine ends the game', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tapCell(tester, 40);
      await tester.pumpAndSettle();

      final board = openedBoard(40);
      final mine = List.generate(board.cellCount, (i) => i)
          .firstWhere((i) => board.mines[i] && board.states[i] != CellState.revealed);

      await tapCell(tester, mine);
      await tester.pumpAndSettle();

      // The shell's loss overlay.
      expect(find.text('Out of moves'), findsOneWidget);
    });
  });

  group('flagging', () {
    testWidgets('long press flags a cell and decrements the counter',
        (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await longPressCell(tester, 0);
      await tester.pumpAndSettle();

      // One flag on the board plus the counter icon.
      expect(find.byIcon(Icons.flag), findsNWidgets(2));
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('flagging is not counted as a move', (tester) async {
      // It is bookkeeping. Counting it would punish careful players in the one
      // statistic they are trying to minimise.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await longPressCell(tester, 0);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
    });

    testWidgets('a flagged cell cannot be revealed by tapping', (tester) async {
      // Protects against ending a game by mis-tapping a known mine.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await longPressCell(tester, 0);
      await tester.pumpAndSettle();

      await tapCell(tester, 0);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0', reason: 'the tap should be ignored');
      expect(find.byIcon(Icons.flag), findsNWidgets(2), reason: 'the flag stays');
    });
  });

  group('pause', () {
    testWidgets('input is ignored while paused', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      await tapCell(tester, 40);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
    });
  });

  group('definition', () {
    test('ids are distinct per difficulty', () {
      expect(MinesweeperDefinition.beginner.id, 'minesweeper_beginner');
      expect(MinesweeperDefinition.intermediate.id, 'minesweeper_intermediate');
    });

    test('uses the classic grid sizes', () {
      // Players calibrate against these, so they are not free to drift.
      expect(MinesweeperDefinition.beginner.columns, 9);
      expect(MinesweeperDefinition.beginner.mineCount, 10);
    });
  });
}
