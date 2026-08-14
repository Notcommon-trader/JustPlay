import 'package:flutter/foundation.dart';
import 'package:jp_core/jp_core.dart';

import '../storage/key_value_store.dart';
import 'game_record.dart';

/// Every game's history, loaded once and kept in memory.
///
/// App-scoped and long-lived, so unlike [GameSession] it is worth notifying
/// widely: the home screen, a future statistics screen and the shell all read
/// the same instance.
class GameRecordStore extends ChangeNotifier {
  GameRecordStore({required this.store, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  /// Key prefix inside the store. Namespaced so settings and records can share
  /// one backend without colliding.
  static const String keyPrefix = 'record.';

  /// Where records are persisted. Injected so a test can hand in an in-memory
  /// store and an app can hand in the platform one.
  final KeyValueStore store;

  /// Injected so tests can assert on `lastPlayed` instead of ignoring it.
  final DateTime Function() _now;

  final Map<String, GameRecord> _records = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Every game that has been played at least once, most recent first.
  List<GameRecord> get played {
    final all = _records.values.where((r) => r.hasBeenPlayed).toList()
      ..sort((a, b) {
        final aAt = a.lastPlayed;
        final bAt = b.lastPlayed;
        if (aAt == null || bAt == null) return 0;
        return bAt.compareTo(aAt);
      });
    return all;
  }

  Future<void> load() async {
    await store.initialise();

    _records.clear();
    for (final key in store.keys()) {
      if (!key.startsWith(keyPrefix)) continue;

      final gameId = key.substring(keyPrefix.length);
      final raw = store.read(key);
      if (raw == null) continue;

      _records[gameId] = GameRecord.decode(gameId, raw);
    }

    _loaded = true;
    notifyListeners();
  }

  /// The record for [gameId], or an empty one. Never null: a game with no
  /// history and a game that has never been played are the same thing, and
  /// making callers handle null invites a `?? 0` at every call site.
  GameRecord recordFor(String gameId) =>
      _records[gameId] ?? GameRecord(gameId: gameId);

  int bestScoreFor(String gameId) => recordFor(gameId).bestScore;

  /// Folds a finished session into the game's record and saves it.
  ///
  /// Takes the session state rather than loose numbers so a game can never
  /// report a score without the outcome that qualifies it.
  Future<GameRecord> recordSession(String gameId, GameSessionState state) async {
    final merged = recordFor(gameId).merge(
      score: state.score,
      moves: state.moves,
      elapsed: state.elapsed,
      won: state.outcome == GameOutcome.won,
      at: _now(),
    );

    _records[gameId] = merged;
    notifyListeners();

    // The write is awaited, but the in-memory value and the notification are not
    // waiting on it: the player sees their new best immediately, and a slow disk
    // cannot make the UI lag behind the game they just finished.
    await store.write('$keyPrefix$gameId', merged.encode());
    return merged;
  }

  /// Erases one game's history. Wired to a future "reset statistics" control,
  /// and the only supported way to lose a record.
  Future<void> clear(String gameId) async {
    _records.remove(gameId);
    notifyListeners();
    await store.delete('$keyPrefix$gameId');
  }

  Future<void> clearAll() async {
    final ids = _records.keys.toList();
    _records.clear();
    notifyListeners();

    for (final id in ids) {
      await store.delete('$keyPrefix$id');
    }
  }
}
