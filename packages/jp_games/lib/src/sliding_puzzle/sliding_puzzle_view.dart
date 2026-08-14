import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// The playable sliding puzzle.
///
/// Tap a tile beside the blank to slide it. Unlike 2048 this game *can*
/// animate movement properly: a tile keeps its identity for the whole game, so
/// each one gets a stable key and [AnimatedPositioned] does the rest.
class SlidingPuzzleView extends StatefulWidget {
  const SlidingPuzzleView({required this.session, this.size = 4, this.seed, super.key});

  final GameSession session;
  final int size;
  final int? seed;

  @override
  State<SlidingPuzzleView> createState() => _SlidingPuzzleViewState();
}

class _SlidingPuzzleViewState extends State<SlidingPuzzleView> {
  late SlidingPuzzle _puzzle = _deal();

  SlidingPuzzle _deal() => SlidingPuzzle.shuffled(
        size: widget.size,
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
    // Restart is owned by the shell; the board just watches for the session
    // returning to `ready`. Same pattern as 2048, which is the point — the shell
    // drives both without knowing anything about either.
    if (widget.session.state.status == GameStatus.ready) {
      setState(() => _puzzle = _deal());
      widget.session.start();
    }
  }

  void _tap(int index) {
    if (!widget.session.state.isPlaying) return;

    final moved = _puzzle.move(index);
    // Null means the tile is not beside the blank. Tapping a stuck tile must not
    // count as a move, or the move counter stops meaning anything.
    if (moved == null) return;

    setState(() => _puzzle = moved);
    widget.session.recordMove();

    if (moved.isSolved) {
      widget.session.finish(GameOutcome.won);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(JpSpace.lg),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final board = constraints.maxWidth;
              final gap = board * 0.015;
              final cell = (board - gap * (widget.size + 1)) / widget.size;

              return DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: JpRadius.md,
                ),
                child: Stack(
                  children: [
                    for (var i = 0; i < _puzzle.tiles.length; i++)
                      if (_puzzle.tiles[i] != 0)
                        AnimatedPositioned(
                          // Keyed by tile value, not board position. That is what
                          // lets Flutter animate a tile from its old slot to its
                          // new one instead of rebuilding a different widget in
                          // place.
                          key: ValueKey(_puzzle.tiles[i]),
                          duration: JpDuration.quick,
                          curve: JpCurve.standard,
                          left: gap + (i % widget.size) * (cell + gap),
                          top: gap + (i ~/ widget.size) * (cell + gap),
                          width: cell,
                          height: cell,
                          child: _PuzzleTile(
                            value: _puzzle.tiles[i],
                            movable: _puzzle.canMove(i),
                            cellSize: cell,
                            onTap: () => _tap(i),
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({
    required this.value,
    required this.movable,
    required this.cellSize,
    required this.onTap,
  });

  final int value;
  final bool movable;
  final double cellSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: JpDuration.quick,
        curve: JpCurve.standard,
        decoration: BoxDecoration(
          // Movable tiles are lifted and tinted. Without this the player has to
          // work out adjacency themselves every turn, which is busywork rather
          // than difficulty.
          color: movable ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: JpRadius.sm,
          boxShadow: movable ? JpElevation.low(scheme.shadow) : JpElevation.none,
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: cellSize * 0.36,
              fontWeight: FontWeight.w700,
              color: movable ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
