import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// Symbols shown on the card faces.
///
/// Icons rather than emoji: emoji render differently on every platform and font
/// version, which would make goldens unstable and the app look inconsistent
/// between Android versions. The list must have at least as many entries as the
/// largest supported pair count.
const List<IconData> kMemoryIcons = [
  Icons.anchor,
  Icons.bolt,
  Icons.cake,
  Icons.diamond,
  Icons.eco,
  Icons.favorite,
  Icons.grass,
  Icons.hive,
  Icons.icecream,
  Icons.key,
  Icons.lightbulb,
  Icons.music_note,
];

/// Key for the card at [index]. Exposed so tests can address a specific card
/// without depending on widget-tree ordering.
ValueKey<String> memoryCardKey(int index) => ValueKey('memory-card-$index');

/// The playable memory board.
class MemoryMatchView extends StatefulWidget {
  const MemoryMatchView({
    required this.session,
    this.pairs = 8,
    this.columns = 4,
    this.seed,
    super.key,
  });

  final GameSession session;
  final int pairs;
  final int columns;
  final int? seed;

  @override
  State<MemoryMatchView> createState() => _MemoryMatchViewState();
}

class _MemoryMatchViewState extends State<MemoryMatchView> {
  late MemoryBoard _board = _deal();
  Timer? _mismatchTimer;

  /// How long a mismatched pair stays visible. Long enough to memorise, short
  /// enough not to feel like being told off.
  static const Duration _mismatchLinger = Duration(milliseconds: 800);

  MemoryBoard _deal() => MemoryBoard.deal(
        pairs: widget.pairs,
        columns: widget.columns,
        random: widget.seed != null ? Random(widget.seed) : Random(),
      );

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    // Without this, a pending flip-back fires against a disposed State after the
    // player leaves mid-turn.
    _mismatchTimer?.cancel();
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (widget.session.state.status == GameStatus.ready) {
      _mismatchTimer?.cancel();
      setState(() => _board = _deal());
      widget.session.start();
    }
  }

  void _tap(int index) {
    if (!widget.session.state.isPlaying) return;

    // Captured before the board is replaced. Comparing against the field after
    // assigning it always reports "no change", which is how the first version of
    // this method silently never scored anything.
    final previous = _board;

    final next = previous.reveal(index);
    // Null covers every illegal tap: an already-revealed card, a matched card,
    // or a third card during the mismatch window. The rules own that decision,
    // so the view never has to track "am I locked" itself.
    if (next == null) return;

    setState(() => _board = next);

    // A turn is two cards. The first reveal does nothing but show a card; the
    // counters move on the second, whichever way it goes.
    if (next.isAwaitingSecondCard) return;

    widget.session.recordMove();

    if (next.hasUnresolvedMismatch) {
      _scheduleFlipBack();
      return;
    }

    if (next.matchedPairs > previous.matchedPairs) {
      widget.session.addScore(100);
    }

    if (next.isComplete) {
      widget.session.finish(GameOutcome.won);
    }
  }

  void _scheduleFlipBack() {
    _mismatchTimer?.cancel();
    _mismatchTimer = Timer(_mismatchLinger, () {
      if (!mounted) return;
      setState(() => _board = _board.resolveMismatch());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(JpSpace.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _board.cardCount,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.columns,
                mainAxisSpacing: JpSpace.sm,
                crossAxisSpacing: JpSpace.sm,
              ),
              itemBuilder: (context, index) => _Card(
                // Stable per-position key. Tests target cards by index through
                // this; without it they would have to index into every
                // GestureDetector on screen, which also picks up the shell's
                // app-bar buttons and silently taps the wrong thing.
                key: memoryCardKey(index),
                icon: kMemoryIcons[_board.symbols[index] % kMemoryIcons.length],
                state: _board.states[index],
                onTap: () => _tap(index),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One card, with a real 3D flip.
///
/// Driven by a [TweenAnimationBuilder] on the target angle rather than an
/// explicit controller: the card only ever animates between two states, which is
/// what implicit animation is for.
class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.state,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final CardState state;
  final VoidCallback onTap;

  bool get _revealed => state != CardState.faceDown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _revealed ? 1 : 0),
        duration: JpDuration.normal,
        curve: JpCurve.standard,
        builder: (context, t, child) {
          // Rotate the whole card through half a turn. Past the halfway point
          // the back face would be mirrored, so the front is drawn instead and
          // counter-rotated — that swap is what makes it read as a flip rather
          // than as a squash.
          final angle = t * pi;
          final showingFront = t > 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // perspective
              ..rotateY(angle),
            child: showingFront
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _face(scheme, front: true),
                  )
                : _face(scheme, front: false),
          );
        },
      ),
    );
  }

  Widget _face(ColorScheme scheme, {required bool front}) {
    final matched = state == CardState.matched;

    return AnimatedContainer(
      duration: JpDuration.quick,
      decoration: BoxDecoration(
        color: !front
            ? scheme.primary
            : (matched ? scheme.tertiaryContainer : scheme.secondaryContainer),
        borderRadius: JpRadius.sm,
        boxShadow: matched ? JpElevation.none : JpElevation.low(scheme.shadow),
      ),
      child: Center(
        child: front
            ? Icon(
                icon,
                // Matched cards fade back rather than vanishing — the player
                // still wants to see the board they have cleared.
                color: matched
                    ? scheme.onTertiaryContainer.withValues(alpha: 0.55)
                    : scheme.onSecondaryContainer,
                size: 32,
              )
            : Icon(Icons.question_mark, color: scheme.onPrimary, size: 24),
      ),
    );
  }
}
