import 'dart:math';

enum Suit { clubs, diamonds, hearts, spades }

extension SuitColour on Suit {
  /// Diamonds and hearts. Klondike's whole tableau rule is built on this.
  bool get isRed => this == Suit.diamonds || this == Suit.hearts;
}

/// A playing card. Immutable; flipping produces a new one.
class PlayingCard {
  const PlayingCard({
    required this.suit,
    required this.rank,
    this.faceUp = false,
  });

  final Suit suit;

  /// 1 is the ace, 13 the king.
  final int rank;

  final bool faceUp;

  bool get isRed => suit.isRed;

  PlayingCard get revealed => faceUp ? this : PlayingCard(suit: suit, rank: rank, faceUp: true);
  PlayingCard get hidden => faceUp ? PlayingCard(suit: suit, rank: rank) : this;

  /// Stable identity for keys and equality. Rank and suit are unique in a deck.
  String get id => '${suit.name}-$rank';

  @override
  bool operator ==(Object other) =>
      other is PlayingCard &&
      other.suit == suit &&
      other.rank == rank &&
      other.faceUp == faceUp;

  @override
  int get hashCode => Object.hash(suit, rank, faceUp);

  @override
  String toString() => '$id${faceUp ? '' : '?'}';
}

/// Klondike solitaire.
///
/// Every move returns a new game, or **null when the move is illegal**. The view
/// therefore never has to decide what is legal — it offers the move and lets the
/// rules refuse. That is the same contract as the other games here, and it is
/// what keeps rule bugs out of widget code where they cannot be unit tested.
///
/// Not every deal is winnable. Roughly one Klondike deal in fifty is dead on
/// arrival even with perfect play, and no amount of shuffling changes that — so
/// the game offers a restart rather than pretending otherwise.
class Solitaire {
  const Solitaire._({
    required this.stock,
    required this.waste,
    required this.foundations,
    required this.tableau,
    required this.drawCount,
    required this.score,
    required this.moves,
  });

  static const int tableauPiles = 7;
  static const int foundationPiles = 4;

  /// Deals a fresh game.
  ///
  /// [drawCount] is 1 or 3. Three is the traditional rule and much harder; one
  /// is what most phone players expect, so it is the default.
  factory Solitaire.deal({Random? random, int drawCount = 1}) {
    final rng = random ?? Random();
    final deck = [
      for (final suit in Suit.values)
        for (var rank = 1; rank <= 13; rank++) PlayingCard(suit: suit, rank: rank),
    ]..shuffle(rng);

    final tableau = <List<PlayingCard>>[];
    var next = 0;
    for (var pile = 0; pile < tableauPiles; pile++) {
      final cards = <PlayingCard>[];
      for (var i = 0; i <= pile; i++) {
        final card = deck[next++];
        // Only the last card of each pile starts face up.
        cards.add(i == pile ? card.revealed : card);
      }
      tableau.add(cards);
    }

    return Solitaire._(
      stock: List<PlayingCard>.unmodifiable(deck.sublist(next)),
      waste: const [],
      foundations: List<List<PlayingCard>>.unmodifiable([
        for (var i = 0; i < foundationPiles; i++) const <PlayingCard>[],
      ]),
      tableau: List<List<PlayingCard>>.unmodifiable([
        for (final pile in tableau) List<PlayingCard>.unmodifiable(pile),
      ]),
      drawCount: drawCount,
      score: 0,
      moves: 0,
    );
  }

  final List<PlayingCard> stock;

  /// Face-up cards turned from the stock. Only the last one is playable.
  final List<PlayingCard> waste;

  /// One pile per suit, indexed by [Suit.index], each built ace upward.
  final List<List<PlayingCard>> foundations;

  final List<List<PlayingCard>> tableau;

  final int drawCount;
  final int score;
  final int moves;

  PlayingCard? get wasteTop => waste.isEmpty ? null : waste.last;

  bool get isWon =>
      foundations.every((pile) => pile.length == 13);

