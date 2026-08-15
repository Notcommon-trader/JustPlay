import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

/// Accessibility guidelines, checked against every game.
///
/// These are Flutter's own audits, not opinions: [androidTapTargetGuideline] is
/// Material's 48dp minimum, [textContrastGuideline] is WCAG AA. Both are
/// requirements a store review can cite, and both are invisible in a screenshot
/// — a control can look fine and still be too small to hit reliably.
///
/// Where a game cannot meet a guideline, the exception is recorded here with the
/// reason rather than the test being deleted. A silently missing check is worse
/// than a documented gap.
Widget host(GameDefinition definition, String title) {
  return MaterialApp(
    theme: JpTheme.light(),
    home: GameShell(definition: definition, title: title),
  );
}

/// Games whose board is a dense grid of cells.
///
/// A 9x9 sudoku on a 390pt-wide phone gives each cell about 39pt. Meeting the
/// 48dp target would mean a board wider than the screen, so the guideline cannot
/// be met without changing the game. This is the same trade every sudoku and
/// minesweeper app makes, and it is a real accessibility cost, not a
/// technicality — it is recorded in docs/TESTING.md rather than hidden.
const List<({GameDefinition definition, String title})> denseGridGames = [
  (definition: SudokuDefinition(seed: 1), title: 'Sudoku'),
  (definition: MinesweeperDefinition(seed: 1), title: 'Minesweeper'),
  (definition: NonogramDefinition(seed: 1), title: 'Nonogram'),
  (definition: WordSearchDefinition(seed: 1), title: 'Word Search'),
  (definition: SolitaireDefinition(seed: 1), title: 'Solitaire'),
  // Edges are the gaps between dots. Their tap area went from 10pt to 24pt,
  // which is a real improvement to a genuinely frustrating control, but still
  // short of 48. Reaching it properly means hit-testing the nearest edge across
  // a whole box quadrant — see the note on `_dotSize`.
  (definition: DotsAndBoxesDefinition(seed: 1), title: 'Dots & Boxes'),
];

/// Games whose controls are large enough to meet the tap-target guideline.
const List<({GameDefinition definition, String title})> roomyGames = [
  (definition: Game2048Definition(seed: 1), title: '2048'),
  (definition: SlidingPuzzleDefinition(seed: 1), title: 'Sliding Puzzle'),
  (definition: MemoryMatchDefinition(seed: 1), title: 'Memory Match'),
  (definition: ReactionDefinition(seed: 1), title: 'Reaction'),
];

Future<void> phone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('text contrast meets WCAG AA', () {
    for (final game in [...roomyGames, ...denseGridGames]) {
      testWidgets(game.title, (tester) async {
        await phone(tester);
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(host(game.definition, game.title));
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });

  group('tap targets meet the 48dp minimum', () {
    for (final game in roomyGames) {
      testWidgets(game.title, (tester) async {
        await phone(tester);
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(host(game.definition, game.title));
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  group('every tappable control has a label', () {
    // A button an assistive technology cannot name is a button a screen-reader
    // user cannot use, however large and well-contrasted it is.
    for (final game in [...roomyGames, ...denseGridGames]) {
      testWidgets(game.title, (tester) async {
        await phone(tester);
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(host(game.definition, game.title));
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  group('the shell chrome', () {
    testWidgets('app bar controls are reachable and named', (tester) async {
      await phone(tester);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(host(const Game2048Definition(seed: 1), '2048'));
      await tester.pumpAndSettle();

      // Tooltips are what make these announce themselves.
      expect(find.byTooltip('Exit'), findsOneWidget);
      expect(find.byTooltip('Restart'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the game-over overlay is readable', (tester) async {
      await phone(tester);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(host(const Game2048Definition(seed: 1), '2048'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      // The overlay sits over a dimmed board; contrast there is easy to get
      // wrong and impossible to notice on a bright desk.
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      expect(find.text('Paused'), findsOneWidget);

      handle.dispose();
    });
  });
}
