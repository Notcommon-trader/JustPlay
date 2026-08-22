import 'dart:math';

import '../session/game_session_state.dart';

/// A game the Journey can draw a stage from.
///
/// Named here rather than referencing `GameDefinition`, which lives above this
/// package: `jp_core` stays pure Dart, so the whole pacing model is testable
/// without a widget tree. The app maps these onto real definitions.
enum StageGame {
  cascade,
  game2048,
  slidingPuzzle,
  memoryMatch,
  minesweeper,
  dotsAndBoxes,
  reaction,
  wordSearch,
  nonogram,
  solitaire;

  /// Roughly how long one stage of this game runs, used to keep the ladder
  /// inside the one-to-three minute band.
  Duration get typicalLength => switch (this) {
        StageGame.cascade => const Duration(seconds: 90),
        StageGame.reaction => const Duration(seconds: 45),
        StageGame.game2048 => const Duration(seconds: 90),
        StageGame.slidingPuzzle => const Duration(seconds: 90),
        StageGame.memoryMatch => const Duration(seconds: 75),
        StageGame.wordSearch => const Duration(seconds: 75),
        StageGame.minesweeper => const Duration(seconds: 90),
        StageGame.dotsAndBoxes => const Duration(minutes: 2),
        StageGame.nonogram => const Duration(minutes: 2),
        StageGame.solitaire => const Duration(minutes: 3),
      };
}

/// Sudoku is deliberately absent from [StageGame].
///
/// Even an easy grid runs past five minutes, and a stage that outlasts the
/// player's patience breaks the one thing the ladder depends on — that the next
/// stage is always cheap to start. Sudoku stays in the main catalogue, where a
/// player who wants a long sit can choose one.
const String sudokuExclusionReason =
    'A sudoku grid runs longer than a stage should.';

/// What a stage asks for, beyond simply playing.
///
/// A goal is what makes the same board a different task twice — "reach 256" and
/// "reach 256 in 40 moves" are the same game and different problems. This is the
/// only real source of variety in a ladder built from nine mechanics, and its
/// absence is why the catalogue felt flat.
sealed class StageGoal {
  const StageGoal();

  /// One line, shown as the stage's objective. Written as an instruction, not a
  /// description — "Reach 256", not "The goal is 256 points".
  String get describe;

  /// Whether a finished session satisfied this goal.
  bool isMet(GameSessionState state);

  /// Where the player currently stands, as "340 / 600".
  ///
  /// A target with no running total is barely a goal: the header announced
  /// "Score 600" and then never mentioned it again, so a player had no idea
  /// whether they were nearly there or nowhere near. Knowing you are close is
  /// most of the reason to keep going.
  String progress(GameSessionState state);

  /// 0–1, for a progress bar. Clamped, because overshooting a target should
  /// fill the bar rather than overflow it.
  double fraction(GameSessionState state);
}

/// Reach a score.
class ReachScore extends StageGoal {
  const ReachScore(this.target);

  final int target;

  @override
  String get describe => 'Score $target';

  @override
  bool isMet(GameSessionState state) => state.score >= target;

  @override
  String progress(GameSessionState state) => '${state.score} / $target';

  @override
  double fraction(GameSessionState state) =>
      (state.score / target).clamp(0.0, 1.0);
}

/// Win, however long it takes.
class JustWin extends StageGoal {
  const JustWin();

  @override
  String get describe => 'Finish the board';

  @override
  bool isMet(GameSessionState state) => state.outcome == GameOutcome.won;

  // Nothing meaningful to count: a board is finished or it is not.
  @override
  String progress(GameSessionState state) => isMet(state) ? 'done' : '';

  @override
  double fraction(GameSessionState state) => isMet(state) ? 1 : 0;
}

/// Win inside a time limit.
class WinWithin extends StageGoal {
  const WinWithin(this.limit);

  final Duration limit;

  @override
  String get describe => 'Finish in ${limit.inSeconds}s';

  @override
  bool isMet(GameSessionState state) =>
      state.outcome == GameOutcome.won && state.elapsed <= limit;

