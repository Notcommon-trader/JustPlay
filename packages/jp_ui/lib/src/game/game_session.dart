import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jp_core/jp_core.dart';

/// Drives one play session: status, score, move count and the elapsed clock.
///
/// Owned by the shell, handed to the game. A game reports what happened
/// (`addScore`, `recordMove`, `finish`) and never manages pause, timing or
/// game-over presentation itself — that is the whole point of having a shell,
/// and it is what keeps a new game down to rules plus a board widget.
///
/// A ChangeNotifier rather than a Riverpod notifier: this is per-session state
/// with a single owner and a short life. Riverpod earns its place for app-scoped
/// state — settings, entitlements, the game catalogue — where sharing and
/// lifetime actually matter.
class GameSession extends ChangeNotifier {
  GameSession({int bestScore = 0, this.tracksTime = true})
      : _state = GameSessionState(bestScore: bestScore);

  /// Whether the elapsed clock runs. Off for untimed puzzles, where a visible
  /// timer adds pressure the game was not designed around.
  final bool tracksTime;

  GameSessionState _state;
  GameSessionState get state => _state;

  Timer? _ticker;

  /// Rebuilding once a second is enough for a mm:ss display and avoids waking
  /// the UI 60 times a second to redraw a label that changes once.
  static const Duration _tickInterval = Duration(seconds: 1);

  void start() {
    if (_state.status == GameStatus.playing) return;
    _update(_state.copyWith(status: GameStatus.playing));
    _startTicker();
  }

  void pause() {
    if (_state.status != GameStatus.playing) return;
    _stopTicker();
    _update(_state.copyWith(status: GameStatus.paused));
  }

  void resume() {
    if (_state.status != GameStatus.paused) return;
    _update(_state.copyWith(status: GameStatus.playing));
    _startTicker();
  }

  /// Restarts in place, keeping [bestScore] so the player can still see what
  /// they are chasing.
  void restart() {
    _stopTicker();
    _update(GameSessionState(bestScore: _state.bestScore));
  }

  void addScore(int points) {
    if (points == 0) return;
    _update(_state.copyWith(score: _state.score + points));
  }

  void recordMove() {
    _update(_state.copyWith(moves: _state.moves + 1));
  }

  /// Ends the session. Idempotent: a game that detects "no moves left" in more
  /// than one place must not be able to fire two game-over sheets.
  void finish(GameOutcome outcome) {
    if (_state.status == GameStatus.finished) return;
    _stopTicker();
    _update(_state.copyWith(status: GameStatus.finished, outcome: outcome));
  }

  /// Restores a previously saved session, for resuming an interrupted game.
  /// Always restored paused — dropping a returning player straight into a live
  /// timer loses them the seconds it takes to re-read the board.
  void restoreFrom(GameSessionState saved) {
    _stopTicker();
    _update(saved.copyWith(
      status: saved.isFinished ? GameStatus.finished : GameStatus.paused,
    ));
  }

  void _startTicker() {
    if (!tracksTime) return;
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) {
      _update(_state.copyWith(elapsed: _state.elapsed + _tickInterval));
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _update(GameSessionState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    // Without this a paused-then-disposed session keeps a periodic timer alive
    // and calls notifyListeners on a dead object — a leak that only shows up
    // after navigating between games a few times.
    _stopTicker();
    super.dispose();
  }
}
