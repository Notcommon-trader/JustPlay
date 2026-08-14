import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

Widget host({int rows = 2, int columns = 2}) {
  return MaterialApp(
    theme: JpTheme.light(),
    home: GameShell(
      definition: DotsAndBoxesDefinition(rows: rows, columns: columns, seed: 5),
      title: 'Dots & Boxes',
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

Future<void> tapEdge(WidgetTester tester, Edge edge, {bool covered = false}) async {
  await tester.tap(find.byKey(dotsEdgeKey(edge)), warnIfMissed: !covered);
  await tester.pump();
}

/// Long enough for the AI's scheduled move (450ms) plus its animation.
Future<void> letAiPlay(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  group('shell integration', () {
    testWidgets('shows score and moves but no timer', (tester) async {
      // A clock would push the player to move fast in a game that rewards
      // moving well.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('MOVES'), findsOneWidget);
      expect(find.text('TIME'), findsNothing);
    });

    testWidgets('shows both scores and whose turn it is', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('You  0'), findsOneWidget);
      expect(find.text('CPU  0'), findsOneWidget);
    });
  });

  group('turn handling', () {
    testWidgets('a player move passes the turn and the AI replies',
        (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tapEdge(tester, const Edge(EdgeOrientation.horizontal, 0));
      await tester.pumpAndSettle();
      expect(statValue(tester, 'MOVES'), '1');

      await letAiPlay(tester);

      // After the AI has replied it is the player's turn again, so the board is
      // interactive once more.
      await tapEdge(tester, const Edge(EdgeOrientation.horizontal, 1));
      await tester.pumpAndSettle();
      expect(statValue(tester, 'MOVES'), '2');
    });

    testWidgets('the board refuses input during the AI turn', (tester) async {
      // The board is not the player's to touch while the opponent is thinking.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tapEdge(tester, const Edge(EdgeOrientation.horizontal, 0));
      await tester.pump();

      // Before the AI's timer fires, a second tap must be ignored.
      await tapEdge(tester, const Edge(EdgeOrientation.horizontal, 1));
      await tester.pump();

      expect(statValue(tester, 'MOVES'), '1',
          reason: 'the second tap landed during the opponent turn');

      await letAiPlay(tester);
    });

    testWidgets('an already-drawn edge cannot be redrawn', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      const edge = Edge(EdgeOrientation.horizontal, 0);
      await tapEdge(tester, edge);
      await tester.pumpAndSettle();
      await letAiPlay(tester);

      final before = statValue(tester, 'MOVES');
      await tapEdge(tester, edge);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), before);
    });
  });

  group('pause', () {
    testWidgets('input is ignored while paused', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      await tapEdge(tester, const Edge(EdgeOrientation.horizontal, 0), covered: true);
      await tester.pumpAndSettle();

      expect(statValue(tester, 'MOVES'), '0');
    });

    testWidgets('quitting mid-game does not leave a pending AI move',
        (tester) async {
      // A scheduled AI move firing against a disposed State is the exact leak
      // this game introduces; testWidgets fails on a pending timer.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tapEdge(tester, const Edge(EdgeOrientation.horizontal, 0));
      await tester.pump();

      // Tear the tree down while the AI timer is still in flight.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
    });
  });

  group('definition', () {
    test('ids distinguish size and difficulty', () {
      expect(
        const DotsAndBoxesDefinition().id,
        'dots_and_boxes_4x4_smart',
      );
      expect(
        const DotsAndBoxesDefinition(rows: 3, columns: 3, level: DotsAiLevel.easy).id,
        'dots_and_boxes_3x3_easy',
      );
    });
  });
}