  // Counts down, because the pressure is the time left rather than the time
  // spent.
  @override
  String progress(GameSessionState state) {
    final left = limit - state.elapsed;
    return left.isNegative ? 'out of time' : '${left.inSeconds}s left';
  }

  @override
  double fraction(GameSessionState state) =>
      (state.elapsed.inMilliseconds / limit.inMilliseconds).clamp(0.0, 1.0);
}

/// Win without spending more than [maxMoves].
class WinInMoves extends StageGoal {
  const WinInMoves(this.maxMoves);

  final int maxMoves;

  @override
  String get describe => 'Finish in $maxMoves moves';

  @override
  bool isMet(GameSessionState state) =>
      state.outcome == GameOutcome.won && state.moves <= maxMoves;

  @override
  String progress(GameSessionState state) =>
      '${state.moves} / $maxMoves moves';

  @override
  double fraction(GameSessionState state) =>
      (state.moves / maxMoves).clamp(0.0, 1.0);
}

/// Make progress without necessarily finishing.
///
/// The reason solitaire and minesweeper can appear at all: a full game of either
/// is far too long for a stage, but "send six cards home" is a real objective
/// inside one, and it ends the moment it is met.
class MakeProgress extends StageGoal {
  const MakeProgress({required this.moves, required this.label});

  final int moves;

  /// What the moves are, in the player's words — "cards home", "squares".
  final String label;

  @override
  String get describe => '$moves $label';

  @override
  bool isMet(GameSessionState state) =>
      state.moves >= moves && state.outcome != GameOutcome.lost;

  @override
  String progress(GameSessionState state) => '${state.moves} / $moves';

  @override
  double fraction(GameSessionState state) =>
      (state.moves / moves).clamp(0.0, 1.0);
}

/// One rung of the ladder.
class Stage {
  const Stage({
    required this.number,
    required this.game,
    required this.goal,
    required this.difficulty,
    this.stretch,
  });

  /// 1-based, and shown to the player. The ladder never restarts, so this is
  /// also the honest measure of how far someone has come.
  final int number;

  final StageGame game;
  final StageGoal goal;

  /// 0 upward. The app maps this onto board size, mine count, word count — each
  /// game decides what its own difficulty means.
  final int difficulty;

  /// The stretch goal, worth the third star. Optional: not every stage has a
  /// meaningful one, and inventing one that is impossible is worse than none.
  final StageGoal? stretch;

  /// 1 for beating it, 2 for beating it well, 3 for the stretch.
  ///
  /// Zero when the goal was not met — a stage is not passed, and the difference
  /// between "failed" and "passed badly" has to be visible.
  int starsFor(GameSessionState state) {
    if (!goal.isMet(state)) return 0;
    if (stretch != null && stretch!.isMet(state)) return 3;
    return state.outcome == GameOutcome.won ? 2 : 1;
  }

  /// Every tenth stage opens a chapter, so hours of play have visible markers.
  /// Three hours of identical stages feels like one hour repeated.
  int get chapter => (number - 1) ~/ 10 + 1;

  bool get isChapterStart => number % 10 == 1;

  @override
  String toString() => 'Stage $number: ${game.name} — ${goal.describe}';
}

