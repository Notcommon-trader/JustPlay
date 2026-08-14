/// Lifecycle of a single play session, identical for every game.
enum GameStatus {
  /// Built but not started. The shell shows a start or tutorial overlay.
  ready,

  playing,

  /// Paused by the player, or by the app going to background.
  paused,

  /// Finished. Whether that is a win, a loss or simply "no moves left" is the
  /// game's business — the shell only needs to know play has stopped.
  finished,
}

/// How a finished session ended. Drives the game-over copy and whether a
/// celebration plays.
enum GameOutcome { none, won, lost, draw }

/// Everything the shell needs to render, for any game.
///
/// Immutable, so a session can be saved, restored, and compared. The shell
/// rebuilds from this alone — a game that needs the shell to show something not
/// represented here is a signal the shell has a gap, not a reason for the game
/// to reach around it.
class GameSessionState {
  const GameSessionState({
    this.status = GameStatus.ready,
    this.outcome = GameOutcome.none,
    this.score = 0,
    this.bestScore = 0,
    this.moves = 0,
    this.elapsed = Duration.zero,
  });

  final GameStatus status;
  final GameOutcome outcome;
  final int score;

  /// Best score recorded for this game before the current session started.
  /// Held here so the shell can show "personal best" without querying storage
  /// mid-render.
  final int bestScore;

  final int moves;
  final Duration elapsed;

  bool get isPlaying => status == GameStatus.playing;
  bool get isFinished => status == GameStatus.finished;
  bool get isPaused => status == GameStatus.paused;

  /// True when this session beat the previous best. Only meaningful once
  /// finished — mid-session it would flicker as the score crosses the old best.
  bool get isNewBest => isFinished && score > bestScore;

  GameSessionState copyWith({
    GameStatus? status,
    GameOutcome? outcome,
    int? score,
    int? bestScore,
    int? moves,
    Duration? elapsed,
  }) {
    return GameSessionState(
      status: status ?? this.status,
      outcome: outcome ?? this.outcome,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      moves: moves ?? this.moves,
      elapsed: elapsed ?? this.elapsed,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GameSessionState &&
        other.status == status &&
        other.outcome == outcome &&
        other.score == score &&
        other.bestScore == bestScore &&
        other.moves == moves &&
        other.elapsed == elapsed;
  }

  @override
  int get hashCode => Object.hash(status, outcome, score, bestScore, moves, elapsed);

  @override
  String toString() =>
      'GameSessionState($status, $outcome, score: $score, best: $bestScore, '
      'moves: $moves, elapsed: $elapsed)';
}
