import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// Key for a card, wherever it currently sits.
ValueKey<String> solitaireCardKey(PlayingCard card) =>
    ValueKey('card-${card.id}');

const ValueKey<String> solitaireStockKey = ValueKey('solitaire-stock');
const ValueKey<String> solitaireWasteKey = ValueKey('solitaire-waste');

ValueKey<String> solitaireFoundationKey(Suit suit) =>
    ValueKey('solitaire-foundation-${suit.name}');

ValueKey<String> solitaireTableauKey(int pile) =>
    ValueKey('solitaire-tableau-$pile');

/// What a drag is carrying: a run of cards and where it came from.
///
/// [tableauPile] is null when the run came from the waste, which can only ever
/// be a single card.
class SolitaireDrag {
  const SolitaireDrag({
    required this.cards,
    required this.cardIndex,
    this.tableauPile,
  });

  final List<PlayingCard> cards;
  final int cardIndex;
  final int? tableauPile;
}

/// Klondike solitaire.
///
/// Two ways to move a card, because solitaire players are split on it: drag it
/// where you want, or tap it and let the game find the best home — foundation
/// first, then the leftmost tableau pile that will take it.
class SolitaireView extends StatefulWidget {
  const SolitaireView({
    required this.session,
    this.drawCount = 1,
    this.seed,
    super.key,
  });

  final GameSession session;

  /// 1 or 3 cards turned per tap on the stock.
  final int drawCount;

  final int? seed;

  @override
  State<SolitaireView> createState() => _SolitaireViewState();
}

class _SolitaireViewState extends State<SolitaireView> {
  late Solitaire _game = _deal();

