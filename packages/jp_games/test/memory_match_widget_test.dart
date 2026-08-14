import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

const int kSeed = 11;

Widget host({int pairs = 8, int columns = 4}) {
  return MaterialApp(
    theme: JpTheme.light(),
    home: GameShell(
      definition: MemoryMatchDefinition(pairs: pairs, columns: columns, seed: kSeed),
      title: 'Memory',
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

/// The board the view will have dealt, so tests can reason about which cards
/// pair rather than tapping blindly.
MemoryBoard dealtBoard({int pairs = 8, int columns = 4}) =>
    MemoryBoard.deal(pairs: pairs, columns: columns, random: Random(kSeed));

/// Indices of a genuine pair, and of two cards that do not match.
({int a, int b}) matchingPair(MemoryBoard board) {
  const a = 0;
  final b = List.generate(board.cardCount, (i) => i)
      .firstWhere((i) => i != a && board.symbols[i] == board.symbols[a]);
  return (a: a, b: b);
}

({int a, int b}) mismatchedPair(MemoryBoard board) {
  const a = 0;
  final b = List.generate(board.cardCount, (i) => i)
      .firstWhere((i) => board.symbols[i] != board.symbols[a]);
  return (a: a, b: b);
}

/// Taps a card by board index.
///
/// Addressed by key rather than by indexing into GestureDetectors: there are 19
/// of those on this screen and only 16 are cards, so an index-based tap silently
/// hits an app-bar button instead.
Future<void> tapCard(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(memoryCardKey(index)));
  await tester.pump();
}

/// Sizes the surface to a phone. The default 800x600 test surface clips the
/// grid, so the last row is never built and card counts come up short.
Future<void> phoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(GoldenSize.phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Advances past the mismatch flip-back delay.
///
/// Uses `pump(duration)` rather than `pumpAndSettle(duration)`. The argument to
/// pumpAndSettle is the *interval between pumps*, not a total wait — and since
/// this game runs a one-second session clock, pumping in one-second steps fires
/// that timer on every step, schedules another frame, and never settles. That
/// spelling hangs the test until it times out.
Future<void> advancePastFlipBack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  group('shell integration', () {
    testWidgets('shows score, moves and timer', (tester) async {
      // The first game to use all three readouts.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('MOVES'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
    });

    testWidgets('deals the right number of cards, all face down', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // Face-down cards show the question-mark back.
      expect(find.byIcon(Icons.question_mark), findsNWidgets(16));
    });
  });

  group('turns', () {
    testWidgets('the first card of a turn does not advance the counters',
        (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final pair = matchingPair(dealtBoard());
      await tapCard(tester, pair.a);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0', reason: 'a turn is two cards');
      expect(statValue(tester, 'SCORE'), '0');
    });

    testWidgets('a matching pair scores and counts a move', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final pair = matchingPair(dealtBoard());
      await tapCard(tester, pair.a);
      await tapCard(tester, pair.b);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '1');
      expect(statValue(tester, 'SCORE'), '100');
    });

    testWidgets('a mismatch counts a move but scores nothing', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final pair = mismatchedPair(dealtBoard());
      await tapCard(tester, pair.a);
      await tapCard(tester, pair.b);
      await tester.pump();

      expect(statValue(tester, 'MOVES'), '1');
      expect(statValue(tester, 'SCORE'), '0');

      // Let the flip-back timer run so the test does not end with it pending.
      await advancePastFlipBack(tester);
    });

    testWidgets('a mismatched pair flips back on its own', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final pair = mismatchedPair(dealtBoard());
      await tapCard(tester, pair.a);
      await tapCard(tester, pair.b);
      await tester.pumpAndSettle();

      // Two cards revealed, so 14 backs remain of 16.
      expect(find.byIcon(Icons.question_mark), findsNWidgets(14));

      await advancePastFlipBack(tester);
      expect(find.byIcon(Icons.question_mark), findsNWidgets(16),
          reason: 'both cards should have flipped back');
    });

    testWidgets('a third card is ignored during the mismatch window',
        (tester) async {
      // The defining bug of memory match. The rules lock it, and this proves the
      // view honours that lock rather than tracking its own flag.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final board = dealtBoard();
      final pair = mismatchedPair(board);
      final third = List.generate(board.cardCount, (i) => i)
          .firstWhere((i) => i != pair.a && i != pair.b);

      await tapCard(tester, pair.a);
      await tapCard(tester, pair.b);

      // pumpAndSettle, not pump: a revealed card is mid-flip for 240ms and is
      // still showing its back until the animation passes halfway. Settling here
      // finishes the flip while staying well inside the 800ms mismatch window.
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.question_mark), findsNWidgets(14));

      await tapCard(tester, third);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.question_mark), findsNWidgets(14),
          reason: 'the third card must stay face down');
      expect(statValue(tester, 'MOVES'), '1', reason: 'the ignored tap is not a move');

      await advancePastFlipBack(tester);
    });

    testWidgets('input is ignored while paused', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      final pair = matchingPair(dealtBoard());
      await tapCard(tester, pair.a);
      await tapCard(tester, pair.b);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
      expect(find.byIcon(Icons.question_mark), findsNWidgets(16));
    });
  });

  group('definition', () {
    test('ids are distinct per pair count', () {
      expect(const MemoryMatchDefinition().id, 'memory_match_8');
      expect(const MemoryMatchDefinition(pairs: 6).id, 'memory_match_6');
    });

    test('declares score, moves and timer', () {
      final capabilities = const MemoryMatchDefinition().capabilities;
      expect(capabilities.showsScore, isTrue);
      expect(capabilities.showsMoves, isTrue);
      expect(capabilities.showsTimer, isTrue);
    });
  });
}


