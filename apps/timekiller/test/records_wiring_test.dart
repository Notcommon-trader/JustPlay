import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:timekiller/catalogue.dart';
import 'package:timekiller/main.dart';

/// Wiring tests for the path a record actually travels: game finishes → shell
/// reports → store saves → the game's sheet shows it.
///
/// Each piece is unit tested where it lives. This file exists because the pieces
/// being right individually has never once meant they were connected.
GameRecordStore storeWith([Map<String, String> seed = const {}]) {
  return GameRecordStore(
    store: InMemoryKeyValueStore({...seed}),
    clock: () => DateTime(2026, 8, 16, 12),
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
        at: DateTime(2026, 8, 15),
      )
      .encode();
}

/// The full app, minus the plugin-backed store that only exists on a device.
Widget app(GameRecordStore records) => TimeKillerApp(records: records);

Future<void> phoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// A game that keeps a score and has more than two levels, so both the record
/// section and the level chips have something to show.
CatalogueEntry scoringGameWithLevels() => appCatalogue.firstWhere(
      (e) =>
          e.levels.length > 2 &&
          e.levels.first.definition.capabilities.showsScore,
    );

/// Opens the full catalogue, which now sits one tap behind the front door.
Future<void> openGames(WidgetTester tester) async {
  await tester.tap(find.textContaining('Or pick one of'));
  await tester.pumpAndSettle();
}

/// Opens the sheet for [entry], from the front door.
Future<void> openSheet(WidgetTester tester, CatalogueEntry entry) async {
  await openGames(tester);
  await tester.scrollUntilVisible(find.text(entry.name), 200);
  await tester.pumpAndSettle();
  await tester.tap(find.text(entry.name));
  await tester.pumpAndSettle();
}