/// Builds the ladder.
///
/// Deterministic: stage 41 is the same stage for everyone, forever, because it
/// is a pure function of its number. That makes the ladder shareable and
/// comparable, and makes a complaint about stage 41 reproducible.
abstract final class Journey {
  /// Games available at [stageNumber].
  ///
  /// The rotation opens gradually. Meeting nine mechanics in the first ten
  /// minutes is how a player ends up learning none of them; a new game arriving
  /// at stage 11, 21, 31 is also one of the few things that marks progress
  /// without a reward screen.
  static List<StageGame> availableAt(int stageNumber) {
    // Four to open, not three.
    //
    // With a pool of three and a rule against repeating within three, exactly
    // one game is ever legal — so the opening ran wordSearch, 2048, memory,
    // wordSearch, 2048, memory in perfect lockstep. A rotation that predictable
    // is the opposite of variety, and only reading the printed ladder showed it.
    // All four here explain themselves in one glance, which is what an opening
    // pool has to do.
    // Cascade opens, and is the first thing a new player meets.
    //
    // It is the only game here with chain reactions — a payout you did not plan
    // — and that surprise is what the rest of the catalogue structurally cannot
    // provide. Holding it back behind an unlock would mean the opening stages
    // are all deliberate puzzles, which is precisely the run that got described
    // as boring.
    const opening = [
      StageGame.cascade,
      StageGame.game2048,
      StageGame.wordSearch,
      StageGame.memoryMatch,
      StageGame.slidingPuzzle,
    ];
    const unlocks = [
      (11, StageGame.nonogram),
      (21, StageGame.minesweeper),
      (31, StageGame.reaction),
      (41, StageGame.dotsAndBoxes),
      (51, StageGame.solitaire),
    ];

    return [
      ...opening,
      for (final (at, game) in unlocks)
        if (stageNumber >= at) game,
    ];
  }

  /// The game newly available at [stageNumber], if any. Drives the "new game
  /// unlocked" moment.
  static StageGame? unlockedAt(int stageNumber) {
    if (stageNumber <= 1) return null;
    final before = availableAt(stageNumber - 1);
    final now = availableAt(stageNumber);
    if (now.length == before.length) return null;
    return now.last;
  }

  /// The stage at [number].
  static Stage stageAt(int number) {
    assert(number >= 1, 'stages are 1-based');

    // Seeded from the stage number, so the ladder is identical for every player
    // and every run.
    final rng = Random(0x5747 ^ number);
    final game = _gameFor(number);
    final difficulty = _difficultyAt(number);

    final goal = _goalFor(game, difficulty, rng);

    return Stage(
      number: number,
      game: game,
      goal: goal,
      difficulty: difficulty,
      stretch: _stretchFor(goal),
    );
  }

  /// The first [count] stages, for inspecting the pacing as a list.
  static List<Stage> ladder(int count) =>
      [for (var i = 1; i <= count; i++) stageAt(i)];

  /// The sequence of games, built once and extended as the ladder is walked.
  ///
  /// Choosing a stage's game needs to know the previous two, and doing that by
  /// recursion costs O(n) per stage and risks the stack at high stage numbers.
  /// Growing a list instead makes the whole ladder linear, and the result is
  /// still a pure function of the stage number — the cache only avoids
  /// recomputing it.
  static final List<StageGame> _games = [];

  static StageGame _gameFor(int number) {
    // Stage 1 is always Cascade, not whatever the shuffle produces.
    //
    // The first stage is the only one every player is guaranteed to see, and it
    // decides whether there is a second. Cascade is the one game here that pays
    // out in chains the player did not plan; opening on a deliberate puzzle
    // instead spends that moment on the exact impression this whole redesign was
    // trying to escape.
    if (number == 1) return StageGame.cascade;

    while (_games.length < number) {
      final n = _games.length + 1;
      final rng = Random(0x5747 ^ n);
      final pool = availableAt(n);

      // A stage that unlocks a game *is* that game.
      //
      // Announcing "new: nonogram" and then dealing a word search wastes the one
      // moment in ten stages that is supposed to feel like an arrival — and the
      // new game then turned up seven stages later attached to nothing. The
      // announcement and the thing announced have to be the same stage.
      final unlocked = unlockedAt(n);
      if (unlocked != null) {
        _games.add(unlocked);
        continue;
      }

      // Never the same game three stages running. Rotation is what stops one
      // mechanic wearing out over a long sitting, and it is the whole reason
      // nine games is an asset here rather than a scattered menu.
      if (n == 1) {
        _games.add(StageGame.cascade);
        continue;
      }

      final recent = <StageGame>{
        if (_games.isNotEmpty) _games[_games.length - 1],
        if (_games.length > 1) _games[_games.length - 2],
      };

      // Forbidding the last two is only worth doing while it still leaves a real
      // choice. Where it does not, forbid just the previous game — a rule that
      // narrows the field to one option is not a rule, it is a fixed cycle.
      var choices = pool.where((g) => !recent.contains(g)).toList();
      if (choices.length < 2 && _games.isNotEmpty) {
        choices = pool.where((g) => g != _games.last).toList();
      }

      final from = choices.isEmpty ? pool : choices;
      _games.add(from[rng.nextInt(from.length)]);
    }
    return _games[number - 1];
  }