  Solitaire _deal() => Solitaire.deal(
        drawCount: widget.drawCount,
        random: widget.seed != null ? Random(widget.seed) : Random(),
      );

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (widget.session.state.status == GameStatus.ready) {
      setState(() => _game = _deal());
      widget.session.start();
    }
  }

  /// Commits [next], or does nothing when the rules refused the move.
  void _apply(Solitaire? next) {
    if (next == null || !widget.session.state.isPlaying) return;

    final gained = next.score - _game.score;
    setState(() => _game = next);
    widget.session.recordMove();
    if (gained != 0) widget.session.addScore(gained);

    if (next.isWon) {
      widget.session.finish(GameOutcome.won);
      return;
    }

    // A dead deal is a real Klondike outcome, not an edge case — roughly one in
    // fifty is unwinnable from the start, and plenty more are lost by ordinary
    // play. Without this the player is left on a board with no legal move and
    // nothing telling them so, waiting for something that will never happen.
    //
    // Found by the automated agent in soak_test.dart, which reported "no legal
    // move remains but the game is not finished" on seed 96 after 119 moves.
    if (!next.hasMoves) widget.session.finish(GameOutcome.lost);
  }

  void _drawFromStock() => _apply(_game.draw());

  /// Sends a card to the best available home.
  ///
  /// Foundation first: it is what the player wants nine times in ten, and the
  /// one time it is wrong the card can be taken back down.
  void _autoPlace({int? tableauPile}) {
    if (tableauPile == null) {
      final toFoundation = _game.playWasteToFoundation();
      if (toFoundation != null) {
        _apply(toFoundation);
        return;
      }
      for (var pile = 0; pile < Solitaire.tableauPiles; pile++) {
        final moved = _game.playWasteToTableau(pile);
        if (moved != null) {
          _apply(moved);
          return;
        }
      }
      return;
    }

    final toFoundation = _game.playTableauToFoundation(tableauPile);
    if (toFoundation != null) {
      _apply(toFoundation);
      return;
    }

    final index = _game.tableau[tableauPile].length - 1;
    for (var pile = 0; pile < Solitaire.tableauPiles; pile++) {
      if (pile == tableauPile) continue;
      final moved = _game.moveTableau(tableauPile, index, pile);
      if (moved != null) {
        _apply(moved);
        return;
      }
    }
  }

  void _dropOnTableau(SolitaireDrag drag, int pile) {
    if (drag.tableauPile == null) {
      _apply(_game.playWasteToTableau(pile));
      return;
    }
    _apply(_game.moveTableau(drag.tableauPile!, drag.cardIndex, pile));
  }

  void _dropOnFoundation(SolitaireDrag drag) {
    // A foundation takes one card. A run dropped on it is not a legal move, and
    // silently taking only the last card would move something the player did not
    // pick up.
    if (drag.cards.length != 1) return;

    if (drag.tableauPile == null) {
      _apply(_game.playWasteToFoundation());
      return;
    }
    _apply(_game.playTableauToFoundation(drag.tableauPile!));
  }

  bool _accepts(SolitaireDrag? drag, {int? tableauPile, Suit? foundation}) {
    if (drag == null || drag.cards.isEmpty) return false;

    if (tableauPile != null) {
      if (drag.tableauPile == tableauPile) return false;
      return _game.canDropOnTableau(drag.cards.first, tableauPile);
    }

    if (drag.cards.length != 1) return false;
    final card = drag.cards.single;
    return card.suit == foundation && _game.canSendToFoundation(card);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Seven columns across the full width. Everything else — card height,
        // fan spacing, the top row — is derived from this one number, so the
        // layout holds together on any screen without breakpoints.
        const gap = JpSpace.xs;
        final cardWidth =
            (constraints.maxWidth - JpSpace.sm * 2 - gap * 6) / Solitaire.tableauPiles;
        final cardHeight = cardWidth / 0.68;

        final tallest = _game.tableau.fold(1, (m, p) => max(m, p.length));
        final tableauHeight =
            constraints.maxHeight - cardHeight - JpSpace.lg * 2 - JpSpace.md;

        // Piles compress rather than scroll. A scrollable tableau fights the
        // drag gesture for the same vertical movement, and the loser is always
        // the drag.
        final fan = tallest <= 1
            ? 0.0
            : ((tableauHeight - cardHeight) / (tallest - 1))
                .clamp(cardHeight * 0.12, cardHeight * 0.32);

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: JpSpace.sm,
            vertical: JpSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopRow(
                game: _game,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                gap: gap,
                onStockTap: _drawFromStock,
                onWasteTap: () => _autoPlace(),
                accepts: (drag, suit) => _accepts(drag, foundation: suit),
                onFoundationDrop: _dropOnFoundation,
              ),
              const SizedBox(height: JpSpace.lg),
              Expanded(
                child: Row(
                  // Stretch, not start: each pile's Stack must be as tall as the
                  // area it fans into. Sized to its top card instead, every card
                  // below the first would draw fine and refuse every tap, because
                  // hit testing stops at the parent's bounds.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var pile = 0; pile < Solitaire.tableauPiles; pile++) ...[
                      if (pile > 0) const SizedBox(width: gap),
                      Expanded(
                        child: _TableauPile(
                          key: solitaireTableauKey(pile),
                          game: _game,
                          pile: pile,
                          cardWidth: cardWidth,
                          cardHeight: cardHeight,
                          fan: fan,
                          onTapTop: () => _autoPlace(tableauPile: pile),
                          accepts: (drag) => _accepts(drag, tableauPile: pile),
                          onDrop: (drag) => _dropOnTableau(drag, pile),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Stock, waste and the four foundations.
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.game,
    required this.cardWidth,
    required this.cardHeight,
    required this.gap,
    required this.onStockTap,
    required this.onWasteTap,
    required this.accepts,
    required this.onFoundationDrop,
  });

  final Solitaire game;
  final double cardWidth;
  final double cardHeight;
  final double gap;
  final VoidCallback onStockTap;
  final VoidCallback onWasteTap;
  final bool Function(SolitaireDrag? drag, Suit suit) accepts;
  final void Function(SolitaireDrag drag) onFoundationDrop;

  @override
  Widget build(BuildContext context) {
    final waste = game.wasteTop;

    return SizedBox(
      height: cardHeight,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: game.stock.isEmpty
                ? 'Turn the pile back over'
                : 'Deal from the stock, ${game.stock.length} cards left',
            excludeSemantics: true,
            onTap: onStockTap,
            child: GestureDetector(
            key: solitaireStockKey,
            onTap: onStockTap,
            child: _Slot(
              width: cardWidth,
              height: cardHeight,
              // An empty stock still shows a slot, with a recycle mark: the tap
              // that turns the waste back over has to look available.
              icon: game.stock.isEmpty ? Icons.refresh : null,
              child: game.stock.isEmpty
                  ? null
                  : _CardFace(card: game.stock.last, width: cardWidth),
            ),
            ),
          ),
          SizedBox(width: gap),
          SizedBox(
            key: solitaireWasteKey,
            width: cardWidth,
            height: cardHeight,
            child: waste == null
                ? _Slot(width: cardWidth, height: cardHeight)
                : _DraggableCard(
                    drag: SolitaireDrag(cards: [waste], cardIndex: 0),
                    width: cardWidth,
                    height: cardHeight,
                    onTap: onWasteTap,
                  ),
          ),
          const Spacer(),
          for (final suit in Suit.values) ...[
            SizedBox(width: gap),
            DragTarget<SolitaireDrag>(
              key: solitaireFoundationKey(suit),
              onWillAcceptWithDetails: (details) => accepts(details.data, suit),
              onAcceptWithDetails: (details) => onFoundationDrop(details.data),
              builder: (context, candidate, rejected) {
                final pile = game.foundations[suit.index];
                return _Slot(
                  width: cardWidth,
                  height: cardHeight,
                  highlighted: candidate.isNotEmpty,
                  suit: suit,
                  child: pile.isEmpty
                      ? null
                      : _CardFace(card: pile.last, width: cardWidth),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _TableauPile extends StatelessWidget {
  const _TableauPile({
    required this.game,
    required this.pile,
    required this.cardWidth,
    required this.cardHeight,
    required this.fan,
    required this.onTapTop,
    required this.accepts,
    required this.onDrop,
    super.key,
  });

  final Solitaire game;
  final int pile;
  final double cardWidth;
  final double cardHeight;
  final double fan;
  final VoidCallback onTapTop;
  final bool Function(SolitaireDrag? drag) accepts;
  final void Function(SolitaireDrag drag) onDrop;

  @override
  Widget build(BuildContext context) {
    final cards = game.tableau[pile];

    return DragTarget<SolitaireDrag>(
      onWillAcceptWithDetails: (details) => accepts(details.data),
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidate, rejected) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _Slot(
              width: cardWidth,
              height: cardHeight,
              highlighted: candidate.isNotEmpty,
            ),
            for (var i = 0; i < cards.length; i++)
              Positioned(
                top: fan * i,
                child: _cardAt(cards, i),
              ),
          ],
        );
      },
    );
  }

  Widget _cardAt(List<PlayingCard> cards, int index) {
    final card = cards[index];
    final isTop = index == cards.length - 1;
    final run = game.runAt(pile, index);

    if (!card.faceUp || run == null) {
      return _CardFace(card: card, width: cardWidth, height: cardHeight);
    }

    return _DraggableCard(
      drag: SolitaireDrag(cards: run, cardIndex: index, tableauPile: pile),
      width: cardWidth,
      height: cardHeight,
      fan: fan,
      // Only the exposed card auto-places. Tapping a buried one would move a
      // whole run somewhere the player never looked at.
      onTap: isTop ? onTapTop : null,
    );
  }
}

/// A card the player can pick up, showing the whole run it would carry.
class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    required this.drag,
    required this.width,
    required this.height,
    this.fan = 0,
    this.onTap,
  });

  final SolitaireDrag drag;
  final double width;
  final double height;
  final double fan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = drag.cards.first;

    final body = Semantics(
      button: true,
      label: describeCard(card),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: _CardFace(card: card, width: width, height: height),
      ),
    );

    return Draggable<SolitaireDrag>(
      data: drag,
      // The run travels with the finger, offset so the card sits under it rather
      // than under the palm.
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          height: height + fan * (drag.cards.length - 1),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < drag.cards.length; i++)
                Positioned(
                  top: fan * i,
                  child: _CardFace(
                    card: drag.cards[i],
                    width: width,
                    height: height,
                  ),
                ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: body),
      child: body,
    );
  }
}

