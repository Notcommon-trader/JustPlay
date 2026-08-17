import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:timekiller/catalogue.dart';
import 'package:timekiller/main.dart';

/// Goldens for the app's own screens: the game grid and the game sheet.
///
/// These exist because the whole point of the redesign was how it *looks*, and
/// the only honest way to check that is to look at it. Regenerate with
/// `flutter test --update-goldens` and then open the images — a golden that
/// nobody looks at records a bug just as faithfully as it records a fix.
GameRecordStore emptyStore() => GameRecordStore(
      store: InMemoryKeyValueStore(),
      clock: () => DateTime(2026, 8, 16, 12),
    );

Future<void> phone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('the game grid, light', (tester) async {
    await phone(tester);
    final records = emptyStore();
    addTearDown(records.dispose);
    await records.load();

    await tester.pumpWidget(TimeKillerApp(records: records));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_grid_light.png'),
    );
  });

  testWidgets('the game grid, dark', (tester) async {
    // Saturated colour on a dark ground is where eye strain lives: the same
    // gradient that reads as lively at noon glares at midnight.
    await phone(tester);
    final records = emptyStore();
    addTearDown(records.dispose);
    await records.load();

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(TimeKillerApp(records: records));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_grid_dark.png'),
    );
  });

  testWidgets('the game sheet explains the rules and offers levels',
      (tester) async {
    await phone(tester);
    final records = emptyStore();
    addTearDown(records.dispose);
    await records.load();

    await tester.pumpWidget(TimeKillerApp(records: records));
    await tester.pumpAndSettle();

    // Sudoku: three levels and four rules, so the sheet is at its fullest.
    await tester.tap(find.text(appCatalogue.first.name));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/game_sheet.png'),
    );
  });

  testWidgets('a game carries its own colour into the board', (tester) async {
    // The board should be green for Solitaire and red for Minesweeper, not the
    // same indigo for everything. This golden is what would catch that
    // regressing back to one theme.
    await phone(tester);
    final records = emptyStore();
    addTearDown(records.dispose);
    await records.load();

    await tester.pumpWidget(TimeKillerApp(records: records));
    await tester.pumpAndSettle();

    final entry = appCatalogue.firstWhere((e) => e.name == 'Minesweeper');
    await tester.scrollUntilVisible(find.text(entry.name), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/game_themed_board.png'),
    );
  });
}
