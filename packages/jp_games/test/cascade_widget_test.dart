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
      definition: CascadeDefinition(columns: 6, rows: 7, seed: kSeed),
      title: 'Cascade',
    ),
  );
}

CascadeBoard expectedBoard() =>
    CascadeBoard.deal(columns: 6, rows: 7, random: Random(kSeed));

String statValue(WidgetTester tester, String label) {
  final column = find.ancestor(of: find.text(label), matching: find.byType(Column));
  final texts = tester.widgetList<Text>(
    find.descendant(of: column.first, matching: find.byType(Text)),
  );
  return texts.last.data ?? '';
}

Future<void> phone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Advances past a whole cascade.
///
/// pumpAndSettle is not enough on its own: the chain is driven by a `Timer` per
/// link rather than by an animation, and settle returns as soon as no frame is
/// scheduled — which can happen between links, before the last one has fired.
/// Advancing the clock explicitly is what actually runs the sequence out.
Future<void> settleCascade(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pumpAndSettle();
}

/// The first legal swap on the seeded board.
({int a, int b})? firstLegalSwap(CascadeBoard board) {
  for (var a = 0; a < board.cellCount; a++) {
    for (final b in [a + 1, a + board.columns]) {
      if (!board.areAdjacent(a, b)) continue;
      if (board.swap(a, b).isLegal) return (a: a, b: b);
    }
  }
  return null;
}

void main() {
  group('shell integration', () {
    testWidgets('shows score and moves but no clock', (tester) async {
      // A cascade is a thing to watch; a running timer turns watching it into a
      // cost.
      await phone(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('MOVES'), findsOneWidget);
      expect(find.text('TIME'), findsNothing);
    });
  });

  group('swapping', () {
    testWidgets('a legal swap scores', (tester) async {
      await phone(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final swap = firstLegalSwap(expectedBoard());
      expect(swap, isNotNull, reason: 'the seeded board has no legal move');

      await tester.tap(find.byKey(cascadeTileKey(swap!.a)));
      await tester.pump();
      await tester.tap(find.byKey(cascadeTileKey(swap.b)));
      await settleCascade(tester);

      expect(statValue(tester, 'SCORE'), isNot('0'));
      expect(statValue(tester, 'MOVES'), '1');
    });

    testWidgets('a swap that matches nothing costs nothing', (tester) async {
      await phone(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final board = expectedBoard();

      // Find a pair the rules refuse.
      ({int a, int b})? illegal;
      for (var a = 0; a < board.cellCount && illegal == null; a++) {
        for (final b in [a + 1, a + board.columns]) {
          if (!board.areAdjacent(a, b)) continue;
          if (!board.swap(a, b).isLegal) {
            illegal = (a: a, b: b);
            break;
          }
        }
      }
      expect(illegal, isNotNull);

      await tester.tap(find.byKey(cascadeTileKey(illegal!.a)));
      await tester.pump();
      await tester.tap(find.byKey(cascadeTileKey(illegal.b)));
      await tester.pumpAndSettle();

      expect(statValue(tester, 'SCORE'), '0');
      expect(statValue(tester, 'MOVES'), '0',
          reason: 'a refused swap is not a move');
    });

    testWidgets('tapping a distant tile reselects rather than failing',
        (tester) async {
      // The player is choosing, not making a mistake.
      await phone(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(cascadeTileKey(0)));
      await tester.pump();
      await tester.tap(find.byKey(cascadeTileKey(20)));
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
    });
  });

  group('the cascade animation', () {
    testWidgets('plays out over time instead of jumping to the end',
        (tester) async {
      // The whole feature. If the board snapped straight to its final state, a
      // four-link chain would look exactly like one lucky match — and the
      // unplanned payout is the only reason this game exists.
      await phone(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final swap = firstLegalSwap(expectedBoard())!;

      await tester.tap(find.byKey(cascadeTileKey(swap.a)));
      await tester.pump();
      await tester.tap(find.byKey(cascadeTileKey(swap.b)));

      // One frame in, the move is under way but not finished.
      await tester.pump(const Duration(milliseconds: 50));
      final midScore = statValue(tester, 'SCORE');
      expect(statValue(tester, 'MOVES'), '0',
          reason: 'the move is only counted once the chain has finished');

      await settleCascade(tester);
      expect(statValue(tester, 'MOVES'), '1');
      expect(statValue(tester, 'SCORE'), isNot('0'));
      expect(midScore, isNotNull);
    });

    testWidgets('input is refused while a chain is playing', (tester) async {
      // A swap mid-chain would race the animation and land on a board that no
      // longer exists.
      await phone(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final swap = firstLegalSwap(expectedBoard())!;

      await tester.tap(find.byKey(cascadeTileKey(swap.a)));
      await tester.pump();
      await tester.tap(find.byKey(cascadeTileKey(swap.b)));
      await tester.pump(const Duration(milliseconds: 50));

      // Try to play again mid-cascade.
      await tester.tap(find.byKey(cascadeTileKey(0)));
      await tester.pump();
      await tester.tap(find.byKey(cascadeTileKey(1)));
      await settleCascade(tester);

      expect(statValue(tester, 'MOVES'), '1',
          reason: 'the mid-chain swap must not have registered');
    });

    testWidgets('leaving mid-cascade leaves no pending timer', (tester) async {
      // testWidgets fails on a leaked timer, which is the point of the test.
      await phone(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final swap = firstLegalSwap(expectedBoard())!;
      await tester.tap(find.byKey(cascadeTileKey(swap.a)));
      await tester.pump();
      await tester.tap(find.byKey(cascadeTileKey(swap.b)));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
    });
  });

  group('definition', () {
    test('id encodes the size', () {
      expect(const CascadeDefinition().id, 'cascade_standard');
      expect(CascadeDefinition.small.id, 'cascade_small');
    });
  });
}