  /// Whether any productive move remains.
  ///
  /// A Klondike deal can genuinely die: roughly one in fifty is unwinnable from
  /// the start, and many more are lost by ordinary play. When the stock and
  /// waste are empty and nothing will move, the game is over — and the app has
  /// to say so, or the player is left staring at a board with no moves and no
  /// explanation.
  ///
  /// **Taking a card back off a foundation does not count.** It is a legal move,
  /// so counting it would make almost every dead position look alive; but a game
  /// whose only remaining action is to undo previous progress is lost in every
  /// practical sense, and every solitaire app treats it that way.
  bool get hasMoves {
    if (draw() != null) return true;
    if (playWasteToFoundation() != null) return true;

    for (var pile = 0; pile < tableauPiles; pile++) {
      if (playTableauToFoundation(pile) != null) return true;
      if (playWasteToTableau(pile) != null) return true;
    }

    for (var from = 0; from < tableauPiles; from++) {
      for (var card = 0; card < tableau[from].length; card++) {
        final run = runAt(from, card);
        if (run == null) continue;

        for (var to = 0; to < tableauPiles; to++) {
          if (to == from) continue;
          // Sliding a king between two empty piles changes nothing, so it must
          // not count as a move that keeps the game alive.
          if (card == 0 && tableau[to].isEmpty) continue;
          if (canDropOnTableau(run.first, to)) return true;
        }
      }
    }

    return false;
  }

  /// Won, or dead with no productive move left.
  bool get isOver => isWon || !hasMoves;

  /// Cards still to be placed on a foundation.
  int get remainingCards =>
      52 - foundations.fold(0, (sum, pile) => sum + pile.length);

  /// Turns cards from the stock, or recycles the waste when the stock is empty.
  ///
  /// Returns null only when both piles are empty — there is genuinely nothing to
  /// do, and a UI that let the player tap forever would be lying about it.
  Solitaire? draw() {
    if (stock.isEmpty && waste.isEmpty) return null;

    if (stock.isEmpty) {
      return _copy(
        stock: [for (final card in waste.reversed) card.hidden],
        waste: const [],
        // Recycling is not progress, so it does not score. It still counts as a
        // move, because it is a decision the player made.
        moves: moves + 1,
      );
    }

    final taken = min(drawCount, stock.length);
    return _copy(
      stock: stock.sublist(0, stock.length - taken),
      waste: [
        ...waste,
        for (final card in stock.sublist(stock.length - taken).reversed)
          card.revealed,
      ],
      moves: moves + 1,
    );
  }

  /// Sends the top waste card to its foundation.
  Solitaire? playWasteToFoundation() {
    final card = wasteTop;
    if (card == null) return null;
    if (!_fitsFoundation(card)) return null;

    return _copy(
      waste: waste.sublist(0, waste.length - 1),
      foundations: _withFoundation(card),
      score: score + 10,
      moves: moves + 1,
    );
  }

  /// Sends the top waste card onto a tableau pile.
  Solitaire? playWasteToTableau(int pile) {
    if (pile < 0 || pile >= tableauPiles) return null;

    final card = wasteTop;
    if (card == null) return null;
    if (!_fitsTableau(card, tableau[pile])) return null;

    final next = [...tableau];
    next[pile] = [...tableau[pile], card];

    return _copy(
      waste: waste.sublist(0, waste.length - 1),
      tableau: next,
      score: score + 5,
      moves: moves + 1,
    );
  }

  /// Sends the bottom card of a tableau pile to its foundation.
  Solitaire? playTableauToFoundation(int pile) {
    if (pile < 0 || pile >= tableauPiles) return null;
    if (tableau[pile].isEmpty) return null;

    final card = tableau[pile].last;
    if (!card.faceUp || !_fitsFoundation(card)) return null;

    final next = [...tableau];
    final shortened = tableau[pile].sublist(0, tableau[pile].length - 1);
    final flipped = _flipTop(shortened);
    next[pile] = flipped.pile;

    return _copy(
      tableau: next,
      foundations: _withFoundation(card),
      score: score + 10 + (flipped.turned ? 5 : 0),
      moves: moves + 1,
    );
  }

  /// Moves a card off a foundation back onto the tableau.
  ///
  /// Legal in Klondike and occasionally necessary: a low card sent up too early
  /// can be the only thing that unblocks a colour.
  Solitaire? playFoundationToTableau(Suit suit, int pile) {
    if (pile < 0 || pile >= tableauPiles) return null;
    if (foundations[suit.index].isEmpty) return null;

    final card = foundations[suit.index].last;
    if (!_fitsTableau(card, tableau[pile])) return null;

    final nextFoundations = [...foundations];
    nextFoundations[suit.index] =
        foundations[suit.index].sublist(0, foundations[suit.index].length - 1);

    final nextTableau = [...tableau];
    nextTableau[pile] = [...tableau[pile], card];

    return _copy(
      foundations: nextFoundations,
      tableau: nextTableau,
      score: score - 10,
      moves: moves + 1,
    );
  }

