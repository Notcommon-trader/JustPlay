import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_framework/jp_framework.dart';

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
  late InMemoryKeyValueStore backing;
  late GameRecordStore store;

  setUp(() {
    backing = InMemoryKeyValueStore();
    store = GameRecordStore(
      store: backing,
      clock: () => DateTime(2026, 8, 14, 12),
    );
  });

  tearDown(() => store.dispose());

  group('reading', () {
    test('an unplayed game reads as an empty record, never null', () {
      // Making callers handle null invites a `?? 0` at every call site.
      final record = store.recordFor('nobody');

      expect(record.gameId, 'nobody');
      expect(record.bestScore, 0);
      expect(record.hasBeenPlayed, isFalse);
      expect(store.bestScoreFor('nobody'), 0);
    });

    test('loads what a previous run saved', () async {
      await store.load();
      await store.recordSession('2048', finished(score: 512));

      final reopened = GameRecordStore(store: backing);
      addTearDown(reopened.dispose);
      await reopened.load();

      expect(reopened.bestScoreFor('2048'), 512);
    });

    test('ignores keys that are not records', () async {
      await backing.write('settings.theme', 'dark');
      await store.load();

      expect(store.played, isEmpty);
    });

    test('a corrupt entry does not stop the rest loading', () async {
      await backing.write('${GameRecordStore.keyPrefix}broken', 'not json');
      await backing.write(
        '${GameRecordStore.keyPrefix}fine',
        const GameRecord(gameId: 'fine')
            .merge(
              score: 7,
              moves: 1,
              elapsed: const Duration(seconds: 1),
              won: true,
              at: DateTime(2026, 8, 14),
            )
            .encode(),
      );

      await store.load();

      expect(store.bestScoreFor('fine'), 7);
      expect(store.bestScoreFor('broken'), 0);
    });
  });

  group('recording a session', () {
    test('writes through to storage', () async {
      await store.load();
      await store.recordSession('2048', finished(score: 128, moves: 20));

      expect(
        backing.read('${GameRecordStore.keyPrefix}2048'),
        isNotNull,
        reason: 'the record never reached the backing store',
      );
    });

    test('notifies listeners so the home screen updates immediately', () async {
      await store.load();

      var notifications = 0;
      store.addListener(() => notifications++);

      await store.recordSession('2048', finished(score: 128));

      expect(notifications, greaterThan(0));
    });

    test('stamps the injected clock', () async {
      await store.load();
      final record = await store.recordSession('2048', finished(score: 1));

      expect(record.lastPlayed, DateTime(2026, 8, 14, 12));
    });

    test('a loss still counts as a play', () async {
      await store.load();
      await store.recordSession(
        'minesweeper',
        finished(moves: 3, outcome: GameOutcome.lost),
      );

      final record = store.recordFor('minesweeper');
      expect(record.plays, 1);
      expect(record.wins, 0);
      expect(record.bestMoves, isNull);
    });

    test('accumulates across sessions', () async {
      await store.load();
      await store.recordSession('2048', finished(score: 100));
      await store.recordSession('2048', finished(score: 900));
      await store.recordSession('2048', finished(score: 300));

      final record = store.recordFor('2048');
      expect(record.bestScore, 900);
      expect(record.plays, 3);
    });

    test('keeps games apart', () async {
      await store.load();
      await store.recordSession('2048', finished(score: 100));
      await store.recordSession('sudoku_easy', finished(score: 5));

      expect(store.bestScoreFor('2048'), 100);
      expect(store.bestScoreFor('sudoku_easy'), 5);
    });
  });

  group('listing', () {
    test('played returns only games with history, most recent first', () async {
      var minute = 0;
      final ticking = GameRecordStore(
        store: backing,
        clock: () => DateTime(2026, 8, 14, 12, minute++),
      );
      addTearDown(ticking.dispose);
      await ticking.load();

      await ticking.recordSession('first', finished(score: 1));
      await ticking.recordSession('second', finished(score: 1));

      expect(ticking.played.map((r) => r.gameId), ['second', 'first']);
      expect(ticking.recordFor('never-played').hasBeenPlayed, isFalse);
    });
  });

  group('clearing', () {
    test('removes one game from memory and from storage', () async {
      await store.load();
      await store.recordSession('2048', finished(score: 100));

      await store.clear('2048');

      expect(store.bestScoreFor('2048'), 0);
      expect(backing.read('${GameRecordStore.keyPrefix}2048'), isNull);
    });

    test('clearAll empties everything', () async {
      await store.load();
      await store.recordSession('a', finished(score: 1));
      await store.recordSession('b', finished(score: 2));

      await store.clearAll();

      expect(store.played, isEmpty);
      expect(backing.keys(), isEmpty);
    });
  });
}
