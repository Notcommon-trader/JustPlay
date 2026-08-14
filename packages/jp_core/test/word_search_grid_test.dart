import 'dart:math';

import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

const List<String> sampleWords = [
  'FLUTTER',
  'WIDGET',
  'STREAM',
  'FUTURE',
  'BUILD',
  'STATE',
];

void main() {
  group('generation', () {
    test('every placed word can actually be read off the grid', () {
      // A word the generator claims to have placed but which is not really there
      // makes the game unwinnable, and the player has no way to know.
      for (var seed = 0; seed < 30; seed++) {
        final grid = WordSearchGrid.generate(
          words: sampleWords,
          size: 10,
          random: Random(seed),
        );
        expect(grid.verifyPlacements(), isTrue, reason: 'seed $seed placed a phantom word');
      }
    });

    test('overlaps only occur where letters already agree', () {
      // Checked implicitly by verifyPlacements across many seeds: if a later
      // word had overwritten an earlier one's letter, the earlier word would no
      // longer read back correctly.
      for (var seed = 30; seed < 60; seed++) {
        final grid = WordSearchGrid.generate(
          words: sampleWords,
          size: 8,
          random: Random(seed),
        );
        expect(grid.verifyPlacements(), isTrue,
            reason: 'seed $seed corrupted an earlier word');
      }
    });

    test('fills the whole grid with letters', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(1));
      expect(grid.letters.length, 100);
      expect(grid.letters.every((l) => l.length == 1), isTrue);
      expect(grid.letters.every((l) => RegExp(r'^[A-Z]$').hasMatch(l)), isTrue);
    });

    test('places at least most of the requested words', () {
      final grid = WordSearchGrid.generate(
        words: sampleWords,
        size: 10,
        random: Random(3),
      );
      expect(grid.words.length, greaterThanOrEqualTo(sampleWords.length - 1));
    });

    test('drops words too long for the grid rather than forcing them', () {
      final grid = WordSearchGrid.generate(
        words: ['EXTRAORDINARILY', 'CAT'],
        size: 5,
        random: Random(1),
      );

      expect(grid.words.map((w) => w.word), isNot(contains('EXTRAORDINARILY')));
      expect(grid.verifyPlacements(), isTrue);
    });

    test('is reproducible for a given seed', () {
      expect(
        WordSearchGrid.generate(words: sampleWords, random: Random(7)).letters,
        WordSearchGrid.generate(words: sampleWords, random: Random(7)).letters,
      );
    });

    test('uppercases input words', () {
      final grid = WordSearchGrid.generate(
        words: ['flutter'],
        size: 8,
        random: Random(1),
      );
      expect(grid.words.single.word, 'FLUTTER');
    });
  });

  group('line selection', () {
    test('accepts a horizontal run', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(1));
      expect(grid.lineBetween(0, 4), [0, 1, 2, 3, 4]);
    });

    test('accepts a vertical run', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(1));
      expect(grid.lineBetween(0, 30), [0, 10, 20, 30]);
    });

    test('accepts a diagonal run', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(1));
      expect(grid.lineBetween(0, 33), [0, 11, 22, 33]);
    });

    test('rejects a path that is not a straight line', () {
      // Without this a player could drag any wandering path and match letters
      // that do not form a line on the board.
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(1));
      expect(grid.lineBetween(0, 12), isNull, reason: '1 across, 1 down is not a line');
      expect(grid.lineBetween(0, 23), isNull);
    });

    test('a single cell is a valid one-cell line', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(1));
      expect(grid.lineBetween(5, 5), [5]);
    });

    test('rejects out-of-range indices', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(1));
      expect(grid.lineBetween(-1, 5), isNull);
      expect(grid.lineBetween(0, 999), isNull);
    });
  });

  group('matching words', () {
    test('matches a word dragged in its written direction', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(4));
      final target = grid.words.first;

      final match = grid.wordForSelection(target.start, target.end);
      expect(match?.word, target.word);
    });

    test('matches a word dragged backwards', () {
      // A player who drags from the last letter to the first has still found it.
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(4));
      final target = grid.words.first;

      final match = grid.wordForSelection(target.end, target.start);
      expect(match?.word, target.word);
    });

    test('returns null for a selection that is not a word', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(4));
      expect(grid.wordForSelection(0, 12), isNull, reason: 'not even a line');
    });

    test('does not re-match a word already found', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(4));
      final target = grid.words.first;

      final after = grid.markFound(target.word);
      expect(after.wordForSelection(target.start, target.end), isNull);
    });
  });

  group('progress', () {
    test('marking a word reduces the remaining count', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(2));
      final before = grid.remainingCount;

      final after = grid.markFound(grid.words.first.word);
      expect(after.remainingCount, before - 1);
    });

    test('marking the same word twice changes nothing', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(2));
      final once = grid.markFound(grid.words.first.word);
      final twice = once.markFound(grid.words.first.word);

      expect(twice.remainingCount, once.remainingCount);
    });

    test('found cells cover exactly the located words', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(2));
      final target = grid.words.first;

      final after = grid.markFound(target.word);
      expect(after.foundCells, target.cells.toSet());
    });

    test('is complete once every placed word is found', () {
      var grid = WordSearchGrid.generate(words: sampleWords, random: Random(2));
      expect(grid.isComplete, isFalse);

      for (final word in grid.words) {
        grid = grid.markFound(word.word);
      }

      expect(grid.isComplete, isTrue);
      expect(grid.remainingCount, 0);
    });

    test('the source grid is never mutated', () {
      final grid = WordSearchGrid.generate(words: sampleWords, random: Random(2));
      grid.markFound(grid.words.first.word);
      expect(grid.found, isEmpty);
    });
  });
}
