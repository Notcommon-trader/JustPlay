import 'dart:math';

/// A game an automated agent can play, without a screen.
///
/// The point of this abstraction is *volume*. A hand-written test plays one
/// scripted game and asserts what the author already suspected. An agent plays
/// tens of thousands of random games and asserts things that must hold in every
/// one of them — which is how you find the position nobody thought to write down.
///
/// Every game here is deterministic given a seed, so a failure is reproducible:
/// the runner reports the seed and the move number, and replaying them lands on
/// the same broken state.
abstract class PlayableGame<S> {
  /// Used in failure messages. Include the variant, not just the game.
  String get name;

  /// A fresh game.
  S deal(Random random);

  /// Plays one legal move chosen with [random].
  ///
  /// Returns null when the agent has nothing legal left to do. That is not
  /// automatically a bug — a finished game has no moves — but a game that is
  /// *not* finished and has no moves is a softlock, and the runner treats it as
  /// a failure. Deadlocks are the bug class random play is best at finding.
  S? step(S state, Random random);

  /// Whether play has ended: won, lost, or drawn.
  bool isFinished(S state);

  /// Throws if [state] is impossible.
  ///
  /// This is where the value lives. An invariant is a claim about every state
  /// the game can ever reach, so each one is worth more than any number of
  /// example-based assertions — `verify` on solitaire counts the deck, which no
  /// scripted test would think to do after every single move.
  void verify(S state);
}

/// Raised when an agent reaches an impossible state.
///
/// Carries everything needed to reproduce it. A soak failure that cannot be
/// replayed is a rumour, not a bug report.
class SoakFailure implements Exception {
  SoakFailure({
    required this.game,
    required this.seed,
    required this.move,
    required this.reason,
    this.state,
  });

  final String game;
  final int seed;
  final int move;
  final String reason;
  final Object? state;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('$game failed after $move move(s) with seed $seed')
      ..writeln(reason);
    if (state != null) {
      buffer
        ..writeln('--- state ---')
        ..writeln(state);
    }
    buffer.writeln(
      'Reproduce: play $game with Random($seed) and stop after $move moves.',
    );
    return buffer.toString();
  }
}

/// What a soak run did. Reported even on success, because "passed" and "played
/// four games because everything deadlocked immediately" look identical
/// otherwise — and the second is the more interesting result.
class SoakReport {
  SoakReport(this.game);

  final String game;

  int gamesPlayed = 0;
  int movesPlayed = 0;
  int finished = 0;

  /// Games that ran out of moves without reporting themselves finished.
  int exhausted = 0;

  /// Games stopped by the move ceiling rather than by ending.
  int truncated = 0;

  double get averageMoves => gamesPlayed == 0 ? 0 : movesPlayed / gamesPlayed;

  @override
  String toString() =>
      '$game: $gamesPlayed games, $movesPlayed moves '
      '(${averageMoves.toStringAsFixed(1)} avg), '
      '$finished finished, $exhausted exhausted, $truncated truncated';
}

/// Plays [game] many times, checking its invariants after every single move.
///
/// [maxMoves] is a ceiling per game, not an expectation. Without it a rules bug
/// that lets a move repeat forever hangs the suite instead of failing it, and a
/// hung test tells you nothing.
SoakReport soak(
  PlayableGame<Object?> game, {
  int games = 100,
  int maxMoves = 4000,
  int startSeed = 0,
  bool requireProgress = true,
}) {
  final report = SoakReport(game.name);

  for (var seed = startSeed; seed < startSeed + games; seed++) {
    final random = Random(seed);
    var state = game.deal(random);
    var move = 0;

    void check(String stage) {
      try {
        game.verify(state);
      } on Object catch (error) {
        throw SoakFailure(
          game: game.name,
          seed: seed,
          move: move,
          reason: '$stage: $error',
          state: state,
        );
      }
    }

    check('invalid on deal');

    while (move < maxMoves) {
      final next = game.step(state, random);

      if (next == null) {
        // No move available. Fine if the game is over, a softlock if not.
        if (!game.isFinished(state) && requireProgress) {
          throw SoakFailure(
            game: game.name,
            seed: seed,
            move: move,
            reason: 'no legal move remains but the game is not finished — '
                'a player would be stuck on this screen with nothing to do',
            state: state,
          );
        }
        report.exhausted += game.isFinished(state) ? 0 : 1;
        break;
      }

      state = next;
      move++;
      check('invariant broken');

      if (game.isFinished(state)) {
        report.finished++;
        break;
      }
    }

    if (move >= maxMoves) report.truncated++;

    report.gamesPlayed++;
    report.movesPlayed += move;
  }

  return report;
}

/// Throws [message] as a plain failure, for use inside [PlayableGame.verify].
Never invalid(String message) => throw StateError(message);
