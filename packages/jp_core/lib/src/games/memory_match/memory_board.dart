import 'dart:math';

/// State of a single card.
enum CardState { faceDown, faceUp, matched }

/// Memory match: reveal two cards, keep them if they pair.
///
/// The rule that makes this game non-trivial to implement is that a mismatched
/// pair stays visible for a moment before flipping back, and **input must be
/// locked during that window**. Without the lock, a fast tapper reveals three or
/// four cards at once and the game falls apart. That state is modelled
/// explicitly here as [hasUnresolvedMismatch] rather than left to the UI to
/// remember, because a UI-only flag is exactly what gets forgotten on a rebuild.
class MemoryBoard {
  MemoryBoard._(this.symbols, this.states, this.columns);

  /// Deals a shuffled board of [pairs] pairs.
  ///
  /// [columns] controls the grid shape; card count is always `pairs * 2`.
  factory MemoryBoard.deal({int pairs = 8, int columns = 4, Random? random}) {
    assert(pairs >= 2, 'A board needs at least two pairs.');
    assert((pairs * 2) % columns == 0, 'Cards must fill whole rows.');

    final rng = random ?? Random();
    final deck = [
      for (var symbol = 0; symbol < pairs; symbol++) ...[symbol, symbol],
    ]..shuffle(rng);

    return MemoryBoard._(
      List<int>.unmodifiable(deck),
      List<CardState>.unmodifiable(
        List<CardState>.filled(deck.length, CardState.faceDown),
      ),
      columns,
    );
  }

  /// Builds an explicit board. Used by tests and by save/restore.
  factory MemoryBoard.fromState({
    required List<int> symbols,
    required List<CardState> states,
    int columns = 4,
  }) {
    assert(symbols.length == states.length, 'Every card needs a state.');
    return MemoryBoard._(
      List<int>.unmodifiable(symbols),
      List<CardState>.unmodifiable(states),
      columns,
    );
  }

  /// Pair identifier per card position. Two cards sharing a symbol are a pair.
  final List<int> symbols;

  final List<CardState> states;
  final int columns;

  int get cardCount => symbols.length;
  int get rows => cardCount ~/ columns;
  int get pairCount => cardCount ~/ 2;

  int get matchedCount => states.where((s) => s == CardState.matched).length;
  int get matchedPairs => matchedCount ~/ 2;

  bool get isComplete => states.every((s) => s == CardState.matched);

  List<int> get _faceUpIndices => [
        for (var i = 0; i < states.length; i++)
          if (states[i] == CardState.faceUp) i,
      ];

  /// True when two mismatched cards are showing and must be flipped back.
  ///
  /// While this holds, [reveal] refuses every tap. The caller is expected to
  /// wait a beat — long enough for the player to memorise the pair — and then
  /// call [resolveMismatch].
  bool get hasUnresolvedMismatch {
    final up = _faceUpIndices;
    return up.length == 2 && symbols[up[0]] != symbols[up[1]];
  }

  /// Whether tapping [index] would do anything.
  bool canReveal(int index) {
    if (index < 0 || index >= cardCount) return false;
    if (states[index] != CardState.faceDown) return false;
    if (hasUnresolvedMismatch) return false;
    return _faceUpIndices.length < 2;
  }

  /// Turns a card face up, matching the pair immediately if it completes one.
  ///
  /// Returns null for an illegal tap — a card already face up or matched, a tap
  /// during the mismatch window, or a third card. Null rather than an unchanged
  /// board so a caller counting moves can tell "revealed" from "ignored".
  MemoryBoard? reveal(int index) {
    if (!canReveal(index)) return null;

    final next = List<CardState>.from(states);
    next[index] = CardState.faceUp;

    final up = [
      for (var i = 0; i < next.length; i++)
        if (next[i] == CardState.faceUp) i,
    ];

    // A completed pair is matched straight away. Leaving it face up and matching
    // it on the next tick would let the player tap a third card in between.
    if (up.length == 2 && symbols[up[0]] == symbols[up[1]]) {
      next[up[0]] = CardState.matched;
      next[up[1]] = CardState.matched;
    }

    return MemoryBoard._(symbols, List<CardState>.unmodifiable(next), columns);
  }

  /// Flips the mismatched pair back down. A no-op when nothing is mismatched, so
  /// a stray timer firing after a restart cannot corrupt a fresh board.
  MemoryBoard resolveMismatch() {
    if (!hasUnresolvedMismatch) return this;

    final next = [
      for (final state in states)
        if (state == CardState.faceUp) CardState.faceDown else state,
    ];

    return MemoryBoard._(symbols, List<CardState>.unmodifiable(next), columns);
  }

  /// True when exactly one card is showing — the player is mid-turn.
  bool get isAwaitingSecondCard => _faceUpIndices.length == 1;

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final i = r * columns + c;
        final glyph = switch (states[i]) {
          CardState.faceDown => '#',
          CardState.faceUp => '${symbols[i]}',
          CardState.matched => '*',
        };
        buffer.write(glyph.padLeft(3));
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
