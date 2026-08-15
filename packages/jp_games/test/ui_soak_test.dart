import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

/// Random input fired at every screen.
///
/// The agent in jp_core proves the *rules* survive extended play. This proves
/// the *widgets* do — a different bug class entirely: hit-testing outside a
/// parent's bounds, a timer firing after dispose, a setState on an unmounted
/// State, an overflow when a board reflows mid-animation.
///
/// It taps where a confused thumb would: on the board, off the board, twice in
/// the same frame, during animations, while paused, and on the way out of the
/// screen. Any exception fails the test, because in a widget test an unhandled
/// exception is a red screen in production.
const List<({GameDefinition definition, String title})> games = [
  (definition: Game2048Definition(seed: 1), title: '2048'),
  (definition: Game2048Definition(boardSize: 3, seed: 2), title: '2048 Tight'),
  (definition: SlidingPuzzleDefinition(seed: 3), title: 'Sliding Puzzle'),
  (definition: MemoryMatchDefinition(seed: 4), title: 'Memory Match'),
  (definition: MinesweeperDefinition(seed: 5), title: 'Minesweeper'),
  (definition: DotsAndBoxesDefinition(seed: 6), title: 'Dots & Boxes'),
  (definition: WordSearchDefinition(seed: 7), title: 'Word Search'),
  (definition: NonogramDefinition(seed: 8), title: 'Nonogram'),
  (definition: SudokuDefinition(seed: 9), title: 'Sudoku'),
  (definition: SolitaireDefinition(seed: 10), title: 'Solitaire'),
  (definition: ReactionDefinition(seed: 11), title: 'Reaction'),
];

Widget host(GameDefinition definition, String title) {
  return MaterialApp(
    theme: JpTheme.light(),
    home: GameShell(definition: definition, title: title),
  );
}

Future<void> phone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// A point anywhere on screen, including outside the board.
Offset randomPoint(Random random) =>
    Offset(random.nextDouble() * 390, random.nextDouble() * 900);

void main() {
  group('random tapping never throws', () {
    for (final game in games) {
      testWidgets(game.title, (tester) async {
        await phone(tester);
        await tester.pumpWidget(host(game.definition, game.title));
        await tester.pumpAndSettle();

        final random = Random(1234);
        for (var i = 0; i < 120; i++) {
          await tester.tapAt(randomPoint(random));
          // Sometimes settle, sometimes do not — a tap landing mid-animation is
          // the case that finds reentrancy, and always settling would hide it.
          if (random.nextBool()) {
            await tester.pump(const Duration(milliseconds: 16));
          } else {
            await tester.pumpAndSettle();
          }
        }

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('random dragging never throws', () {
    for (final game in games) {
      testWidgets(game.title, (tester) async {
        await phone(tester);
        await tester.pumpWidget(host(game.definition, game.title));
        await tester.pumpAndSettle();

        final random = Random(99);
        for (var i = 0; i < 40; i++) {
          final from = randomPoint(random);
          final to = randomPoint(random);

          final gesture = await tester.startGesture(from);
          await tester.pump(const Duration(milliseconds: 16));
          await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
          await tester.pump(const Duration(milliseconds: 16));
          await gesture.moveTo(to);
          await tester.pump(const Duration(milliseconds: 16));
          await gesture.up();
          await tester.pumpAndSettle();
        }

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the board survives being torn down mid-play', () {
    for (final game in games) {
      testWidgets(game.title, (tester) async {
        // Leaving a screen while something is animating or a timer is pending is
        // ordinary player behaviour and a classic source of "setState called
        // after dispose". testWidgets also fails on a leaked timer, so this
        // covers both.
        await phone(tester);
        await tester.pumpWidget(host(game.definition, game.title));
        await tester.pumpAndSettle();

        final random = Random(7);
        for (var i = 0; i < 10; i++) {
          await tester.tapAt(randomPoint(random));
        }
        // Tear down on the very next frame, with animations still running.
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('shell controls under abuse', () {
    for (final game in games) {
      testWidgets(game.title, (tester) async {
        await phone(tester);
        await tester.pumpWidget(host(game.definition, game.title));
        await tester.pumpAndSettle();

        // Hammer pause and restart, interleaved with board taps. Restarting
        // while paused, and pausing during a restart, are the states nobody
        // tests by hand.
        final random = Random(3);
        for (var i = 0; i < 12; i++) {
          await tester.tap(find.byTooltip('Restart'));
          await tester.pump(const Duration(milliseconds: 8));

          final pause = find.byTooltip('Pause');
          if (pause.evaluate().isNotEmpty) {
            await tester.tap(pause);
            await tester.pump(const Duration(milliseconds: 8));
          }

          await tester.tapAt(randomPoint(random));
          await tester.pump(const Duration(milliseconds: 8));

          final resume = find.byTooltip('Resume');
          if (resume.evaluate().isNotEmpty) {
            await tester.tap(resume);
            await tester.pump(const Duration(milliseconds: 8));
          }
        }

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('layout holds at awkward sizes', () {
    // Overflow is reported as an exception in tests, so a board that does not
    // fit fails here rather than shipping with a yellow-and-black stripe.
    const sizes = <Size>[
      Size(320, 568), // the smallest phone still worth supporting
      Size(360, 640), // a very common budget Android
      Size(412, 915), // a large modern phone
      Size(600, 1024), // a small tablet
    ];

    for (final size in sizes) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final game in games) {
          // Mount each game fresh. Swapping one definition for another in place
          // keeps the shell's State — and with it the previous game's session —
          // which the real app never does, because every game is pushed as its
          // own route. Without this the failures reported here belong to
          // whichever game happened to be on screen before.
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
          await tester.pumpAndSettle();

          await tester.pumpWidget(host(game.definition, game.title));
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '${game.title} does not fit ${size.width}x${size.height}',
          );
        }
      });
    }
  });
}
