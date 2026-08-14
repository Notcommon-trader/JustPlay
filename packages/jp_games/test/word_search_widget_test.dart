import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

const int kSeed = 12;
const String kPackId = 'animals';
const int kSize = 10;
const int kWordCount = 6;

Widget host() {
  return MaterialApp(
    theme: JpTheme.light(),
    home: const GameShell(
      definition: WordSearchDefinition(
        size: kSize,
        wordCount: kWordCount,
        packId: kPackId,
        seed: kSeed,
      ),
      title: 'Word Search',
    ),
  );
}

/// Rebuilds the grid the seeded view will have produced.
///
/// This mirrors [WordSearchView]'s deal step by step. If the two ever drift, the
/// [gridMatchesScreen] check below fails loudly rather than the tests quietly
/// dragging across the wrong letters.
WordSearchGrid expectedGrid() {
  final rng = Random(kSeed);
  final pack = packById(kPackId);
  final words = pack.sample(kWordCount, maxLength: kSize, random: rng);
  return WordSearchGrid.generate(words: words, size: kSize, random: rng);
}

void gridMatchesScreen(WidgetTester tester, WordSearchGrid grid) {
  for (final index in [0, 17, grid.cellCount - 1]) {
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(wordSearchCellKey(index)),
        matching: find.byType(Text),
      ),
    );
    expect(text.data, grid.letters[index],
        reason: 'the test grid no longer matches what the view dealt');
  }
}

String statValue(WidgetTester tester, String label) {
  final column = find.ancestor(of: find.text(label), matching: find.byType(Column));
  final texts = tester.widgetList<Text>(
    find.descendant(of: column.first, matching: find.byType(Text)),
  );
  return texts.last.data ?? '';
}

bool chipIsStruck(WidgetTester tester, String word) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byKey(wordSearchChipKey(word)),
      matching: find.byType(Text),
    ),
  );
  return text.style?.decoration == TextDecoration.lineThrough;
}

Future<void> phoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(GoldenSize.phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Drags across [word] the way a player would.
///
/// Moves through the midpoint rather than jumping straight to the end: a single
/// giant move is still recognised, but stepping proves the highlight follows the
/// finger instead of only appearing on release.
Future<void> dragWord(
  WidgetTester tester,
  PlacedWord word, {
  bool backwards = false,
}) async {
  final fromIndex = backwards ? word.end : word.start;
  final toIndex = backwards ? word.start : word.end;

  await dragCells(tester, fromIndex, toIndex);
}

Future<void> dragCells(WidgetTester tester, int fromIndex, int toIndex) async {
  final from = tester.getCenter(find.byKey(wordSearchCellKey(fromIndex)));
  final to = tester.getCenter(find.byKey(wordSearchCellKey(toIndex)));

  final gesture = await tester.startGesture(from);
  await tester.pump();
  await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('shell integration', () {
    testWidgets('shows score and time but no move counter', (tester) async {
      // A "move" here would be one drag, and counting drags punishes the player
      // for looking — which is the whole activity.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('MOVES'), findsNothing);
    });

    testWidgets('the deal matches what the tests expect', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      gridMatchesScreen(tester, expectedGrid());
    });
  });

  group('the word bank', () {
    testWidgets('lists exactly the words that were placed', (tester) async {
      // Never the requested words: a word the generator dropped would be a list
      // entry the player can hunt for forever.
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final grid = expectedGrid();
      for (final placed in grid.words) {
        expect(find.byKey(wordSearchChipKey(placed.word)), findsOneWidget);
      }
    });

    testWidgets('shows the pack name', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('ANIMALS'), findsOneWidget);
    });
  });

  group('finding a word', () {
    testWidgets('dragging along a word scores it and strikes it out',
        (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final target = expectedGrid().words.first;
      expect(chipIsStruck(tester, target.word), isFalse);

      await dragWord(tester, target);

      expect(chipIsStruck(tester, target.word), isTrue);
      expect(
        statValue(tester, 'SCORE'),
        '${WordSearchGrid.pointsFor(target.word)}',
      );
    });

    testWidgets('dragging a word backwards counts too', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final target = expectedGrid().words.first;
      await dragWord(tester, target, backwards: true);

      expect(chipIsStruck(tester, target.word), isTrue);
    });

    testWidgets('a drag that is not a word scores nothing', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // A knight's move: not a line at all, so not even a candidate.
      await dragCells(tester, 0, 12);

      expect(statValue(tester, 'SCORE'), '0');
    });

    testWidgets('finding every word wins the game', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      for (final word in expectedGrid().words) {
        await dragWord(tester, word);
      }

      expect(find.text('You win'), findsOneWidget);
    });
  });

  group('lifecycle', () {
    testWidgets('drags are ignored while paused', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      // Two things stop this drag: the pause overlay sits over the board, and
      // _startDrag checks the session state. Either alone is enough; the
      // assertion is that a paused game makes no progress, however that happens.
      final target = expectedGrid().words.first;
      await dragWord(tester, target);

      expect(statValue(tester, 'SCORE'), '0');
      expect(chipIsStruck(tester, target.word), isFalse);
    });

    testWidgets('restarting deals a fresh grid with nothing found',
        (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final target = expectedGrid().words.first;
      await dragWord(tester, target);
      expect(chipIsStruck(tester, target.word), isTrue);

      await tester.tap(find.byTooltip('Restart'));
      await tester.pumpAndSettle();

      expect(statValue(tester, 'SCORE'), '0');
      // Same seed, so the same grid comes back — but unsolved.
      expect(chipIsStruck(tester, target.word), isFalse);
    });
  });

  group('definition', () {
    test('id encodes the variant', () {
      expect(const WordSearchDefinition().id, 'word_search_classic');
      expect(WordSearchDefinition.large.id, 'word_search_large');
    });

    test('the large variant is bigger in both dimensions', () {
      expect(WordSearchDefinition.large.size,
          greaterThan(const WordSearchDefinition().size));
      expect(WordSearchDefinition.large.wordCount,
          greaterThan(const WordSearchDefinition().wordCount));
    });
  });
}
