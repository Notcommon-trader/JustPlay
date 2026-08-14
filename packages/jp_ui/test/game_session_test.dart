import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

void main() {
  group('GameSession lifecycle', () {
    test('starts ready and moves to playing', () {
      final session = GameSession();
      expect(session.state.status, GameStatus.ready);

      session.start();
      expect(session.state.isPlaying, isTrue);

      session.dispose();
    });

    test('pause and resume toggle status without losing score', () {
      final session = GameSession()
        ..start()
        ..addScore(120);

      session.pause();
      expect(session.state.isPaused, isTrue);
      expect(session.state.score, 120);

      session.resume();
      expect(session.state.isPlaying, isTrue);
      expect(session.state.score, 120);

      session.dispose();
    });

    test('pausing an already-paused session is a no-op', () {
      final session = GameSession()..start();

      var notifications = 0;
      session.addListener(() => notifications++);

      session.pause();
      session.pause();
      expect(notifications, 1, reason: 'The second pause must not notify listeners.');

      session.dispose();
    });

    test('restart clears score and moves but keeps the best score', () {
      final session = GameSession(bestScore: 500)
        ..start()
        ..addScore(120)
        ..recordMove();

      session.restart();

      expect(session.state.score, 0);
      expect(session.state.moves, 0);
      expect(session.state.bestScore, 500, reason: 'The target to beat must survive a restart.');
      expect(session.state.status, GameStatus.ready);

      session.dispose();
    });

    test('finish is idempotent', () {
      // A game that detects "no moves left" in more than one place must not be
      // able to fire two game-over sheets.
      final session = GameSession()..start();

      var notifications = 0;
      session.addListener(() => notifications++);

      session.finish(GameOutcome.lost);
      session.finish(GameOutcome.won);

      expect(notifications, 1);
      expect(session.state.outcome, GameOutcome.lost, reason: 'The first outcome wins.');

      session.dispose();
    });
  });

  group('scoring', () {
    test('accumulates score and moves', () {
      final session = GameSession()
        ..start()
        ..addScore(10)
        ..addScore(15)
        ..recordMove()
        ..recordMove();

      expect(session.state.score, 25);
      expect(session.state.moves, 2);

      session.dispose();
    });

    test('adding zero points does not notify', () {
      final session = GameSession()..start();

      var notifications = 0;
      session.addListener(() => notifications++);
      session.addScore(0);

      expect(notifications, 0, reason: 'A no-op move must not rebuild the UI.');

      session.dispose();
    });

    test('isNewBest is only true after finishing above the previous best', () {
      final session = GameSession(bestScore: 100)..start();

      session.addScore(150);
      expect(session.state.isNewBest, isFalse, reason: 'Mid-game it would flicker.');

      session.finish(GameOutcome.won);
      expect(session.state.isNewBest, isTrue);

      session.dispose();
    });

    test('isNewBest is false when the previous best stands', () {
      final session = GameSession(bestScore: 100)
        ..start()
        ..addScore(80);
      session.finish(GameOutcome.lost);

      expect(session.state.isNewBest, isFalse);

      session.dispose();
    });
  });

  group('timing', () {
    // These dispose inside the test body rather than via addTearDown.
    // testWidgets asserts that no timers are pending *before* tear-downs run, so
    // a session left ticking fails the test even though it is cleaned up a
    // moment later. Disposing in-body is also what production code does when a
    // game screen is popped.

    testWidgets('the elapsed clock advances while playing', (tester) async {
      final session = GameSession()..start();

      await tester.pump(const Duration(seconds: 3));
      expect(session.state.elapsed.inSeconds, 3);

      session.dispose();
    });

    testWidgets('the clock stops while paused', (tester) async {
      final session = GameSession()..start();

      await tester.pump(const Duration(seconds: 2));
      session.pause();
      await tester.pump(const Duration(seconds: 5));

      expect(session.state.elapsed.inSeconds, 2, reason: 'Paused time must not count.');

      session.dispose();
    });

    testWidgets('the clock stops when the session finishes', (tester) async {
      final session = GameSession()..start();

      await tester.pump(const Duration(seconds: 2));
      session.finish(GameOutcome.lost);
      await tester.pump(const Duration(seconds: 5));

      expect(session.state.elapsed.inSeconds, 2);

      session.dispose();
    });

    testWidgets('an untimed game never starts a clock', (tester) async {
      final session = GameSession(tracksTime: false)..start();

      await tester.pump(const Duration(seconds: 5));
      expect(session.state.elapsed, Duration.zero);

      session.dispose();
    });

    testWidgets('disposing a running session cancels its timer', (tester) async {
      // Regression guard: a leaked periodic timer keeps firing against a dead
      // notifier, which only surfaces after navigating between games a few
      // times. testWidgets fails the test if any timer is still pending here.
      final session = GameSession()..start();
      await tester.pump(const Duration(seconds: 1));
      session.dispose();
    });
  });

  group('restore', () {
    test('a restored session comes back paused, not running', () {
      // Dropping a returning player into a live timer costs them the seconds it
      // takes to re-read the board.
      final session = GameSession();
      session.restoreFrom(const GameSessionState(
        status: GameStatus.playing,
        score: 340,
        moves: 12,
        elapsed: Duration(seconds: 75),
      ));

      expect(session.state.isPaused, isTrue);
      expect(session.state.score, 340);
      expect(session.state.moves, 12);
      expect(session.state.elapsed.inSeconds, 75);

      session.dispose();
    });

    test('a restored finished session stays finished', () {
      final session = GameSession();
      session.restoreFrom(const GameSessionState(
        status: GameStatus.finished,
        outcome: GameOutcome.won,
        score: 999,
      ));

      expect(session.state.isFinished, isTrue);
      expect(session.state.outcome, GameOutcome.won);

      session.dispose();
    });
  });
}