  /// Difficulty rises in steps, not smoothly, and plateaus.
  ///
  /// A curve that climbs every stage becomes unbeatable; one that never climbs
  /// becomes dull. Steps with flat stretches let a player feel competent for a
  /// while before being asked for more.
  static int _difficultyAt(int number) => ((number - 1) ~/ 7).clamp(0, 6);

  /// The goal for a stage, with a little jitter.
  ///
  /// Difficulty only steps every seven stages, so without jitter the same game
  /// produced a word-for-word identical objective every time it came round —
  /// "14 squares" three times inside seven stages. Identical text is what makes
  /// a ladder feel like a treadmill, and the variation costs nothing.
  static StageGoal _goalFor(StageGame game, int difficulty, Random rng) {
    switch (game) {
      case StageGame.cascade:
        // A score target rather than a move limit: the point is to chase chains,
        // and counting moves would push the player toward safe single matches.
        return ReachScore(600 + difficulty * 400);

      case StageGame.game2048:
        // 64, 128, 256… the tile a player is chasing anyway, so no jitter here:
        // a target that is not a power of two reads as a mistake.
        return ReachScore(64 * (1 << difficulty.clamp(0, 5)));

      case StageGame.wordSearch:
        return MakeProgress(moves: 3 + difficulty + rng.nextInt(2), label: 'words');

      case StageGame.memoryMatch:
        return WinInMoves(_round(14 + (6 - difficulty) * 2 + rng.nextInt(3), 2));

      case StageGame.nonogram:
        return WinWithin(
          Duration(seconds: _round(180 - difficulty * 15 - rng.nextInt(10), 5)),
        );

      case StageGame.minesweeper:
        return MakeProgress(
          moves: 8 + difficulty * 2 + rng.nextInt(4),
          label: 'squares',
        );

      case StageGame.slidingPuzzle:
        return WinInMoves(_round(60 + (6 - difficulty) * 10 + rng.nextInt(8), 5));

      case StageGame.reaction:
        return ReachScore(1200 + difficulty * 250 + rng.nextInt(4) * 50);

      case StageGame.dotsAndBoxes:
        return const JustWin();

      case StageGame.solitaire:
        return MakeProgress(
          moves: 10 + difficulty * 3 + rng.nextInt(3),
          label: 'moves',
        );
    }
  }

  /// Rounds a jittered target to something a player would say out loud.
  ///
  /// Jitter produced "finish in 123 moves", which reads as a number that fell
  /// out of a formula rather than a target somebody set. Targets are read at a
  /// glance and remembered between attempts, so they have to be round.
  static int _round(int value, int step) => (value / step).round() * step;

  /// The third star, derived from the goal rather than tabulated beside it.
  ///
  /// Two tables drift apart: jitter the goal and a hardcoded stretch can quietly
  /// become the easier of the two, handing out three stars for merely passing.
  /// Deriving it makes "strictly harder" true by construction instead of by
  /// vigilance.
  static StageGoal? _stretchFor(StageGoal goal) {
    return switch (goal) {
      ReachScore(target: final t) => ReachScore(t * 2),
      WinInMoves(maxMoves: final m) => WinInMoves(_round((m * 0.7).round(), 5)),
      WinWithin(limit: final d) =>
        WinWithin(Duration(seconds: _round((d.inSeconds * 0.7).round(), 5))),
      // Progress and plain wins have no natural stretch, and inventing one that
      // cannot be reached is worse than offering none.
      _ => null,
    };
  }
}