void main() {
  group('the catalogue', () {
    test('every game has rules and at least one level', () {
      // A game with no how-to-play reaches the player as an unexplained grid,
      // which is what sent people back to the home screen in the first place.
      for (final entry in appCatalogue) {
        expect(entry.howToPlay, isNotEmpty, reason: '${entry.name} has no rules');
        expect(entry.levels, isNotEmpty, reason: '${entry.name} has no levels');
      }
    });

    test('every level has a distinct game id', () {
      // Two levels sharing an id would silently share a best score, so beating
      // Sudoku Easy would show as a record on Hard.
      final ids = [
        for (final entry in appCatalogue)
          for (final level in entry.levels) level.definition.id,
      ];

      expect(ids.toSet().length, ids.length, reason: 'duplicate game id');
    });

    test('each game has its own colour', () {
      final colours = appCatalogue.map((e) => e.colour).toSet();
      expect(colours.length, appCatalogue.length);
    });
  });

  group('the home grid', () {
    testWidgets('shows every game without a variant row for each level',
        (tester) async {
      // Ten tiles, not twenty-one rows. The old list was long enough that games
      // at the bottom were never seen.
      final records = storeWith();
      addTearDown(records.dispose);
      await records.load();

      await phoneSurface(tester);
      await tester.pumpWidget(app(records));
      await tester.pumpAndSettle();
      await openGames(tester);

      expect(find.text('Sudoku'), findsOneWidget);
      expect(find.text('Sudoku · Easy'), findsNothing);
      expect(find.text('Sudoku · Hard'), findsNothing);
    });

    testWidgets('marks a game that has been played', (tester) async {
      final entry = appCatalogue.first;
      final gameId = entry.levels.first.definition.id;

      final records = storeWith({
        '${GameRecordStore.keyPrefix}$gameId': encoded(gameId: gameId, score: 10),
      });
      addTearDown(records.dispose);
      await records.load();

      await phoneSurface(tester);
      await tester.pumpWidget(app(records));
      await tester.pumpAndSettle();
      await openGames(tester);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('an untouched catalogue is unmarked', (tester) async {
      final records = storeWith();
      addTearDown(records.dispose);
      await records.load();

      await phoneSurface(tester);
      await tester.pumpWidget(app(records));
      await tester.pumpAndSettle();
      await openGames(tester);

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });

  group('the game sheet', () {
    testWidgets('explains the rules before anything is played', (tester) async {
      final records = storeWith();
      addTearDown(records.dispose);
      await records.load();

      await phoneSurface(tester);
      await tester.pumpWidget(app(records));
      await tester.pumpAndSettle();

      final entry = appCatalogue.first;
      await openSheet(tester, entry);

      expect(find.text('HOW TO PLAY'), findsOneWidget);
      expect(find.text(entry.howToPlay.first.text), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('offers every level of the game', (tester) async {
      final records = storeWith();
      addTearDown(records.dispose);
      await records.load();

      await phoneSurface(tester);
      await tester.pumpWidget(app(records));
      await tester.pumpAndSettle();

      final entry = appCatalogue.firstWhere((e) => e.levels.length > 2);
      await openSheet(tester, entry);

      for (final level in entry.levels) {
        expect(find.text(level.label), findsOneWidget);
      }
    });

    testWidgets('shows no record section for a game never played',
        (tester) async {
      // "Best 0" on an unplayed game is noise pretending to be information.
      final records = storeWith();
      addTearDown(records.dispose);
      await records.load();

      await phoneSurface(tester);
      await tester.pumpWidget(app(records));
      await tester.pumpAndSettle();

      await openSheet(tester, appCatalogue.first);

      expect(find.text('YOUR RECORD'), findsNothing);
    });

    testWidgets('shows the record for the selected level', (tester) async {
      // A scoring game, deliberately: a best score only appears for a game that
      // has one, and sudoku — the first entry — does not.
      final entry = scoringGameWithLevels();
      final level = entry.defaultLevel;
      final gameId = level.definition.id;

      final records = storeWith({
        '${GameRecordStore.keyPrefix}$gameId':
            encoded(gameId: gameId, score: 4096, moves: 120),
      });
      addTearDown(records.dispose);
      await records.load();

      await phoneSurface(tester);
      await tester.pumpWidget(app(records));
      await tester.pumpAndSettle();

      await openSheet(tester, entry);

      expect(find.text('YOUR RECORD'), findsOneWidget);
      expect(find.text('4096'), findsOneWidget);
    });

    testWidgets('a record on one level does not show on another',
        (tester) async {
      // The bug this guards: levels sharing a record, so beating the easy board
      // would show as a record on hard.
      final entry = scoringGameWithLevels();
      final other =
          entry.levels.firstWhere((l) => l != entry.defaultLevel);
      final gameId = other.definition.id;

      final records = storeWith({
        '${GameRecordStore.keyPrefix}$gameId': encoded(gameId: gameId, score: 777),
      });
      addTearDown(records.dispose);
      await records.load();

      await phoneSurface(tester);
      await tester.pumpWidget(app(records));
      await tester.pumpAndSettle();

      await openSheet(tester, entry);

      // The default level is selected, and it has no history.
      expect(find.text('777'), findsNothing);

      await tester.tap(find.text(other.label));
      await tester.pumpAndSettle();

      expect(find.text('777'), findsOneWidget);
    });
  });

  group('playing', () {
    testWidgets('Play opens the chosen level and finishing writes a record',
        (tester) async {
      final records = storeWith();
      addTearDown(records.dispose);
      await records.load();

      await phoneSurface(tester);
      await tester.pumpWidget(app(records));
      await tester.pumpAndSettle();

      final entry = appCatalogue.firstWhere((e) => e.name == 'Reaction');
      await openSheet(tester, entry);
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      // The shell is up, titled with the game rather than the level.
      expect(find.text(entry.name), findsWidgets);
      expect(find.text('SCORE'), findsOneWidget);

      final gameId = entry.defaultLevel.definition.id;
      expect(records.recordFor(gameId).hasBeenPlayed, isFalse,
          reason: 'nothing is recorded until a game actually ends');
    });
  });
}