  /// Moves the run starting at [cardIndex] of [from] onto [to].
  ///
  /// The whole run travels together. Klondike's only multi-card move is a valid
  /// descending, alternating-colour sequence, and [runAt] is what decides that.
  Solitaire? moveTableau(int from, int cardIndex, int to) {
    if (from < 0 || from >= tableauPiles) return null;
    if (to < 0 || to >= tableauPiles) return null;
    if (from == to) return null;

    final run = runAt(from, cardIndex);
    if (run == null) return null;
    if (!_fitsTableau(run.first, tableau[to])) return null;

    final next = [...tableau];
    final shortened = tableau[from].sublist(0, cardIndex);
    final flipped = _flipTop(shortened);
    next[from] = flipped.pile;
    next[to] = [...tableau[to], ...run];

    return _copy(
      tableau: next,
      score: score + (flipped.turned ? 5 : 0),
      moves: moves + 1,
    );
  }

  /// The movable run starting at [cardIndex], or null if that is not one.
  ///
  /// Exposed so the view can decide what a drag picks up without duplicating the
  /// rule — a drag that lifts cards the rules will refuse is worse than one that
  /// never starts.
  List<PlayingCard>? runAt(int pile, int cardIndex) {
    if (pile < 0 || pile >= tableauPiles) return null;
    final cards = tableau[pile];
    if (cardIndex < 0 || cardIndex >= cards.length) return null;

    final run = cards.sublist(cardIndex);
    if (run.any((card) => !card.faceUp)) return null;

    for (var i = 1; i < run.length; i++) {
      final above = run[i - 1];
      final below = run[i];
      if (below.rank != above.rank - 1) return null;
      if (below.isRed == above.isRed) return null;
    }
    return run;
  }

  /// Whether [card] can be dropped on [pile]'s top card.
  bool canDropOnTableau(PlayingCard card, int pile) {
    if (pile < 0 || pile >= tableauPiles) return false;
    return _fitsTableau(card, tableau[pile]);
  }

  bool canSendToFoundation(PlayingCard card) => _fitsFoundation(card);

  /// A king goes on an empty pile; anything else goes on the next rank up in the
  /// other colour.
  bool _fitsTableau(PlayingCard card, List<PlayingCard> pile) {
    if (pile.isEmpty) return card.rank == 13;

    final onto = pile.last;
    if (!onto.faceUp) return false;
    return card.rank == onto.rank - 1 && card.isRed != onto.isRed;
  }

  bool _fitsFoundation(PlayingCard card) {
    final pile = foundations[card.suit.index];
    if (pile.isEmpty) return card.rank == 1;
    return card.rank == pile.last.rank + 1;
  }

  List<List<PlayingCard>> _withFoundation(PlayingCard card) {
    final next = [...foundations];
    next[card.suit.index] = [...foundations[card.suit.index], card];
    return next;
  }

  /// Turns the newly exposed card of a pile face up.
  ///
  /// Automatic, and scored: in a physical game the player would do it without
  /// thinking, and making them tap for it adds a tap to nearly every move.
  static ({List<PlayingCard> pile, bool turned}) _flipTop(
    List<PlayingCard> pile,
  ) {
    if (pile.isEmpty || pile.last.faceUp) return (pile: pile, turned: false);

    final next = [...pile];
    next[next.length - 1] = next.last.revealed;
    return (pile: next, turned: true);
  }

  Solitaire _copy({
    List<PlayingCard>? stock,
    List<PlayingCard>? waste,
    List<List<PlayingCard>>? foundations,
    List<List<PlayingCard>>? tableau,
    int? score,
    int? moves,
  }) {
    return Solitaire._(
      stock: List<PlayingCard>.unmodifiable(stock ?? this.stock),
      waste: List<PlayingCard>.unmodifiable(waste ?? this.waste),
      foundations: List<List<PlayingCard>>.unmodifiable([
        for (final pile in foundations ?? this.foundations)
          List<PlayingCard>.unmodifiable(pile),
      ]),
      tableau: List<List<PlayingCard>>.unmodifiable([
        for (final pile in tableau ?? this.tableau)
          List<PlayingCard>.unmodifiable(pile),
      ]),
      drawCount: drawCount,
      // Klondike's score can go negative through foundation takebacks. Clamping
      // at zero would quietly make the penalty free once you were low enough.
      score: score ?? this.score,
      moves: moves ?? this.moves,
    );
  }
}
