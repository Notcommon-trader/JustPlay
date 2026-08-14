import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

import 'tile_palette.dart';

/// The playable 2048 board.
///
/// Owns only the board and its input. Score, timer, pause and game-over belong
/// to [GameShell], which is why none of them appear here.
class Board2048View extends StatefulWidget {
  const Board2048View({required this.session, this.size = 4, this.seed, super.key});

  final GameSession session;
  final int size;

  /// Fixes the tile spawn sequence. Used by tests and by daily-challenge modes
  /// where every player must get the same board.
  final int? seed;

  @override
  State<Board2048View> createState() => _Board2048ViewState();
}

class _Board2048ViewState extends State<Board2048View> {
  late Random _random = widget.seed != null ? Random(widget.seed) : Random();
  late Board2048 _board = Board2048.newGame(size: widget.size, random: _random);

  /// Indices that merged on the most recent move, so only those tiles pop.
  Set<int> _merged = const {};

  /// Minimum drag distance that counts as a swipe. Below this a stray finger
  /// movement while tapping would fire a move the player never intended.
  static const double _swipeThreshold = 24;

  @override
  void initState() {
    super.initState();
    // The session is created by the shell and starts immediately; the board only
    // needs to react when it is restarted back to `ready`.
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    // The shell owns Restart, so the board watches for the session returning to
    // `ready` and deals a fresh grid. Doing it this way means Restart works from
    // the app bar and from the game-over sheet without either knowing about the
    // board.
    if (widget.session.state.status == GameStatus.ready && _board.score != 0) {
      _deal();
    } else if (widget.session.state.status == GameStatus.ready && _board.highestTile == 0) {
      _deal();
    }
  }

  void _deal() {
    setState(() {
      _random = widget.seed != null ? Random(widget.seed) : Random();
      _board = Board2048.newGame(size: widget.size, random: _random);
      _merged = const {};
    });
    widget.session.start();
  }

  void _move(SlideDirection direction) {
    final state = widget.session.state;
    if (!state.isPlaying) return;

    final result = _board.move(direction);

    // A move that changes nothing must not spawn a tile or count as a move —
    // otherwise a player fills the board by swiping into a wall.
    if (!result.changed) return;

    final next = result.board.spawnTile(_random);

    setState(() {
      _board = next;
      _merged = result.mergedIndices.toSet();
    });

    widget.session
      ..addScore(result.scoreGained)
      ..recordMove();

    if (next.isGameOver) {
      widget.session.finish(GameOutcome.lost);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance < _swipeThreshold) return;

    // Dominant axis wins. Diagonal swipes are common and resolving them to the
    // larger component is what players expect.
    if (velocity.dx.abs() > velocity.dy.abs()) {
      _move(velocity.dx > 0 ? SlideDirection.right : SlideDirection.left);
    } else {
      _move(velocity.dy > 0 ? SlideDirection.down : SlideDirection.up);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // Arrow and WASD support. Not shipped chrome — it exists so the game is
    // playable on desktop during development, which is a far faster loop than
    // reaching for a phone on every change.
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => SlideDirection.left,
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.keyD => SlideDirection.right,
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => SlideDirection.up,
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => SlideDirection.down,
      _ => null,
    };

    if (direction == null) return KeyEventResult.ignored;
    _move(direction);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onPanEnd: _onPanEnd,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(JpSpace.lg),
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gap = constraints.maxWidth * 0.02;
                  final cell = (constraints.maxWidth - gap * (widget.size + 1)) / widget.size;

                  return DecoratedBox(
                    decoration: BoxDecoration(
                      // surfaceContainerHighest, matching every other board in
                      // the catalogue. This one was surfaceContainerLow — a tone
                      // away from the page behind it, so on a phone the board had
                      // no edge and the grid appeared to float on the background.
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: JpRadius.md,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(gap),
                      child: Column(
                        children: [
                          for (var row = 0; row < widget.size; row++) ...[
                            if (row > 0) SizedBox(height: gap),
                            Expanded(
                              child: Row(
                                children: [
                                  for (var col = 0; col < widget.size; col++) ...[
                                    if (col > 0) SizedBox(width: gap),
                                    Expanded(
                                      child: _Tile(
                                        value: _board.tileAt(row, col),
                                        merged: _merged.contains(row * widget.size + col),
                                        cellSize: cell,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One cell.
///
/// Tiles pop into place rather than sliding across the board. Sliding would need
/// stable per-tile identity in the model — the rules currently return a grid of
/// values, not tracked tiles — and that is a real follow-up, not a shortcut
/// worth faking with heuristics that guess which tile went where.
class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.merged, required this.cellSize});

  final int value;
  final bool merged;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: JpDuration.quick,
      curve: JpCurve.standard,
      decoration: BoxDecoration(
        color: TilePalette.background(scheme, value),
        borderRadius: JpRadius.sm,
      ),
      child: Center(
        child: value == 0
            ? const SizedBox.shrink()
            : TweenAnimationBuilder<double>(
                // A merged tile gets a brief overshoot; a tile that merely moved
                // does not. Animating everything on every move reads as noise.
                key: ValueKey('$value-$merged'),
                tween: Tween(begin: merged ? 0.7 : 1.0, end: 1.0),
                duration: JpDuration.quick,
                curve: JpCurve.pop,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(JpSpace.xxs),
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: TilePalette.fontSizeFor(value, cellSize),
                        fontWeight: FontWeight.w700,
                        color: TilePalette.foreground(scheme, value),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
