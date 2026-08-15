import 'dart:math';

import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

/// Automated play across every game.
///
/// These are not example-based tests. Each one deals a game, plays random legal
/// moves to the end, and re-checks the game's invariants after **every single
/// move** — so a single run covers far more positions than the rest of the suite
/// put together.
///
/// Counts are sized to keep the whole file under a few seconds. Turn them up
/// when hunting something: `soak(agent, games: 5000)` is the same code.
///
/// A failure prints the seed and the move number and is exactly reproducible —
/// a soak failure you cannot replay is a rumour, not a bug report.
void main() {
  group('every game survives extended random play', () {
    for (final agent in allAgents()) {
      test(agent.name, () {
        final report = soak(agent, games: 60);

        // The report is printed on purpose. "Passed" and "played sixty games
        // that each ended after one move" look identical otherwise, and the
        // second is the more interesting result.
        printOnFailure(report.toString());

        expect(report.gamesPlayed, 60);
        expect(
          report.movesPlayed,
          greaterThan(report.gamesPlayed),
          reason: 'games that end in zero or one move are not being played',
        );
      });
    }
  });

  group('the agents actually finish games', () {
    // A soak run that never reaches a terminal state proves only that nothing
    // crashed on the way to nowhere. These assert the games are winnable — or at
    // least completable — under random play.
    test('2048 always reaches game over', () {
      final report = soak(Game2048Agent(), games: 40);
      expect(report.finished, 40);
    });

    test('memory match always completes', () {
      // Every pair is eventually turned over, so a run that does not complete
      // means cards are becoming unreachable.
      final report = soak(MemoryMatchAgent(), games: 30, maxMoves: 20000);
      expect(report.finished, 30);
    });

    test('dots and boxes always fills the board', () {
      final report = soak(DotsAndBoxesAgent(), games: 40);
      expect(report.finished, 40);
    });

    test('word search always completes', () {
      final report = soak(WordSearchAgent(), games: 40);
      expect(report.finished, 40);
    });

    test('sudoku always reaches a solved grid', () {
      // The agent mostly plays correct digits, so every game should finish. If
      // this fails, either a hint is wrong or a correct grid is not recognised
      // as solved.
      final report = soak(SudokuAgent(), games: 20, maxMoves: 2000);
      expect(report.finished, 20);
    });

    test('minesweeper always ends, won or lost', () {
      final report = soak(MinesweeperAgent(), games: 60);
      expect(report.finished, 60);
    });

    test('nonogram always reaches a solved picture', () {
      // The agent plays the puzzle's own line solver, so a game that does not
      // finish means the generator shipped a board its solver cannot finish.
      final report = soak(NonogramAgent(), games: 40);
      expect(report.finished, 40);
    });

    test('solitaire wins a reasonable share of deals', () {
      // Not all of them — Klondike is not always winnable, and this agent plays
      // by simple priorities rather than searching. But a version that wins
      // *none* means the win path is untested, which is exactly what the first
      // draft did: it ping-ponged cards between foundation and tableau until it
      // hit the move ceiling, every single game.
      final report = soak(SolitaireAgent(), games: 60);
      expect(report.finished, greaterThan(10));
    });
  });

  group('games random play does not finish', () {
    test('the sliding puzzle truncates rather than solving itself', () {
      // Honest expectation, not a gap being papered over. Random moves solve a
      // 15-puzzle at a rate indistinguishable from never, so the value here is
      // the invariant checked after each of those moves — every state stays a
      // permutation of the tiles, and stays solvable.
      final report = soak(SlidingPuzzleAgent(), games: 10, maxMoves: 500);

      expect(report.truncated, 10);
      expect(report.movesPlayed, 5000, reason: 'it should keep moving happily');
    });
  });

  group('the harness itself', () {
    test('reports a broken invariant with a reproducible seed', () {
      // A deliberately broken agent, to prove the runner actually fails rather
      // than quietly passing. A test harness that cannot detect a planted bug is
      // worth nothing, and the only way to know is to plant one.
      expect(
        () => soak(_AlwaysBrokenAgent(), games: 1),
        throwsA(
          isA<SoakFailure>()
              .having((f) => f.seed, 'seed', 0)
              .having((f) => f.reason, 'reason', contains('deliberately broken')),
        ),
      );
    });

    test('reports a softlock when a game stalls without finishing', () {
      expect(
        () => soak(_StalledAgent(), games: 1),
        throwsA(
          isA<SoakFailure>().having(
            (f) => f.reason,
            'reason',
            contains('no legal move remains'),
          ),
        ),
      );
    });
  });
}

class _AlwaysBrokenAgent extends PlayableGame<int> {
  @override
  String get name => 'broken';

  @override
  int deal(Random random) => 0;

  @override
  int? step(int state, Random random) => state + 1;

  @override
  bool isFinished(int state) => false;

  @override
  void verify(int state) => invalid('deliberately broken');
}

class _StalledAgent extends PlayableGame<int> {
  @override
  String get name => 'stalled';

  @override
  int deal(Random random) => 0;

  @override
  int? step(int state, Random random) => null;

  @override
  bool isFinished(int state) => false;

  @override
  void verify(int state) {}
}
