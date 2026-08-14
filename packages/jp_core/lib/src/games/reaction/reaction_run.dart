/// Result of a single reaction attempt.
enum RoundResult {
  /// Tapped after the target appeared. The normal case.
  hit,

  /// Tapped before the target appeared. The round is spent and scores nothing.
  falseStart,
}

/// Scoring and round tracking for the reaction game.
///
/// Deliberately holds **no timers**. The view owns the waiting and the clock;
/// this owns what a reaction time is worth and when the run is over, which makes
/// every scoring rule testable without pumping a single frame.
///
/// Scoring is inverted from the other games — faster is better — so rather than
/// storing a "score" where lower wins and fighting every assumption the shell
/// makes, each round converts a time into points where **higher is better**.
class ReactionRun {
  const ReactionRun._({
    required this.totalRounds,
    required this.reactionTimesMs,
    required this.falseStarts,
  });

  /// A fresh run of [totalRounds] attempts.
  factory ReactionRun.fresh({int totalRounds = 5}) {
    assert(totalRounds > 0, 'A run needs at least one round.');
    return ReactionRun._(
      totalRounds: totalRounds,
      reactionTimesMs: const [],
      falseStarts: 0,
    );
  }

  final int totalRounds;

  /// Times for successful rounds only. False starts are counted separately
  /// because folding them in as a huge time would wreck the average and hide
  /// what actually happened.
  final List<int> reactionTimesMs;

  final int falseStarts;

  int get completedRounds => reactionTimesMs.length + falseStarts;

  bool get isComplete => completedRounds >= totalRounds;

  int get roundNumber => (completedRounds + 1).clamp(1, totalRounds);

  /// Fastest successful reaction, or null if every round was a false start.
  int? get bestMs =>
      reactionTimesMs.isEmpty ? null : reactionTimesMs.reduce((a, b) => a < b ? a : b);

  /// Mean of successful reactions, or null if there were none.
  int? get averageMs => reactionTimesMs.isEmpty
      ? null
      : (reactionTimesMs.reduce((a, b) => a + b) / reactionTimesMs.length).round();

  /// Total points across the run.
  int get score =>
      reactionTimesMs.fold(0, (sum, ms) => sum + pointsFor(ms));

  /// Points for a single reaction.
  ///
  /// A flat `1000 - ms` curve, floored at zero and capped at a perfect 1000.
  /// Human reaction to a visual cue is roughly 200-300ms, so this puts a good
  /// player around 700-800 a round and leaves headroom without ever going
  /// negative — a negative round would make the total non-monotonic and confuse
  /// anyone chasing a high score.
  static int pointsFor(int reactionMs) {
    if (reactionMs <= 0) return 1000;
    final points = 1000 - reactionMs;
    return points.clamp(0, 1000);
  }

  /// Records a successful reaction. Ignored once the run is complete, so a
  /// late tap arriving after the final round cannot add a phantom score.
  ReactionRun recordHit(int reactionMs) {
    if (isComplete) return this;
    return ReactionRun._(
      totalRounds: totalRounds,
      reactionTimesMs: List<int>.unmodifiable([...reactionTimesMs, reactionMs]),
      falseStarts: falseStarts,
    );
  }

  /// Records a tap made before the target appeared.
  ReactionRun recordFalseStart() {
    if (isComplete) return this;
    return ReactionRun._(
      totalRounds: totalRounds,
      reactionTimesMs: reactionTimesMs,
      falseStarts: falseStarts + 1,
    );
  }

  @override
  String toString() =>
      'ReactionRun($completedRounds/$totalRounds, best: $bestMs, score: $score)';
}
