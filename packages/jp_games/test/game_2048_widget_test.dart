import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

Widget host({int boardSize = 4, int seed = 7, VoidCallback? onExit}) {
  return MaterialApp(
    theme: JpTheme.light(),
    home: GameShell(
      definition: Game2048Definition(boardSize: boardSize, seed: seed),
      title: '2048',
      bestScore: 500,
      onExit: onExit,
    ),
  );
}

/// Sends an arrow key. The board supports keyboard input so it can be played on
/// desktop during development, and it makes swipes testable without simulating
/// pointer physics.
Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Values of the tiles currently on the board.
///
/// Scoped to Board2048View deliberately. Searching the whole screen also picks
/// up the score, best and move counters in the shell's stat bar, which is how
/// the first version of this helper reported four tiles on a two-tile board.
List<int> tileValues(WidgetTester tester) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byType(Board2048View), matching: find.byType(Text)),
  );

  return [
    for (final t in texts) ?int.tryParse(t.data ?? ''),
  ];
}

/// Reads a stat by its label, so assertions do not depend on a number appearing
/// exactly once anywhere on screen.
String statValue(WidgetTester tester, String label) {
  final column = find.ancestor(
    of: find.text(label),
    matching: find.byType(Column),
  );
  final texts = tester.widgetList<Text>(
    find.descendant(of: column.first, matching: find.byType(Text)),
  );
  return texts.last.data ?? '';
}

void main() {
  group('shell integration', () {
    testWidgets('renders the board inside the shell chrome', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('2048'), findsOneWidget, reason: 'app bar title');
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('BEST'), findsOneWidget);
      expect(find.text('MOVES'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.byType(Board2048View), findsOneWidget);
    });

    testWidgets('a new game starts with exactly two tiles', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      // Empty cells render nothing, so every number on the board is a tile.
      final tiles = tileValues(tester);
      expect(tiles.length, 2);
      expect(tiles.every((v) => v == 2 || v == 4), isTrue);
    });

    testWidgets('the best score passed to the shell is displayed', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      expect(statValue(tester, 'BEST'), '500');
    });
  });

  group('input', () {
    testWidgets('an arrow key that changes the board increments the move count',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      // Seeded, so the starting layout is fixed; try each direction until one
      // actually moves something. Asserting on a specific direction would make
      // the test depend on the spawn positions rather than on the behaviour.
      for (final key in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
      ]) {
        await press(tester, key);
        if (statValue(tester, 'MOVES') != '0') break;
      }
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), isNot('0'),
          reason: 'at least one direction must have moved something');
      expect(tileValues(tester).length, 3, reason: 'a successful move spawns one new tile');
    });

    testWidgets('input is ignored while paused', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);

      for (final key in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
      ]) {
        await press(tester, key);
      }

      await tester.pumpAndSettle();
      expect(statValue(tester, 'MOVES'), '0', reason: 'a paused game must not accept play');
      expect(find.text('Paused'), findsOneWidget);
    });
  });

  group('shell controls', () {
    testWidgets('pause shows the overlay and resume dismisses it', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsNothing);
    });

    testWidgets('quitting mid-game asks for confirmation first', (tester) async {
      var exited = false;
      await tester.pumpWidget(host(onExit: () => exited = true));
      await tester.pump();

      await tester.tap(find.byTooltip('Exit'));
      await tester.pumpAndSettle();

      expect(find.text('Quit this game?'), findsOneWidget);
      expect(exited, isFalse, reason: 'Exiting must not happen before confirming.');

      // The pause overlay must stay hidden behind the dialog, or the player sees
      // two Quit buttons at once.
      expect(find.text('Paused'), findsNothing);
      expect(find.text('Quit'), findsOneWidget);

      await tester.tap(find.text('Keep playing'));
      await tester.pumpAndSettle();
      expect(exited, isFalse);
      expect(find.text('Paused'), findsOneWidget,
          reason: 'declining leaves the game paused, not running');

      await tester.tap(find.byTooltip('Exit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quit'));
      await tester.pumpAndSettle();
      expect(exited, isTrue);
    });

    testWidgets('restart deals a fresh board and resets the counters', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      for (final key in [LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowUp]) {
        await press(tester, key);
      }

      await tester.tap(find.byTooltip('Restart'));
      await tester.pumpAndSettle();

      expect(tileValues(tester).length, 2, reason: 'a restart deals a fresh two-tile board');
      expect(statValue(tester, 'MOVES'), '0');
      expect(statValue(tester, 'BEST'), '500', reason: 'the target to beat survives a restart');
    });
  });

  group('board sizes', () {
    testWidgets('renders a 3x3 variant', (tester) async {
      await tester.pumpWidget(host(boardSize: 3));
      await tester.pump();

      expect(find.byType(Board2048View), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a 5x5 variant', (tester) async {
      await tester.pumpWidget(host(boardSize: 5));
      await tester.pump();

      expect(find.byType(Board2048View), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('definition', () {
    test('ids are stable and distinct per board size', () {
      // Save keys and statistics hang off these, so a collision would merge two
      // games' histories.
      expect(const Game2048Definition().id, 'game_2048');
      expect(const Game2048Definition(boardSize: 5).id, 'game_2048_5x5');
      expect(const Game2048Definition(boardSize: 3).id, 'game_2048_3x3');
    });

    test('names are localization keys, never literals', () {
      expect(const Game2048Definition().nameKey, startsWith('game.'));
      expect(const Game2048Definition().descriptionKey, startsWith('game.'));
    });
  });
}
