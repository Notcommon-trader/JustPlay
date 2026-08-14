import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// A board with one button that ends the game. Enough to drive the shell's
/// reporting without pulling a real game into a jp_ui test.
class _TestDefinition extends GameDefinition {
  const _TestDefinition();

  @override
  String get id => 'test_game';

  @override
  String get nameKey => 'test.name';

  @override
  String get descriptionKey => 'test.description';

  @override
  GameCapabilities get capabilities => const GameCapabilities(
        showsScore: true,
        showsMoves: true,
        showsTimer: true,
      );

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return Center(
      child: TextButton(
        key: const ValueKey('finish'),
        onPressed: () {
          session.addScore(70);
          session.recordMove();
          session.finish(GameOutcome.won);
        },
        child: const Text('Finish'),
      ),
    );
  }
}

void main() {
  late List<GameSessionState> reported;

  Widget host({int bestScore = 0}) {
    return MaterialApp(
      theme: JpTheme.light(),
      home: GameShell(
        definition: const _TestDefinition(),
        title: 'Test',
        bestScore: bestScore,
        onFinished: reported.add,
      ),
    );
  }

  setUp(() => reported = []);

  testWidgets('reports a finished session once, not once per rebuild',
      (tester) async {
    // The session notifies on every tick and every score change. Without a
    // guard, a finished game would file its result again on each one, and the
    // play count would climb while the player read the game-over sheet.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('finish')));
    await tester.pumpAndSettle();

    expect(reported, hasLength(1));
    expect(reported.single.score, 70);
    expect(reported.single.moves, 1);
    expect(reported.single.outcome, GameOutcome.won);

    // Several more frames, including a second of wall clock.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(reported, hasLength(1), reason: 'the same finish was filed twice');
  });

  testWidgets('reports nothing until the game actually ends', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(reported, isEmpty);
  });

  testWidgets('a second round is reported too', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('finish')));
    await tester.pumpAndSettle();

    // "Play again" restarts in place; the shell must re-arm rather than treating
    // the session as already reported for the rest of its life.
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('finish')));
    await tester.pumpAndSettle();

    expect(reported, hasLength(2));
  });

  testWidgets('the reported state carries the best score it started with',
      (tester) async {
    await tester.pumpWidget(host(bestScore: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('finish')));
    await tester.pumpAndSettle();

    expect(reported.single.bestScore, 500);
    expect(reported.single.isNewBest, isFalse);
  });

  testWidgets('a shell with no callback still runs', (tester) async {
    // onFinished is optional, and every existing game test omits it.
    await tester.pumpWidget(
      const MaterialApp(
        home: GameShell(definition: _TestDefinition(), title: 'Test'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('finish')));
    await tester.pumpAndSettle();

    expect(find.text('You win'), findsOneWidget);
  });
}
