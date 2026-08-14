import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_games/jp_games.dart';
import 'package:timekiller/catalogue.dart';
import 'package:timekiller/main.dart';

/// Wiring tests for the path a record actually travels: game finishes → shell
/// reports → store saves → home card shows it.
///
/// Each piece is unit tested where it lives. This file exists because the
/// pieces being right individually has never once meant they were connected.
GameRecordStore storeWith([Map<String, String> seed = const {}]) {
  return GameRecordStore(
    store: InMemoryKeyValueStore({...seed}),
    clock: () => DateTime(2026, 8, 14, 12),
  );
}

String encoded({
  required String gameId,
  int score = 0,
  int moves = 0,
  Duration elapsed = Duration.zero,
  bool won = true,
}) {
  return GameRecord(gameId: gameId)
      .merge(
        score: score,
        moves: moves,
        elapsed: elapsed,
        won: won,
        at: DateTime(2026, 8, 13),
      )
      .encode();
}

/// The full app, minus the plugin-backed store that only exists on a device.
Widget app(GameRecordStore records) => TimeKillerApp(records: records);

Future<void> phoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('a game with no history shows no record line', (tester) async {
    final records = storeWith();
    addTearDown(records.dispose);
    await records.load();

    await phoneSurface(tester);
    await tester.pumpWidget(app(records));
    await tester.pumpAndSettle();

    expect(find.textContaining('Best '), findsNothing);
    expect(find.textContaining('Played '), findsNothing);
  });

  testWidgets('a stored best score reaches the home card', (tester) async {
    // 2048 is the first entry in the catalogue, so its card is on screen
    // without scrolling.
    final gameId = appCatalogue.first.definition.id;

    final records = storeWith({
      '${GameRecordStore.keyPrefix}$gameId': encoded(gameId: gameId, score: 4096),
    });
    addTearDown(records.dispose);
    await records.load();

    await phoneSurface(tester);
    await tester.pumpWidget(app(records));
    await tester.pumpAndSettle();

    expect(find.text('Best 4096'), findsOneWidget);
  });

  testWidgets('a scoreless game shows its best time instead', (tester) async {
    // Minesweeper has no score, so "Best 0" would be both wrong and useless.
    final entry = appCatalogue.firstWhere(
      (e) => e.definition is MinesweeperDefinition,
    );
    final gameId = entry.definition.id;

    final records = storeWith({
      '${GameRecordStore.keyPrefix}$gameId': encoded(
        gameId: gameId,
        moves: 40,
        elapsed: const Duration(minutes: 1, seconds: 23),
      ),
    });
    addTearDown(records.dispose);
    await records.load();

    await phoneSurface(tester);
    await tester.pumpWidget(app(records));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(entry.name), 200);
    await tester.pumpAndSettle();

    expect(find.text('Best 1m 23s'), findsOneWidget);
  });

  testWidgets('a played but never won game falls back to a play count',
      (tester) async {
    final gameId = appCatalogue.first.definition.id;

    final records = storeWith({
      '${GameRecordStore.keyPrefix}$gameId':
          encoded(gameId: gameId, won: false),
    });
    addTearDown(records.dispose);
    await records.load();

    await phoneSurface(tester);
    await tester.pumpWidget(app(records));
    await tester.pumpAndSettle();

    expect(find.text('Played once'), findsOneWidget);
  });

  testWidgets('finishing a game writes a record and updates the card',
      (tester) async {
    // The end-to-end path. Reaction is the one game a test can finish quickly
    // and deterministically, so it is the one worth driving all the way through.
    final entry = appCatalogue.firstWhere(
      (e) => e.definition is ReactionDefinition,
    );

    final records = storeWith();
    addTearDown(records.dispose);
    await records.load();

    await phoneSurface(tester);
    await tester.pumpWidget(app(records));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(entry.name), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry.name));
    await tester.pumpAndSettle();

    // Play out every round: arm, wait past the longest randomised delay, tap.
    final rounds = (entry.definition as ReactionDefinition).rounds;
    for (var i = 0; i < rounds; i++) {
      await tester.tap(find.byKey(reactionSurfaceKey), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 3600));
      await tester.tap(find.byKey(reactionSurfaceKey), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
    }
    await tester.pumpAndSettle();

    expect(find.text('You win'), findsOneWidget);

    final record = records.recordFor(entry.definition.id);
    expect(record.plays, 1);
    expect(record.wins, 1);
    expect(record.bestScore, greaterThan(0));
    expect(
      records.store.read('${GameRecordStore.keyPrefix}${entry.definition.id}'),
      isNotNull,
      reason: 'the record never reached storage',
    );

    // Back to the list: the card now carries the score just earned.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(entry.name), 200);
    await tester.pumpAndSettle();

    expect(find.text('Best ${record.bestScore}'), findsOneWidget);
  });
}
