import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

/// Golden tests for the games and the shell chrome around them.
///
/// Every board here is **seeded**, so the same tiles appear on every run. An
/// unseeded board would produce a different image each time and the goldens
/// would be noise.
///
/// See design_system_golden_test.dart for why text renders as blocks and why
/// these are platform-sensitive.
///
/// Regenerate after an intentional visual change:
///   flutter test --update-goldens
Widget shellFor(GameDefinition definition, String title, {int bestScore = 0}) {
  return goldenHost(
    GameShell(definition: definition, title: title, bestScore: bestScore),
    center: false,
  );
}

Future<void> sizedPhone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(GoldenSize.phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('2048', () {
    testWidgets('board, light', (tester) async {
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const Game2048Definition(seed: 7), '2048', bestScore: 2048),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/game_2048_light.png'),
      );
    });

    testWidgets('board, dark', (tester) async {
      await sizedPhone(tester);

      await tester.pumpWidget(
        goldenHost(
          const GameShell(
            definition: Game2048Definition(seed: 7),
            title: '2048',
            bestScore: 2048,
          ),
          brightness: Brightness.dark,
          center: false,
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/game_2048_dark.png'),
      );
    });

    testWidgets('3x3 variant', (tester) async {
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const Game2048Definition(boardSize: 3, seed: 4), '2048 Tight'),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/game_2048_3x3.png'),
      );
    });
  });

  group('sliding puzzle', () {
    testWidgets('board, light', (tester) async {
      // Also the visual record of GameCapabilities.puzzle: this golden should
      // show a MOVES readout and no score or timer. If someone changes the
      // capability defaults, this image changes and the diff says so.
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const SlidingPuzzleDefinition(seed: 3), 'Sliding Puzzle'),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/sliding_puzzle_light.png'),
      );
    });

    testWidgets('board, dark', (tester) async {
      await sizedPhone(tester);

      await tester.pumpWidget(
        goldenHost(
          const GameShell(
            definition: SlidingPuzzleDefinition(seed: 3),
            title: 'Sliding Puzzle',
          ),
          brightness: Brightness.dark,
          center: false,
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/sliding_puzzle_dark.png'),
      );
    });
  });

  group('memory match', () {
    testWidgets('board, light', (tester) async {
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const MemoryMatchDefinition(seed: 11), 'Memory Match'),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/memory_match_light.png'),
      );
    });

    testWidgets('a revealed pair, dark', (tester) async {
      // Captures both card faces at once: one matched pair showing its icons,
      // the rest still face down. A single all-face-down golden would never
      // notice the front face regressing.
      await sizedPhone(tester);

      await tester.pumpWidget(
        goldenHost(
          const GameShell(
            definition: MemoryMatchDefinition(seed: 11),
            title: 'Memory Match',
          ),
          brightness: Brightness.dark,
          center: false,
        ),
      );
      await tester.pumpAndSettle();

      final board = MemoryBoard.deal(pairs: 8, columns: 4, random: Random(11));
      final partner = List.generate(board.cardCount, (i) => i)
          .firstWhere((i) => i != 0 && board.symbols[i] == board.symbols[0]);

      await tester.tap(find.byKey(memoryCardKey(0)));
      await tester.pump();
      await tester.tap(find.byKey(memoryCardKey(partner)));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/memory_match_revealed_dark.png'),
      );
    });
  });

  group('minesweeper', () {
    testWidgets('unopened board, light', (tester) async {
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const MinesweeperDefinition(seed: 4), 'Minesweeper'),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/minesweeper_light.png'),
      );
    });

    testWidgets('after the opening tap, with numbers and a flag', (tester) async {
      // The interesting golden. An unopened board is a grid of identical
      // squares; this one captures the number colour ramp, the revealed/hidden
      // contrast and a flag all at once.
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const MinesweeperDefinition(seed: 4), 'Minesweeper'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(minesweeperCellKey(40)));
      await tester.pumpAndSettle();

      // Flag a cell the opening cascade did not reach. Flagging a revealed cell
      // is a no-op, so picking index 0 blindly produced a golden with no flag in
      // it — the image looked fine and quietly covered less than it claimed.
      final opened = MinesweeperBoard.empty(columns: 9, rows: 9, mineCount: 10)
          .reveal(40, random: Random(4))!;
      final stillHidden = List.generate(opened.cellCount, (i) => i)
          .firstWhere((i) => opened.states[i] == CellState.hidden);

      await tester.longPress(find.byKey(minesweeperCellKey(stillHidden)));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/minesweeper_opened.png'),
      );
    });
  });

  group('dots and boxes', () {
    testWidgets('mid-game, with claimed boxes on both sides', (tester) async {
      // An empty grid is just dots. This plays a few turns so the golden
      // captures claimed boxes in both players' colours, drawn versus undrawn
      // edges, and the active-turn indicator.
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(
          const DotsAndBoxesDefinition(rows: 3, columns: 3, seed: 5),
          'Dots & Boxes',
        ),
      );
      await tester.pumpAndSettle();

      // Close the top-left box: three sides, then the fourth.
      const closing = [
        Edge(EdgeOrientation.horizontal, 0),
        Edge(EdgeOrientation.horizontal, 3),
        Edge(EdgeOrientation.vertical, 0),
        Edge(EdgeOrientation.vertical, 1),
      ];

      for (final edge in closing) {
        final finder = find.byKey(dotsEdgeKey(edge));
        if (finder.evaluate().isEmpty) continue;
        await tester.tap(finder, warnIfMissed: false);
        await tester.pump();
        // Let the opponent reply between the player's non-scoring moves.
        await tester.pump(const Duration(milliseconds: 600));
      }
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/dots_and_boxes_midgame.png'),
      );
    });
  });

  group('reaction', () {
    testWidgets('idle state', (tester) async {
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const ReactionDefinition(rounds: 5, seed: 2), 'Reaction'),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/reaction_idle.png'),
      );
    });

    testWidgets('the go state', (tester) async {
      // The one screen in the app that is deliberately loud. Worth a golden of
      // its own: if the green ever drifts toward the theme's muted palette the
      // game stops working, because the whole point is a signal you react to
      // without reading.
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const ReactionDefinition(rounds: 5, seed: 2), 'Reaction'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(reactionSurfaceKey), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 3600));

      // Settle before capturing. The frame on which the target appears is the
      // *first* frame of the colour transition, so capturing there records a
      // grey background under the word TAP — a golden that says "go" while
      // showing the idle colour, which is worse than no golden at all.
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/reaction_go.png'),
      );

      // Complete the round so no timer is left pending.
      await tester.tap(find.byKey(reactionSurfaceKey), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
    });
  });

  group('solitaire', () {
    testWidgets('fresh deal, light', (tester) async {
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const SolitaireDefinition(seed: 11), 'Solitaire'),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/solitaire_light.png'),
      );
    });

    testWidgets('after a draw, dark', (tester) async {
      // Card faces are deliberately *not* themed — a red suit has to stay red in
      // dark mode or it stops reading as one. This golden is what would catch a
      // well-meaning change that themes them.
      await sizedPhone(tester);

      await tester.pumpWidget(
        goldenHost(
          const GameShell(
            definition: SolitaireDefinition(seed: 11),
            title: 'Solitaire',
          ),
          brightness: Brightness.dark,
          center: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(solitaireStockKey));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/solitaire_drawn_dark.png'),
      );
    });
  });

  group('sudoku', () {
    SudokuBoard seededBoard() => SudokuBoard.generate(
          difficulty: SudokuDifficulty.easy,
          random: Random(5),
        );

    testWidgets('fresh board, light', (tester) async {
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(
          const SudokuDefinition(difficulty: SudokuDifficulty.easy, seed: 5),
          'Sudoku',
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/sudoku_light.png'),
      );
    });

    testWidgets('selection, notes and a clash, dark', (tester) async {
      // Four states in one image: the selected cell, its tinted peers, a pair of
      // clashing cells, and pencil marks. A fresh board shows none of them.
      await sizedPhone(tester);

      await tester.pumpWidget(
        goldenHost(
          const GameShell(
            definition: SudokuDefinition(
              difficulty: SudokuDifficulty.easy,
              seed: 5,
            ),
            title: 'Sudoku',
          ),
          brightness: Brightness.dark,
          center: false,
        ),
      );
      await tester.pumpAndSettle();

      final board = seededBoard();
      final empty = List<int>.generate(81, (i) => i)
          .where((i) => board.entries[i] == null)
          .toList();

      // Pencil marks in one cell.
      await tester.tap(find.byKey(sudokuCellKey(empty.first)));
      await tester.pump();
      await tester.tap(find.byKey(sudokuNotesKey));
      await tester.pump();
      for (final digit in [1, 4, 9]) {
        await tester.tap(find.byKey(sudokuPadKey(digit)));
        await tester.pump();
      }
      await tester.tap(find.byKey(sudokuNotesKey));
      await tester.pump();

      // A wrong digit that clashes with a given in the same row.
      final clashing = empty.last;
      final duplicate = List<int>.generate(9, (c) => board.rowOf(clashing) * 9 + c)
          .firstWhere((i) => i != clashing && board.entries[i] != null);

      await tester.tap(find.byKey(sudokuCellKey(clashing)));
      await tester.pump();
      await tester.tap(find.byKey(sudokuPadKey(board.entries[duplicate]!)));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/sudoku_marked_dark.png'),
      );
    });
  });

  group('nonogram', () {
    testWidgets('fresh 10x10 board, light', (tester) async {
      // Also the record of the clue gutters and the heavy rules every five
      // cells: if either regresses the grid stops being countable, and counting
      // is the whole game.
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const NonogramDefinition(seed: 8), 'Nonogram'),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/nonogram_light.png'),
      );
    });

    testWidgets('filled and crossed cells, dark', (tester) async {
      // A fresh board contains only one of the three cell states. This one has
      // all of them on screen at once.
      await sizedPhone(tester);

      await tester.pumpWidget(
        goldenHost(
          const GameShell(
            definition: NonogramDefinition(seed: 8),
            title: 'Nonogram',
          ),
          brightness: Brightness.dark,
          center: false,
        ),
      );
      await tester.pumpAndSettle();

      // A diagonal of filled cells and a column of crosses — arbitrary marks,
      // chosen to be obvious in the image rather than to be a real solve.
      for (final index in [0, 11, 22, 33, 44, 55]) {
        await tester.tap(find.byKey(nonogramCellKey(index)));
        await tester.pump();
      }
      for (final index in [5, 15, 25]) {
        await tester.tap(find.byKey(nonogramCellKey(index)));
        await tester.pump();
        await tester.tap(find.byKey(nonogramCellKey(index)));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/nonogram_marked_dark.png'),
      );
    });
  });

  group('word search', () {
    /// Rebuilds the grid the seeded view deals, so the golden can drag along a
    /// real word instead of guessing at coordinates.
    WordSearchGrid seededGrid() {
      final rng = Random(12);
      final words = packById('animals').sample(6, maxLength: 10, random: rng);
      return WordSearchGrid.generate(words: words, size: 10, random: rng);
    }

    testWidgets('fresh board, light', (tester) async {
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(
          const WordSearchDefinition(wordCount: 6, packId: 'animals', seed: 12),
          'Word Search',
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/word_search_light.png'),
      );
    });

    testWidgets('a found word and a live drag, dark', (tester) async {
      // The three cell states at once: plain, found, and under the finger. A
      // fresh-board golden alone would never notice the highlight colours
      // regressing, since a fresh board contains neither.
      await sizedPhone(tester);

      await tester.pumpWidget(
        goldenHost(
          const GameShell(
            definition: WordSearchDefinition(
              wordCount: 6,
              packId: 'animals',
              seed: 12,
            ),
            title: 'Word Search',
          ),
          brightness: Brightness.dark,
          center: false,
        ),
      );
      await tester.pumpAndSettle();

      final grid = seededGrid();
      final solved = grid.words.first;
      final dragging = grid.words[1];

      Offset centreOf(int index) =>
          tester.getCenter(find.byKey(wordSearchCellKey(index)));

      // Find the first word outright.
      final finder = await tester.startGesture(centreOf(solved.start));
      await tester.pump();
      await finder.moveTo(centreOf(solved.end));
      await tester.pump();
      await finder.up();
      await tester.pumpAndSettle();

      // Leave the second one half-selected under the finger.
      final live = await tester.startGesture(centreOf(dragging.start));
      await tester.pump();
      await live.moveTo(centreOf(dragging.cells[dragging.cells.length ~/ 2]));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/word_search_active_dark.png'),
      );

      // Release, or the test ends with a pointer still down.
      await live.up();
      await tester.pumpAndSettle();
    });
  });

  group('shell overlays', () {
    testWidgets('paused', (tester) async {
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const Game2048Definition(seed: 7), '2048'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(GameShell),
        matchesGoldenFile('goldens/shell_paused.png'),
      );
    });

    testWidgets('quit confirmation, with the pause overlay suppressed', (tester) async {
      // Guards the fix for a real bug: confirming exit pauses the session, which
      // used to render the pause overlay behind the dialog and put two Quit
      // buttons on screen at once.
      await sizedPhone(tester);

      await tester.pumpWidget(
        shellFor(const Game2048Definition(seed: 7), '2048'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Exit'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shell_quit_dialog.png'),
      );
    });
  });
}
