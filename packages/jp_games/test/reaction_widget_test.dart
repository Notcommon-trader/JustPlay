import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

Widget host({int rounds = 3}) {
  return MaterialApp(
    theme: JpTheme.light(),
    home: GameShell(
      definition: ReactionDefinition(rounds: rounds, seed: 2),
      title: 'Reaction',
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

Future<void> tapSurface(WidgetTester tester) async {
  await tester.tap(find.byKey(reactionSurfaceKey), warnIfMissed: false);
  await tester.pump();
}

/// Longer than the maximum randomised wait (1200 + 2300ms), so the target is
/// guaranteed to have appeared.
Future<void> waitForTarget(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 3600));
}

void main() {
  group('shell integration', () {
    testWidgets('shows score and moves but not the session clock',
        (tester) async {
      // The shell clock would mostly measure the randomised waiting, which the
      // player cannot influence. Reaction times are shown on the board instead.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('MOVES'), findsOneWidget);
      expect(find.text('TIME'), findsNothing);
    });

    testWidgets('starts idle showing the round number', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('Tap to start'), findsOneWidget);
      expect(find.text('Round 1 of 3'), findsOneWidget);
    });
  });

  group('a round', () {
    testWidgets('arming shows the wait state, then the target', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tapSurface(tester);
      expect(find.text('Wait…'), findsOneWidget);

      await waitForTarget(tester);
      expect(find.text('TAP'), findsOneWidget);

      await tapSurface(tester);
      await tester.pump();

      expect(statValue(tester, 'MOVES'), '1');
      // Score is awarded from the measured reaction, which in a test runs at
      // fake-clock speed — so assert that something was scored, not a value.
      expect(statValue(tester, 'SCORE'), isNot('0'));
    });

    testWidgets('tapping before the target is a false start worth nothing',
        (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tapSurface(tester); // arm
      await tester.pump(const Duration(milliseconds: 200));
      await tapSurface(tester); // far too early

      expect(find.text('Too soon'), findsOneWidget);
      expect(statValue(tester, 'SCORE'), '0');
      expect(statValue(tester, 'MOVES'), '1',
          reason: 'the round is spent even though it scored nothing');
    });

    testWidgets('tapping during feedback is ignored', (tester) async {
      // Otherwise a fast double tap skips the number the player is reading.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tapSurface(tester);
      await tester.pump(const Duration(milliseconds: 200));
      await tapSurface(tester); // false start -> feedback

      await tapSurface(tester); // should do nothing
      expect(find.text('Too soon'), findsOneWidget);
      expect(statValue(tester, 'MOVES'), '1');

      await tester.pump(const Duration(milliseconds: 1000));
    });
  });

  group('run completion', () {
    testWidgets('the run ends after the configured rounds', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host(rounds: 2));
      await tester.pumpAndSettle();

      for (var i = 0; i < 2; i++) {
        await tapSurface(tester); // arm
        await waitForTarget(tester);
        await tapSurface(tester); // hit
        await tester.pump(const Duration(milliseconds: 1000));
      }
      await tester.pumpAndSettle();

      // The shell's win overlay.
      expect(find.text('You win'), findsOneWidget);
    });
  });

  group('lifecycle', () {
    testWidgets('quitting while armed leaves no pending timer', (tester) async {
      // Both the arm timer and the feedback timer can be in flight; a leaked one
      // fires against a disposed State. testWidgets fails on a pending timer.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tapSurface(tester); // arm, timer now in flight
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
    });

    testWidgets('input is ignored while paused', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      await tapSurface(tester);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
    });
  });

  group('definition', () {
    test('id encodes the round count', () {
      expect(const ReactionDefinition().id, 'reaction_5');
      expect(const ReactionDefinition(rounds: 10).id, 'reaction_10');
    });
  });
}
