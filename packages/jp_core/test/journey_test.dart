import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

/// A finished session, for checking a goal against.
GameSessionState finished({
  int score = 0,
  int moves = 0,
  Duration elapsed = Duration.zero,
  GameOutcome outcome = GameOutcome.won,
}) {
  return GameSessionState(
    status: GameStatus.finished,
    outcome: outcome,
    score: score,
    moves: moves,
    elapsed: elapsed,
  );
}

void main() {
  group('goals', () {
    test('a score goal is met by reaching it', () {
      const goal = ReachScore(256);
      expect(goal.isMet(finished(score: 255)), isFalse);
      expect(goal.isMet(finished(score: 256)), isTrue);
    });

    test('a timed goal needs the win as well as the time', () {
      // Running out the clock on a board you never solved is not a win in 60
      // seconds, and a goal that accepted it would be trivially farmable.
      const goal = WinWithin(Duration(seconds: 60));

      expect(goal.isMet(finished(elapsed: const Duration(seconds: 30))), isTrue);
      expect(goal.isMet(finished(elapsed: const Duration(seconds: 90))), isFalse);
      expect(
        goal.isMet(finished(
          elapsed: const Duration(seconds: 30),
          outcome: GameOutcome.lost,
        )),
        isFalse,
      );
    });

    test('a move-limited goal needs the win too', () {
      const goal = WinInMoves(20);
      expect(goal.isMet(finished(moves: 20)), isTrue);
      expect(goal.isMet(finished(moves: 21)), isFalse);
      expect(
        goal.isMet(finished(moves: 5, outcome: GameOutcome.lost)),
        isFalse,
        reason: 'losing in five moves is not winning in twenty',
      );
    });

    test('a progress goal does not require finishing, but does require surviving',
        () {
      // This is what lets solitaire and minesweeper appear at all: a full game
      // of either outruns a stage, but "six cards home" is a real objective
      // inside one.
      const goal = MakeProgress(moves: 6, label: 'cards home');

      expect(goal.isMet(finished(moves: 6, outcome: GameOutcome.none)), isTrue);
      expect(goal.isMet(finished(moves: 5, outcome: GameOutcome.none)), isFalse);
      expect(
        goal.isMet(finished(moves: 9, outcome: GameOutcome.lost)),
        isFalse,
        reason: 'hitting a mine on move nine is not nine squares opened',
      );
    });

    test('every goal describes itself as an instruction', () {
      for (final stage in Journey.ladder(60)) {
        expect(stage.goal.describe, isNotEmpty);
        expect(stage.goal.describe.length, lessThan(30),
            reason: 'a goal has to fit a banner: ${stage.goal.describe}');
      }
    });
  });

  group('stars', () {
    test('a missed goal scores nothing', () {
      final stage = Journey.stageAt(1);
      expect(stage.starsFor(finished(outcome: GameOutcome.lost)), 0);
    });

    test('three stars need the stretch', () {
      // Stage 1 is 2048: score 64 to pass, 128 for the stretch.
      final stage = Journey.ladder(40).firstWhere(
        (s) => s.game == StageGame.game2048 && s.stretch != null,
      );

      final base = (stage.goal as ReachScore).target;
      final stretch = (stage.stretch! as ReachScore).target;

      expect(stage.starsFor(finished(score: base)), 2);
      expect(stage.starsFor(finished(score: stretch)), 3);
    });

    test('a stretch is always harder than the goal it stretches', () {
      // A stretch easier than the base would hand out three stars for passing,
      // which quietly removes the reason to replay anything.
      for (final stage in Journey.ladder(120)) {
        final stretch = stage.stretch;
        if (stretch == null) continue;

        if (stage.goal case ReachScore(target: final base)) {
          expect((stretch as ReachScore).target, greaterThan(base),
              reason: 'stage ${stage.number}');
        }
        if (stage.goal case WinInMoves(maxMoves: final base)) {
          expect((stretch as WinInMoves).maxMoves, lessThan(base),
              reason: 'stage ${stage.number}');
        }
        if (stage.goal case WinWithin(limit: final base)) {
          expect((stretch as WinWithin).limit, lessThan(base),
              reason: 'stage ${stage.number}');
        }
      }
    });
  });

  group('the ladder', () {
    test('is the same for everyone, every time', () {
      // Deterministic by design: a complaint about stage 41 has to be
      // reproducible, and a shared ladder is comparable between players.
      final first = Journey.ladder(50).map((s) => s.toString()).toList();
      final second = Journey.ladder(50).map((s) => s.toString()).toList();
      expect(first, second);
    });

    test('never runs the same game three stages in a row', () {
      // Rotation is the thing that defeats mechanic fatigue over a long sitting.
      final ladder = Journey.ladder(400);

      for (var i = 2; i < ladder.length; i++) {
        final three = {ladder[i - 2].game, ladder[i - 1].game, ladder[i].game};
        expect(three.length, greaterThan(1),
            reason: 'stages ${i - 1}-${i + 1} are all the same game');
      }
    });

    test('opens with a small pool and widens', () {
      // Meeting every mechanic in the first ten minutes is how a player learns
      // none of them — but the pool cannot be so small that the no-repeat rule
      // leaves one legal choice and the "random" opening becomes a fixed cycle.
      //
      // Cascade is in the opening deliberately: it is the only game with chain
      // reactions, and holding it back would make the first stages entirely
      // deliberate puzzles.
      expect(Journey.availableAt(1).length, 5);
      expect(Journey.availableAt(40).length, greaterThan(5));
      expect(Journey.availableAt(100).length, StageGame.values.length);
    });

    test('the opening never settles into a fixed cycle', () {
      // The failure this guards against was visible only by printing the ladder:
      // wordSearch, 2048, memory, wordSearch, 2048, memory, in lockstep.
      final opening = Journey.ladder(12).map((s) => s.game).toList();

      var repeats = 0;
      for (var i = 3; i < opening.length; i++) {
        if (opening[i] == opening[i - 3]) repeats++;
      }

      expect(repeats, lessThan(opening.length - 3),
          reason: 'every stage matches the one three back — that is a cycle');
    });

    test('early stages only use games that are unlocked', () {
      for (final stage in Journey.ladder(80)) {
        expect(
          Journey.availableAt(stage.number),
          contains(stage.game),
          reason: 'stage ${stage.number} uses a game not yet introduced',
        );
      }
    });

    test('a stage that unlocks a game is that game', () {
      // Announcing "new: nonogram" and then dealing a word search wastes the one
      // moment in ten stages meant to feel like an arrival.
      for (var i = 1; i <= 100; i++) {
        final unlocked = Journey.unlockedAt(i);
        if (unlocked == null) continue;
        expect(Journey.stageAt(i).game, unlocked,
            reason: 'stage $i announces $unlocked but plays something else');
      }
    });

    test('goal targets are round numbers', () {
      // "Finish in 123 moves" reads as a number that fell out of a formula. A
      // target is read at a glance and remembered between attempts.
      for (final stage in Journey.ladder(200)) {
        if (stage.goal case WinInMoves(maxMoves: final m)) {
          expect(m % 5 == 0 || m % 2 == 0, isTrue,
              reason: 'stage ${stage.number}: $m moves');
        }
        if (stage.goal case WinWithin(limit: final d)) {
          expect(d.inSeconds % 5, 0, reason: 'stage ${stage.number}');
        }
      }
    });

    test('announces each new game exactly once', () {
      final unlocks = <StageGame>[];
      for (var i = 1; i <= 100; i++) {
        final game = Journey.unlockedAt(i);
        if (game != null) unlocks.add(game);
      }

      expect(unlocks.length, unlocks.toSet().length, reason: 'a game unlocked twice');
      expect(unlocks.length, StageGame.values.length - Journey.availableAt(1).length,
          reason: 'every game not in the opening pool should unlock exactly once');
    });

    test('difficulty rises but plateaus rather than climbing forever', () {
      // A curve that climbs every stage becomes unbeatable; one that never
      // climbs is dull. Steps with flat stretches let competence settle.
      final ladder = Journey.ladder(200);

      expect(ladder.first.difficulty, 0);
      expect(ladder[50].difficulty, greaterThan(ladder[5].difficulty));

      for (var i = 1; i < ladder.length; i++) {
        expect(ladder[i].difficulty,
            greaterThanOrEqualTo(ladder[i - 1].difficulty),
            reason: 'difficulty went backwards at stage ${i + 1}');
      }
      expect(ladder.last.difficulty, lessThanOrEqualTo(6));
    });

    test('never runs out', () {
      // No ending, because "congratulations, you finished" is permission to stop.
      expect(Journey.stageAt(5000).goal.describe, isNotEmpty);
    });

    test('marks a chapter every ten stages', () {
      expect(Journey.stageAt(1).chapter, 1);
      expect(Journey.stageAt(1).isChapterStart, isTrue);
      expect(Journey.stageAt(10).chapter, 1);
      expect(Journey.stageAt(11).chapter, 2);
      expect(Journey.stageAt(11).isChapterStart, isTrue);
    });

    test('stays inside the one-to-three minute band', () {
      // A stage that outlasts the player's patience breaks the only thing the
      // ladder depends on: that the next one is always cheap to start.
      for (final stage in Journey.ladder(200)) {
        expect(stage.game.typicalLength.inSeconds, lessThanOrEqualTo(180),
            reason: 'stage ${stage.number}');
      }
    });

    test('does not include sudoku', () {
      // Deliberate: an easy grid runs past five minutes. It stays in the main
      // catalogue for players who want a long sit.
      expect(StageGame.values.map((g) => g.name), isNot(contains('sudoku')));
    });
  });

  group('the first ten stages', () {
    test('are gentle enough to be passed', () {
      // The opening decides whether anyone reaches stage eleven.
      for (final stage in Journey.ladder(10)) {
        expect(stage.difficulty, lessThanOrEqualTo(1),
            reason: 'stage ${stage.number} is steep for an opening');

        if (stage.goal case WinWithin(limit: final limit)) {
          expect(limit.inSeconds, greaterThanOrEqualTo(120));
        }
      }
    });
  });
}
