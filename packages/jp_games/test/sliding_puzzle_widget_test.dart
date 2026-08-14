import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

Widget host({int boardSize = 4, int seed = 3}) {
  return MaterialApp(
    theme: JpTheme.light(),
    home: GameShell(
      definition: SlidingPuzzleDefinition(boardSize: boardSize, seed: seed),
      title: 'Sliding Puzzle',
    ),
  );
}

/// Reads a stat by its label.
String statValue(WidgetTester tester, String label) {
  final column = find.ancestor(of: find.text(label), matching: find.byType(Column));
  final texts = tester.widgetList<Text>(
    find.descendant(of: column.first, matching: find.byType(Text)),
  );
  return texts.last.data ?? '';
}

void main() {
  group('shell adapts to the game', () {
    testWidgets('shows moves but neither score nor timer', (tester) async {
      // The payoff of GameCapabilities: the same shell that renders a score and
      // a clock for 2048 renders neither here, and neither game knows about the
      // other.
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('MOVES'), findsOneWidget);
      expect(find.text('SCORE'), findsNothing);
      expect(find.text('BEST'), findsNothing);
      expect(find.text('TIME'), findsNothing);
    });

    testWidgets('renders every tile except the blank', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      // 4x4 has 15 numbered tiles; the blank renders nothing.
      final numbers = tester
          .widgetList<Text>(
            find.descendant(of: find.byType(SlidingPuzzleView), matching: find.byType(Text)),
          )
          .map((t) => int.tryParse(t.data ?? ''))
          .whereType<int>()
          .toList();

      expect(numbers.length, 15);
      expect(numbers.toSet().length, 15, reason: 'every tile appears exactly once');
      expect(numbers.contains(0), isFalse, reason: 'the blank must not be drawn');
    });
  });

  group('input', () {
    testWidgets('tapping a movable tile increments the move count', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      expect(statValue(tester, 'MOVES'), '0');

      // Find a tile that is currently movable by consulting the same rules the
      // view uses, rather than guessing at a board position.
      final puzzle = SlidingPuzzle.shuffled(random: _seeded(3));
      final movableValue = puzzle.tiles[puzzle.movableTiles.first];

      await tester.tap(find.text('$movableValue'));
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '1');
    });

    testWidgets('tapping a stuck tile does not count as a move', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      final puzzle = SlidingPuzzle.shuffled(random: _seeded(3));
      final stuckIndex = List.generate(puzzle.tiles.length, (i) => i).firstWhere(
        (i) => puzzle.tiles[i] != 0 && !puzzle.canMove(i),
      );

      await tester.tap(find.text('${puzzle.tiles[stuckIndex]}'));
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0',
          reason: 'a tile that cannot move must not advance the counter');
    });

    testWidgets('input is ignored while paused', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      final puzzle = SlidingPuzzle.shuffled(random: _seeded(3));
      final movableValue = puzzle.tiles[puzzle.movableTiles.first];

      // The overlay covers the board, so this tap should not reach a tile at
      // all — asserting on the counter proves it either way.
      await tester.tap(find.text('$movableValue'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
    });
  });

  group('board sizes', () {
    testWidgets('renders a 3x3 variant', (tester) async {
      await tester.pumpWidget(host(boardSize: 3));
      await tester.pump();

      expect(find.byType(SlidingPuzzleView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('definition', () {
    test('ids are distinct per board size', () {
      expect(const SlidingPuzzleDefinition().id, 'sliding_puzzle_4x4');
      expect(const SlidingPuzzleDefinition(boardSize: 3).id, 'sliding_puzzle_3x3');
    });

    test('declares itself a puzzle: moves only', () {
      final capabilities = const SlidingPuzzleDefinition().capabilities;
      expect(capabilities.showsMoves, isTrue);
      expect(capabilities.showsScore, isFalse);
      expect(capabilities.showsTimer, isFalse);
    });
  });
}

/// Mirrors the seed the view uses, so a test can reason about the same board the
/// widget dealt rather than guessing at positions.
Random _seeded(int seed) => Random(seed);
