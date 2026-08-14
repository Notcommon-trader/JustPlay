import 'dart:convert';

/// What the app remembers about one game between sessions.
///
/// **Best moves and best time count only wins.** Losing a minesweeper board on
/// the third tap is not a three-move record, and a "best time" set by quitting
/// early is the fastest way to make a statistics screen worthless.
class GameRecord {
  const GameRecord({
    required this.gameId,
    this.bestScore = 0,
    this.bestMoves,
    this.bestTime,
    this.plays = 0,
    this.wins = 0,
    this.totalPlayed = Duration.zero,
    this.lastPlayed,
  });

  /// Reads a record back, or returns an empty one if the stored value is not
  /// something this version understands.
  ///
  /// A record that fails to parse is discarded rather than thrown: a corrupt or
  /// older entry must cost the player one game's history, never a crash on
  /// launch.
  factory GameRecord.decode(String gameId, String source) {
    try {
      final json = jsonDecode(source);
      if (json is! Map<String, dynamic>) return GameRecord(gameId: gameId);

      return GameRecord(
        gameId: gameId,
        bestScore: (json['bestScore'] as num?)?.toInt() ?? 0,
        bestMoves: (json['bestMoves'] as num?)?.toInt(),
        bestTime: json['bestTimeMs'] == null
            ? null
            : Duration(milliseconds: (json['bestTimeMs'] as num).toInt()),
        plays: (json['plays'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        totalPlayed:
            Duration(milliseconds: (json['totalPlayedMs'] as num?)?.toInt() ?? 0),
        lastPlayed: json['lastPlayed'] == null
            ? null
            : DateTime.tryParse(json['lastPlayed'] as String),
      );
    } on FormatException {
      return GameRecord(gameId: gameId);
    }
  }

  /// Matches [GameDefinition.id], so a record follows a game across app builds
  /// and across apps that share it.
  final String gameId;

  final int bestScore;

  /// Fewest moves in a *won* session. Null until the game has been won once.
  final int? bestMoves;

  /// Fastest *won* session.
  final Duration? bestTime;

  final int plays;
  final int wins;
  final Duration totalPlayed;
  final DateTime? lastPlayed;

  bool get hasBeenPlayed => plays > 0;

  String encode() => jsonEncode({
        'bestScore': bestScore,
        if (bestMoves != null) 'bestMoves': bestMoves,
        if (bestTime != null) 'bestTimeMs': bestTime!.inMilliseconds,
        'plays': plays,
        'wins': wins,
        'totalPlayedMs': totalPlayed.inMilliseconds,
        if (lastPlayed != null) 'lastPlayed': lastPlayed!.toIso8601String(),
      });

  /// Folds one finished session into this record.
  ///
  /// Every "best" takes the better of the two rather than the newer, so a bad
  /// round can never overwrite a good one. That rule also makes this safe to
  /// re-apply if a cloud sync ever replays a session twice.
  GameRecord merge({
    required int score,
    required int moves,
    required Duration elapsed,
    required bool won,
    required DateTime at,
  }) {
    return GameRecord(
      gameId: gameId,
      bestScore: score > bestScore ? score : bestScore,
      bestMoves: won && moves > 0
          ? (bestMoves == null || moves < bestMoves! ? moves : bestMoves)
          : bestMoves,
      bestTime: won && elapsed > Duration.zero
          ? (bestTime == null || elapsed < bestTime! ? elapsed : bestTime)
          : bestTime,
      plays: plays + 1,
      wins: wins + (won ? 1 : 0),
      totalPlayed: totalPlayed + elapsed,
      lastPlayed: at,
    );
  }

  /// Takes the better of two records for the same game.
  ///
  /// Written for the cloud-sync rule already recorded in ARCHITECTURE.md: last
  /// write wins per game, except that bests take the maximum. A player who beats
  /// their record offline must not lose it to an older cloud value.
  GameRecord mergeWith(GameRecord other) {
    assert(other.gameId == gameId, 'cannot merge records for different games');

    return GameRecord(
      gameId: gameId,
      bestScore: other.bestScore > bestScore ? other.bestScore : bestScore,
      bestMoves: _lower(bestMoves, other.bestMoves),
      bestTime: _shorter(bestTime, other.bestTime),
      plays: plays > other.plays ? plays : other.plays,
      wins: wins > other.wins ? wins : other.wins,
      totalPlayed: totalPlayed > other.totalPlayed ? totalPlayed : other.totalPlayed,
      lastPlayed: _later(lastPlayed, other.lastPlayed),
    );
  }

  static int? _lower(int? a, int? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a < b ? a : b;
  }

  static Duration? _shorter(Duration? a, Duration? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a < b ? a : b;
  }

  static DateTime? _later(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  @override
  String toString() =>
      'GameRecord($gameId, best: $bestScore, plays: $plays, wins: $wins)';
}
