import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// Key for the cell at [index], so tests can address one without indexing into
/// every GestureDetector on screen.
ValueKey<String> minesweeperCellKey(int index) => ValueKey('mine-cell-$index');

/// The playable minesweeper grid.
///
/// Tap to reveal, long-press to flag. Long-press rather than a mode toggle
/// because a mode toggle means every flag costs three taps and a glance at the
/// toolbar; long-press is what players of this game already expect.
class MinesweeperView extends StatefulWidget {
  const MinesweeperView({
    required this.session,
    this.columns = 9,
    this.rows = 9,
    this.mineCount = 10,
    this.seed,
    super.key,
  });

  final GameSession session;
  final int columns;
  final int rows;
  final int mineCount;
  final int? seed;

  @override
  State<MinesweeperView> createState() => _MinesweeperViewState();
}

class _MinesweeperViewState extends State<MinesweeperView> {
  late MinesweeperBoard _board = _deal();
  late Random _random = _newRandom();

  Random _newRandom() => widget.seed != null ? Random(widget.seed) : Random();

  MinesweeperBoard _deal() => MinesweeperBoard.empty(
        columns: widget.columns,
        rows: widget.rows,
        mineCount: widget.mineCount,
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
      setState(() {
        _random = _newRandom();
        _board = _deal();
      });
      widget.session.start();
    }
  }

  void _reveal(int index) {
    if (!widget.session.state.isPlaying) return;

    final next = _board.reveal(index, random: _random);
    // Null covers an already-revealed cell, a flagged one, or a tap after the
    // game ended. The rules decide; the view does not second-guess them.
    if (next == null) return;

    setState(() => _board = next);
    widget.session.recordMove();

    if (next.isLost) {
      widget.session.finish(GameOutcome.lost);
    } else if (next.isWon) {
      widget.session.finish(GameOutcome.won);
    }
  }

  void _toggleFlag(int index) {
    if (!widget.session.state.isPlaying) return;

    final next = _board.toggleFlag(index);
    if (next == null) return;

    // Flagging is not a move. It is bookkeeping, and counting it would punish
    // careful players in the one statistic they are trying to minimise.
    setState(() => _board = next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Mines remaining is specific to this game, so it lives with the board
        // rather than in the shell's stat bar — the shell deliberately knows
        // only about score, moves and time.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: JpSpace.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flag, size: 18, color: scheme.error),
              const SizedBox(width: JpSpace.xs),
              Text(
                '${_board.minesRemaining}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(JpSpace.lg),
              child: AspectRatio(
                aspectRatio: widget.columns / widget.rows,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _board.cellCount,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.columns,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemBuilder: (context, index) => _Cell(
                    key: minesweeperCellKey(index),
                    state: _board.states[index],
                    isMine: _board.mines[index],
                    adjacent: _board.adjacentMines(index),
                    detonated: _board.hitMineIndex == index,
                    revealAll: _board.isLost,
                    onTap: () => _reveal(index),
                    onLongPress: () => _toggleFlag(index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.state,
    required this.isMine,
    required this.adjacent,
    required this.detonated,
    required this.revealAll,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final CellState state;
  final bool isMine;
  final int adjacent;
  final bool detonated;

  /// After a loss, un-flagged mines are shown. Players want to see what killed
  /// them and what they had already worked out.
  final bool revealAll;

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// What a screen reader announces. Minesweeper is played entirely by counting
  /// adjacent numbers, so the number is the whole content of the cell — a label
  /// of just "button" would make the game unplayable rather than merely awkward.
  String get _label {
    if (state == CellState.flagged) return 'Flagged';
    if (state == CellState.hidden) return 'Hidden';
    if (isMine) return 'Mine';
    return adjacent == 0 ? 'Empty' : '$adjacent adjacent';
  }

  /// Number colours, following the convention every minesweeper player already
  /// has in their head: 1 blue, 2 green, 3 red, then progressively darker.
  Color _numberColour(ColorScheme scheme) {
    return switch (adjacent) {
      1 => scheme.primary,
      2 => const Color(0xFF2E7D32),
      3 => scheme.error,
      4 => const Color(0xFF6A1B9A),
      5 => const Color(0xFF8D6E63),
      _ => scheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final revealed = state == CellState.revealed;
    final showMine = isMine && (revealed || revealAll);

    return Semantics(
      button: true,
      label: _label,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: JpDuration.instant,
        decoration: BoxDecoration(
          color: detonated
              ? scheme.errorContainer
              : revealed
                  ? scheme.surfaceContainerHighest
                  // A hint of the game's colour, not a bath in it.
                  //
                  // This was primaryContainer, which was a soft lavender under
                  // the old single indigo theme. Once each game seeded its own
                  // colour, an 81-cell grid of primaryContainer became a wall of
                  // saturated red — louder than the old grey, and no more
                  // readable. Large areas take a tint; the accent belongs on the
                  // small things the player is actually meant to look at.
                  : Color.lerp(
                      scheme.surfaceContainerHighest,
                      scheme.primary,
                      0.22,
                    )!,
          borderRadius: JpRadius.xs,
        ),
        child: Center(
          child: switch (state) {
            CellState.flagged => Icon(Icons.flag, size: 16, color: scheme.error),
            _ when showMine =>
              Icon(Icons.brightness_high, size: 16, color: scheme.onErrorContainer),
            CellState.revealed when adjacent > 0 => Text(
                '$adjacent',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _numberColour(scheme),
                ),
              ),
            _ => const SizedBox.shrink(),
          },
          ),
        ),
      ),
    );
  }
}
