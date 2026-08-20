import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:timekiller/catalogue.dart';
import 'package:timekiller/first_play_coach.dart';
import 'package:timekiller/main.dart';

GameRecordStore storeWith([Map<String, String> seed = const {}]) {
  return GameRecordStore(
    store: InMemoryKeyValueStore({...seed}),
    clock: () => DateTime(2026, 8, 16, 12),
  );
}

String encoded(String gameId) => GameRecord(gameId: gameId)
    .merge(
      score: 10,
      moves: 3,
      elapsed: const Duration(seconds: 30),
      won: true,
      at: DateTime(2026, 8, 15),
    )
    .encode();

Future<void> phone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Opens [entry] at its default level, the way a player does.
Future<void> play(WidgetTester tester, CatalogueEntry entry) async {
  // The catalogue moved one screen back when the Journey became the front door.
  await tester.tap(find.textContaining('Or pick one of'));
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(find.text(entry.name), 200);
  await tester.pumpAndSettle();
  await tester.tap(find.text(entry.name));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Play'));
  await tester.pumpAndSettle();
}

void main() {
  group('the catalogue', () {
    test('every game tells the coach what to point at', () {
      for (final entry in appCatalogue) {
        expect(entry.coachMoves, isNotEmpty, reason: '${entry.name} has no hints');
      }
    });

    test('hints stay inside the board', () {
      // Fractions outside 0–1 would put the finger off the playing area, where
      // it points at nothing.
      for (final entry in appCatalogue) {
        for (final move in entry.coachMoves) {
          for (final point in [move.from, if (move.to != null) move.to!]) {
            expect(point.dx, inInclusiveRange(0, 1), reason: entry.name);
            expect(point.dy, inInclusiveRange(0, 1), reason: entry.name);
          }
        }
      }
    });
  });

  group('first play', () {
    testWidgets('shows the gesture on the real board', (tester) async {
      final records = storeWith();
      addTearDown(records.dispose);
      await records.load();

      await phone(tester);
      await tester.pumpWidget(TimeKillerApp(records: records));
      await tester.pumpAndSettle();

      final entry = appCatalogue.first;
      await play(tester, entry);

      expect(find.byType(FirstPlayCoach), findsOneWidget);
      expect(find.text(entry.coachMoves.first.text), findsOneWidget);
    });

    testWidgets('a game already played gets no tutorial', (tester) async {
      // Someone who knows sudoku should never have to dismiss an explanation.
      final entry = appCatalogue.first;
      final gameId = entry.defaultLevel.definition.id;

      final records = storeWith({
        '${GameRecordStore.keyPrefix}$gameId': encoded(gameId),
      });
      addTearDown(records.dispose);
      await records.load();

      await phone(tester);
      await tester.pumpWidget(TimeKillerApp(records: records));
      await tester.pumpAndSettle();

      await play(tester, entry);

      expect(find.text(entry.coachMoves.first.text), findsNothing);
    });

    testWidgets('the first touch clears it and still reaches the board',
        (tester) async {
      // The coach must not cost the player a move. Swallowing the first touch is
      // the small insult that makes someone close an app.
      final records = storeWith();
      addTearDown(records.dispose);
      await records.load();

      await phone(tester);
      await tester.pumpWidget(TimeKillerApp(records: records));
      await tester.pumpAndSettle();

      final entry = appCatalogue.firstWhere((e) => e.name == 'Minesweeper');
      await play(tester, entry);
      expect(find.text(entry.coachMoves.first.text), findsOneWidget);

      // Tap the middle of the board.
      await tester.tapAt(const Offset(195, 500));
      await tester.pumpAndSettle();

      expect(find.text(entry.coachMoves.first.text), findsNothing,
          reason: 'the coach steps aside on first contact');
      expect(find.text('MOVES'), findsOneWidget);
    });
  });

  group('the game colour', () {
    testWidgets('is the exact tile colour, not a palette approximation',
        (tester) async {
      // ColorScheme.fromSeed derives a primary that can be visibly different
      // from the seed, which made the board a near-miss of the tile it came
      // from — close enough to read as a mistake.
      final records = storeWith();
      addTearDown(records.dispose);
      await records.load();

      await phone(tester);
      await tester.pumpWidget(TimeKillerApp(records: records));
      await tester.pumpAndSettle();

      final entry = appCatalogue.firstWhere((e) => e.name == 'Minesweeper');
      await play(tester, entry);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, entry.colour);
    });
  });
}
