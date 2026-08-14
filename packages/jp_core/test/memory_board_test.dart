import 'dart:math';

import 'package:jp_core/jp_core.dart';
import 'package:test/test.dart';

/// A predictable 4-card board: symbols 0,0,1,1 in order, all face down.
MemoryBoard board({List<CardState>? states}) {
  return MemoryBoard.fromState(
    symbols: const [0, 0, 1, 1],
    states: states ?? const [
      CardState.faceDown,
      CardState.faceDown,
      CardState.faceDown,
      CardState.faceDown,
    ],
    columns: 2,
  );
}

void main() {
  group('dealing', () {
    test('every symbol appears exactly twice', () {
      final dealt = MemoryBoard.deal(pairs: 8, random: Random(1));

      final counts = <int, int>{};
      for (final s in dealt.symbols) {
        counts[s] = (counts[s] ?? 0) + 1;
      }

      expect(counts.length, 8);
      expect(counts.values.every((c) => c == 2), isTrue);
    });

    test('all cards start face down', () {
      final dealt = MemoryBoard.deal(random: Random(1));
      expect(dealt.states.every((s) => s == CardState.faceDown), isTrue);
      expect(dealt.isComplete, isFalse);
      expect(dealt.matchedPairs, 0);
    });

    test('is reproducible for a given seed', () {
      expect(
        MemoryBoard.deal(random: Random(9)).symbols,
        MemoryBoard.deal(random: Random(9)).symbols,
      );
    });

    test('grid shape is derived from the column count', () {
      final dealt = MemoryBoard.deal(pairs: 6, columns: 3, random: Random(1));
      expect(dealt.cardCount, 12);
      expect(dealt.rows, 4);
      expect(dealt.pairCount, 6);
    });
  });

  group('revealing', () {
    test('turns a face-down card up', () {
      final next = board().reveal(0)!;
      expect(next.states[0], CardState.faceUp);
      expect(next.isAwaitingSecondCard, isTrue);
    });

    test('a matching second card matches the pair immediately', () {
      // Matched on reveal rather than on a later tick: any gap would let the
      // player tap a third card before the pair resolves.
      final next = board().reveal(0)!.reveal(1)!;

      expect(next.states[0], CardState.matched);
      expect(next.states[1], CardState.matched);
      expect(next.matchedPairs, 1);
      expect(next.hasUnresolvedMismatch, isFalse);
    });

    test('a non-matching second card leaves both showing', () {
      final next = board().reveal(0)!.reveal(2)!;

      expect(next.states[0], CardState.faceUp);
      expect(next.states[2], CardState.faceUp);
      expect(next.hasUnresolvedMismatch, isTrue);
    });

    test('the source board is never mutated', () {
      final source = board();
      source.reveal(0);
      expect(source.states[0], CardState.faceDown);
    });
  });

  group('illegal taps', () {
    test('a card that is already face up cannot be revealed again', () {
      // Otherwise tapping the same card twice "matches" it with itself.
      final next = board().reveal(0)!;
      expect(next.reveal(0), isNull);
    });

    test('a matched card cannot be revealed', () {
      final next = board().reveal(0)!.reveal(1)!;
      expect(next.reveal(0), isNull);
    });

    test('a third card cannot be revealed during the mismatch window', () {
      // The defining bug of this game: without the lock, a fast tapper reveals
      // three or four cards at once.
      final mismatched = board().reveal(0)!.reveal(2)!;

      expect(mismatched.hasUnresolvedMismatch, isTrue);
      expect(mismatched.reveal(1), isNull);
      expect(mismatched.reveal(3), isNull);
      expect(mismatched.canReveal(1), isFalse);
    });

    test('out-of-range indices are rejected rather than throwing', () {
      expect(board().reveal(-1), isNull);
      expect(board().reveal(99), isNull);
    });
  });

  group('resolving a mismatch', () {
    test('flips both cards back down', () {
      final resolved = board().reveal(0)!.reveal(2)!.resolveMismatch();

      expect(resolved.states[0], CardState.faceDown);
      expect(resolved.states[2], CardState.faceDown);
      expect(resolved.hasUnresolvedMismatch, isFalse);
    });

    test('unlocks input again', () {
      final resolved = board().reveal(0)!.reveal(2)!.resolveMismatch();
      expect(resolved.reveal(1), isNotNull);
    });

    test('is a no-op when nothing is mismatched', () {
      // A timer that fires after a restart must not corrupt the fresh board.
      final fresh = board();
      expect(fresh.resolveMismatch().states, fresh.states);

      final matched = board().reveal(0)!.reveal(1)!;
      expect(matched.resolveMismatch().states, matched.states);
    });

    test('does not disturb already-matched cards', () {
      final mixed = board(states: const [
        CardState.matched,
        CardState.matched,
        CardState.faceUp,
        CardState.faceUp,
      ]);

      // Symbols 1 and 1 at indices 2,3 actually match, so this is not a
      // mismatch — resolve must leave it alone.
      expect(mixed.hasUnresolvedMismatch, isFalse);
      expect(mixed.resolveMismatch().states[0], CardState.matched);
    });
  });

  group('completion', () {
    test('is complete once every card is matched', () {
      final done = board().reveal(0)!.reveal(1)!.reveal(2)!.reveal(3)!;

      expect(done.isComplete, isTrue);
      expect(done.matchedPairs, 2);
    });

    test('is not complete while a pair is outstanding', () {
      final partial = board().reveal(0)!.reveal(1)!;
      expect(partial.isComplete, isFalse);
      expect(partial.matchedPairs, 1);
    });

    test('a full board can be cleared start to finish', () {
      // Walks a real 8-pair game to completion, mismatches and all, so the state
      // machine is exercised end to end rather than only in isolated steps.
      var current = MemoryBoard.deal(pairs: 8, random: Random(5));
      var guard = 0;

      while (!current.isComplete && guard++ < 500) {
        if (current.hasUnresolvedMismatch) {
          current = current.resolveMismatch();
          continue;
        }

        // Find any two face-down cards sharing a symbol and take them.
        final faceDown = [
          for (var i = 0; i < current.cardCount; i++)
            if (current.states[i] == CardState.faceDown) i,
        ];
        final first = faceDown.first;
        final partner = faceDown.firstWhere(
          (i) => i != first && current.symbols[i] == current.symbols[first],
        );

        current = current.reveal(first)!.reveal(partner)!;
      }

      expect(current.isComplete, isTrue);
      expect(current.matchedPairs, 8);
    });
  });
}
