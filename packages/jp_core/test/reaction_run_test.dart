import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

void main() {
  group('scoring curve', () {
    test('faster reactions are worth more', () {
      expect(ReactionRun.pointsFor(200), greaterThan(ReactionRun.pointsFor(400)));
      expect(ReactionRun.pointsFor(400), greaterThan(ReactionRun.pointsFor(800)));
    });

    test('a realistic human reaction lands in a sensible band', () {
      // Visual reaction is roughly 200-300ms, so a good player should be around
      // 700-800 a round rather than pinned at either end of the range.
      expect(ReactionRun.pointsFor(250), inInclusiveRange(700, 800));
    });

    test('never goes negative, however slow', () {
      // A negative round would make the total non-monotonic — a player could
      // score worse by playing more rounds, which is incoherent.
      expect(ReactionRun.pointsFor(5000), 0);
      expect(ReactionRun.pointsFor(1000), 0);
    });

    test('is capped at a perfect thousand', () {
      expect(ReactionRun.pointsFor(0), 1000);
      expect(ReactionRun.pointsFor(-50), 1000);
    });
  });

  group('recording rounds', () {
    test('a hit advances the round and adds its points', () {
      final run = ReactionRun.fresh(totalRounds: 3).recordHit(300);

      expect(run.completedRounds, 1);
      expect(run.score, ReactionRun.pointsFor(300));
      expect(run.isComplete, isFalse);
    });

    test('a false start spends the round and scores nothing', () {
      final run = ReactionRun.fresh(totalRounds: 3).recordFalseStart();

      expect(run.completedRounds, 1);
      expect(run.falseStarts, 1);
      expect(run.score, 0);
    });

    test('false starts are kept out of the timing statistics', () {
      // Folding a false start in as a huge time would wreck the average and
      // hide what actually happened.
      final run = ReactionRun.fresh(totalRounds: 3)
          .recordHit(250)
          .recordFalseStart()
          .recordHit(350);

      expect(run.reactionTimesMs, [250, 350]);
      expect(run.averageMs, 300);
      expect(run.bestMs, 250);
    });

    test('the source run is never mutated', () {
      final run = ReactionRun.fresh(totalRounds: 3);
      run.recordHit(200);
      expect(run.completedRounds, 0);
    });
  });

  group('completion', () {
    test('completes after the configured number of rounds', () {
      var run = ReactionRun.fresh(totalRounds: 3);
      for (var i = 0; i < 3; i++) {
        run = run.recordHit(300);
      }

      expect(run.isComplete, isTrue);
      expect(run.completedRounds, 3);
    });

    test('false starts count towards completion', () {
      var run = ReactionRun.fresh(totalRounds: 2);
      run = run.recordFalseStart().recordFalseStart();

      expect(run.isComplete, isTrue);
      expect(run.bestMs, isNull, reason: 'no successful rounds to report');
      expect(run.averageMs, isNull);
      expect(run.score, 0);
    });

    test('a late tap after the final round cannot add a phantom score',
        () {
      // The view schedules timers; one arriving after the run ended must not
      // inflate the total.
      var run = ReactionRun.fresh(totalRounds: 1).recordHit(300);
      final finalScore = run.score;

      run = run.recordHit(100);
      expect(run.score, finalScore);
      expect(run.completedRounds, 1);
    });

    test('round number stops at the total rather than running past it', () {
      var run = ReactionRun.fresh(totalRounds: 2);
      expect(run.roundNumber, 1);

      run = run.recordHit(300);
      expect(run.roundNumber, 2);

      run = run.recordHit(300);
      expect(run.roundNumber, 2, reason: 'never shows "round 3 of 2"');
    });
  });

  group('statistics', () {
    test('best and average are null before any successful round', () {
      final run = ReactionRun.fresh();
      expect(run.bestMs, isNull);
      expect(run.averageMs, isNull);
      expect(run.score, 0);
    });

    test('best tracks the fastest, not the most recent', () {
      final run = ReactionRun.fresh(totalRounds: 4)
          .recordHit(400)
          .recordHit(220)
          .recordHit(310);

      expect(run.bestMs, 220);
    });

    test('average rounds to the nearest millisecond', () {
      final run = ReactionRun.fresh(totalRounds: 3)
          .recordHit(200)
          .recordHit(201);

      expect(run.averageMs, 201, reason: '200.5 rounds to 201');
    });
  });
}
