import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

const int kSeed = 11;

Widget host({int drawCount = 1, int seed = kSeed}) {
  return MaterialApp(
    theme: JpTheme.light(),
    home: GameShell(
      definition: SolitaireDefinition(drawCount: drawCount, seed: seed),
      title: 'Solitaire',
    ),
  );
}

/// The game the seeded view will have dealt.
Solitaire expectedGame({int drawCount = 1, int seed = kSeed}) =>
    Solitaire.deal(drawCount: drawCount, random: Random(seed));

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

/// Whether [card] is currently drawn anywhere on screen.
bool isVisible(WidgetTester tester, PlayingCard card) =>
    find.byKey(solitaireCardKey(card)).evaluate().isNotEmpty;

void main() {
  group('shell integration', () {
    testWidgets('shows score, moves and time', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('MOVES'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
    });

    testWidgets('lays out seven piles, four foundations and a stock',
        (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      for (var pile = 0; pile < 7; pile++) {
        expect(find.byKey(solitaireTableauKey(pile)), findsOneWidget);
      }
      for (final suit in Suit.values) {
        expect(find.byKey(solitaireFoundationKey(suit)), findsOneWidget);
      }
      expect(find.byKey(solitaireStockKey), findsOneWidget);
      expect(find.byKey(solitaireWasteKey), findsOneWidget);
    });

    testWidgets('shows the face-up card of every tableau pile', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final game = expectedGame();
      for (final pile in game.tableau) {
        expect(isVisible(tester, pile.last), isTrue);
      }
    });
  });

  group('the stock', () {
    testWidgets('tapping it turns a card onto the waste', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final game = expectedGame();
      final next = game.draw()!;

      await tester.tap(find.byKey(solitaireStockKey));
      await tester.pumpAndSettle();

      expect(isVisible(tester, next.wasteTop!), isTrue);
      expect(statValue(tester, 'MOVES'), '1');
    });

    testWidgets('draw three turns three', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host(drawCount: 3));
      await tester.pumpAndSettle();

      final next = expectedGame(drawCount: 3).draw()!;

      await tester.tap(find.byKey(solitaireStockKey));
      await tester.pumpAndSettle();

      // Only the top of the waste is playable, but it is the third card that
      // must be showing — not the first.
      expect(isVisible(tester, next.wasteTop!), isTrue);
    });

    testWidgets('taps are ignored while paused', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(solitaireStockKey), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
    });
  });

  group('tapping a card', () {
    testWidgets('sends an exposed ace straight to its foundation',
        (tester) async {
      // Find a deal whose tableau shows an ace, so the auto-place path is
      // exercised deterministically rather than whenever the shuffle obliges.
      final seed = List<int>.generate(200, (i) => i).firstWhere((s) {
        final game = Solitaire.deal(random: Random(s));
        return game.tableau.any((pile) => pile.last.rank == 1);
      });

      final game = Solitaire.deal(random: Random(seed));
      final pile = List<int>.generate(7, (i) => i)
          .firstWhere((i) => game.tableau[i].last.rank == 1);
      final ace = game.tableau[pile].last;

      await phoneSurface(tester);
      await tester.pumpWidget(host(seed: seed));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(solitaireCardKey(ace)));
      await tester.pumpAndSettle();

      // The ace now sits on its foundation, and the move scored ten.
      expect(
        find.descendant(
          of: find.byKey(solitaireFoundationKey(ace.suit)),
          matching: find.byKey(solitaireCardKey(ace)),
        ),
        findsOneWidget,
      );
      // Ten for the foundation, plus five more if removing the ace turned the
      // card beneath it face up. Reading the expected total off the rules keeps
      // the two scoring paths from drifting apart unnoticed.
      expect(
        statValue(tester, 'SCORE'),
        '${game.playTableauToFoundation(pile)!.score}',
      );
    });

    testWidgets('a card with nowhere to go stays put', (tester) async {
      // Whatever the deal, tapping a buried face-down card must do nothing at
      // all — no move, no score, no crash.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final game = expectedGame();
      final buried = game.tableau[6].first;

      await tester.tap(find.byKey(solitaireCardKey(buried)), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
    });
  });

  group('dragging', () {
    testWidgets('drops a run onto a pile that accepts it', (tester) async {
      // Search for a deal with a legal tableau-to-tableau move, then perform it
      // with a real drag rather than by calling the rules.
      late Solitaire game;
      late int from;
      late int to;

      final seed = List<int>.generate(300, (i) => i).firstWhere((s) {
        final candidate = Solitaire.deal(random: Random(s));
        for (var f = 0; f < 7; f++) {
          final run = candidate.runAt(f, candidate.tableau[f].length - 1);
          if (run == null) continue;
          for (var t = 0; t < 7; t++) {
            if (t == f) continue;
            if (!candidate.canDropOnTableau(run.first, t)) continue;
            game = candidate;
            from = f;
            to = t;
            return true;
          }
        }
        return false;
      });

      await phoneSurface(tester);
      await tester.pumpWidget(host(seed: seed));
      await tester.pumpAndSettle();

      final moving = game.tableau[from].last;
      final onto = game.tableau[to].last;

      final start = tester.getCenter(find.byKey(solitaireCardKey(moving)));
      final end = tester.getCenter(find.byKey(solitaireCardKey(onto)));

      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(Offset.lerp(start, end, 0.5)!);
      await tester.pump();
      await gesture.moveTo(end);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(solitaireTableauKey(to)),
          matching: find.byKey(solitaireCardKey(moving)),
        ),
        findsOneWidget,
      );
      expect(statValue(tester, 'MOVES'), '1');
    });

    testWidgets('a drop the rules refuse leaves the board alone', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final game = expectedGame();

      // Find a pair the rules will not accept, and try it anyway.
      int? from;
      int? to;
      for (var f = 0; f < 7 && from == null; f++) {
        final run = game.runAt(f, game.tableau[f].length - 1);
        if (run == null) continue;
        for (var t = 0; t < 7; t++) {
          if (t == f) continue;
          if (game.canDropOnTableau(run.first, t)) continue;
          from = f;
          to = t;
          break;
        }
      }
      expect(from, isNotNull, reason: 'every deal has an illegal pairing');

      final moving = game.tableau[from!].last;
      final start = tester.getCenter(find.byKey(solitaireCardKey(moving)));
      final end = tester.getCenter(find.byKey(solitaireTableauKey(to!)));

      await tester.dragFrom(start, end - start);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
      expect(
        find.descendant(
          of: find.byKey(solitaireTableauKey(from)),
          matching: find.byKey(solitaireCardKey(moving)),
        ),
        findsOneWidget,
      );
    });
  });

  group('lifecycle', () {
    testWidgets('restarting deals again and resets the counters', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(solitaireStockKey));
      await tester.pumpAndSettle();
      expect(statValue(tester, 'MOVES'), '1');

      await tester.tap(find.byTooltip('Restart'));
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
      expect(statValue(tester, 'SCORE'), '0');
    });
  });

  group('definition', () {
    test('id encodes the draw count', () {
      expect(const SolitaireDefinition().id, 'solitaire_draw1');
      expect(SolitaireDefinition.drawThree.id, 'solitaire_draw3');
    });
  });
}