/// An empty position: stock, waste, foundation or an empty tableau pile.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.width,
    required this.height,
    this.highlighted = false,
    this.suit,
    this.icon,
    this.child,
  });

  final double width;
  final double height;

  /// A drag is hovering and would be accepted.
  final bool highlighted;

  final Suit? suit;
  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: JpDuration.quick,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: JpRadius.xs,
        border: Border.all(
          color: highlighted ? scheme.primary : scheme.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: child ??
          Center(
            child: icon != null
                ? Icon(icon, size: width * 0.4, color: scheme.onSurfaceVariant)
                : suit != null
                    ? Text(
                        _suitSymbol(suit!),
                        style: TextStyle(
                          fontSize: width * 0.4,
                          // 0.4 alpha measured 2.02:1 against a required 3.0.
                          // These watermarks say which suit belongs where, so
                          // they are information, not decoration, and have to be
                          // legible rather than merely suggestive.
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                        ),
                      )
                    : null,
          ),
    );
  }
}

/// One card, face up or face down.
class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, required this.width, this.height});

  final PlayingCard card;
  final double width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = height ?? width / 0.68;

    if (!card.faceUp) {
      return Container(
        key: solitaireCardKey(card),
        width: width,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: JpRadius.xs,
          border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.35)),
        ),
      );
    }

    // Red on a light card in both themes. Card faces are the one place a themed
    // palette is wrong: a red suit that is not red stops being readable as one.
    final ink = card.isRed ? const Color(0xFFC62828) : const Color(0xFF1A1A1A);

    return Container(
      key: solitaireCardKey(card),
      width: width,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: JpRadius.xs,
        border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
        boxShadow: JpElevation.low(Colors.black),
      ),
      padding: EdgeInsets.all(width * 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            child: Text(
              _rankLabel(card.rank),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: ink,
                height: 1,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                child: Text(
                  _suitSymbol(card.suit),
                  style: TextStyle(color: ink, height: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card, spoken rather than drawn.
///
/// Suit symbols are glyphs a screen reader either skips or reads as something
/// unhelpful, so the name is spelled out. A face-down card is named as such and
/// nothing more — announcing what it is would hand the game away.
String describeCard(PlayingCard card) {
  if (!card.faceUp) return 'Face down card';

  final rank = switch (card.rank) {
    1 => 'Ace',
    11 => 'Jack',
    12 => 'Queen',
    13 => 'King',
    _ => '${card.rank}',
  };
  return '$rank of ${card.suit.name}';
}

String _rankLabel(int rank) => switch (rank) {
      1 => 'A',
      11 => 'J',
      12 => 'Q',
      13 => 'K',
      _ => '$rank',
    };

String _suitSymbol(Suit suit) => switch (suit) {
      Suit.clubs => '♣',
      Suit.diamonds => '♦',
      Suit.hearts => '♥',
      Suit.spades => '♠',
    };
