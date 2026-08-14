import 'package:flutter_test/flutter_test.dart';
import 'package:jp_framework/jp_framework.dart';

GameRecord empty([String id = 'game']) => GameRecord(gameId: id);

void main() {
  group('merging a session', () {
    test('keeps the higher score', () {
      final record = empty().merge(
        score: 100,
        moves: 5,
        elapsed: const Duration(seconds: 30),
        won: true,
        at: DateTime(2026, 8, 14),
      );

      final worse = record.merge(
        score: 40,
        moves: 5,
        elapsed: const Duration(seconds: 30),
        won: true,
        at: DateTime(2026, 8, 15),
      );

      expect(worse.bestScore, 100, reason: 'a bad round cannot erase a good one');
    });

    test('counts plays and wins separately', () {
      var record = empty();
      record = record.merge(
        score: 1,
        moves: 1,
        elapsed: const Duration(seconds: 1),
        won: true,
        at: DateTime(2026, 8, 14),
      );
      record = record.merge(
        score: 1,
        moves: 1,
        elapsed: const Duration(seconds: 1),
        won: false,
        at: DateTime(2026, 8, 14),
      );

      expect(record.plays, 2);
      expect(record.wins, 1);
    });

    test('best moves and best time count only wins', () {
      // Losing on the third tap is not a three-move record, and a "best time"
      // set by quitting early makes the whole statistic worthless.
      final lost = empty().merge(
        score: 0,
        moves: 3,
        elapsed: const Duration(seconds: 2),
        won: false,
        at: DateTime(2026, 8, 14),
      );

      expect(lost.bestMoves, isNull);
      expect(lost.bestTime, isNull);

      final won = lost.merge(
        score: 0,
        moves: 60,
        elapsed: const Duration(minutes: 4),
        won: true,
        at: DateTime(2026, 8, 14),
      );

      expect(won.bestMoves, 60);
      expect(won.bestTime, const Duration(minutes: 4));
    });

    test('takes the fewer moves and the shorter time', () {
      var record = empty().merge(
        score: 0,
        moves: 60,
        elapsed: const Duration(minutes: 4),
        won: true,
        at: DateTime(2026, 8, 14),
      );
      record = record.merge(
        score: 0,
        moves: 42,
        elapsed: const Duration(minutes: 6),
        won: true,
        at: DateTime(2026, 8, 15),
      );

      expect(record.bestMoves, 42);
      expect(record.bestTime, const Duration(minutes: 4),
          reason: 'the faster win stands even though the later one used fewer moves');
    });

    test('accumulates total play time and stamps the last play', () {
      final at = DateTime(2026, 8, 14, 9, 30);
      var record = empty().merge(
        score: 0,
        moves: 0,
        elapsed: const Duration(minutes: 3),
        won: false,
        at: at,
      );
      record = record.merge(
        score: 0,
        moves: 0,
        elapsed: const Duration(minutes: 5),
        won: false,
        at: at.add(const Duration(hours: 1)),
      );

      expect(record.totalPlayed, const Duration(minutes: 8));
      expect(record.lastPlayed, at.add(const Duration(hours: 1)));
    });

    test('a zero-move win does not set a move record', () {
      // Some games never call recordMove. Storing "best: 0 moves" would make the
      // statistic unbeatable and meaningless.
      final record = empty().merge(
        score: 10,
        moves: 0,
        elapsed: const Duration(seconds: 5),
        won: true,
        at: DateTime(2026, 8, 14),
      );

      expect(record.bestMoves, isNull);
    });
  });

  group('encoding', () {
    test('survives a round trip', () {
      final record = empty('2048').merge(
        score: 4096,
        moves: 300,
        elapsed: const Duration(minutes: 12, seconds: 30),
        won: true,
        at: DateTime(2026, 8, 14, 10),
      );

      final decoded = GameRecord.decode('2048', record.encode());

      expect(decoded.gameId, '2048');
      expect(decoded.bestScore, 4096);
      expect(decoded.bestMoves, 300);
      expect(decoded.bestTime, const Duration(minutes: 12, seconds: 30));
      expect(decoded.plays, 1);
      expect(decoded.wins, 1);
      expect(decoded.totalPlayed, const Duration(minutes: 12, seconds: 30));
      expect(decoded.lastPlayed, DateTime(2026, 8, 14, 10));
    });

    test('an empty record round trips too', () {
      final decoded = GameRecord.decode('x', empty('x').encode());
      expect(decoded.bestScore, 0);
      expect(decoded.bestMoves, isNull);
      expect(decoded.hasBeenPlayed, isFalse);
    });

    test('unparseable stored data costs one game\'s history, not a crash', () {
      expect(GameRecord.decode('x', 'not json').bestScore, 0);
      expect(GameRecord.decode('x', '[1,2,3]').bestScore, 0);
      expect(GameRecord.decode('x', '').bestScore, 0);
    });

    test('missing fields fall back rather than throwing', () {
      // What a record written by an older version of the app looks like.
      final decoded = GameRecord.decode('x', '{"bestScore":50}');
      expect(decoded.bestScore, 50);
      expect(decoded.plays, 0);
      expect(decoded.bestTime, isNull);
    });
  });

  group('merging two records', () {
    test('keeps the best of each, not the newer', () {
      // The cloud-sync rule: a player who beats their record offline must not
      // lose it to an older cloud value.
      final local = empty('a').merge(
        score: 900,
        moves: 100,
        elapsed: const Duration(minutes: 2),
        won: true,
        at: DateTime(2026, 8, 14),
      );
      final cloud = empty('a').merge(
        score: 400,
        moves: 80,
        elapsed: const Duration(minutes: 5),
        won: true,
        at: DateTime(2026, 8, 15),
      );

      final merged = local.mergeWith(cloud);

      expect(merged.bestScore, 900);
      expect(merged.bestMoves, 80);
      expect(merged.bestTime, const Duration(minutes: 2));
      expect(merged.lastPlayed, DateTime(2026, 8, 15));
    });

    test('is order independent', () {
      final a = empty('a').merge(
        score: 900,
        moves: 100,
        elapsed: const Duration(minutes: 2),
        won: true,
        at: DateTime(2026, 8, 14),
      );
      final b = empty('a').merge(
        score: 400,
        moves: 80,
        elapsed: const Duration(minutes: 5),
        won: true,
        at: DateTime(2026, 8, 15),
      );

      expect(a.mergeWith(b).encode(), b.mergeWith(a).encode());
    });

    test('an untouched record contributes nothing', () {
      final played = empty('a').merge(
        score: 10,
        moves: 1,
        elapsed: const Duration(seconds: 1),
        won: true,
        at: DateTime(2026, 8, 14),
      );

      expect(played.mergeWith(empty('a')).encode(), played.encode());
    });
  });
}
