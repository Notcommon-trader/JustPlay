import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// Key for an edge, so tests can tap one without geometry guesswork.
ValueKey<String> dotsEdgeKey(Edge edge) =>
    ValueKey('dots-edge-${edge.orientation.name}-${edge.index}');

/// Dots and boxes against the computer.
///
/// The first game in the catalogue with an opponent, which adds a shape the
/// others do not have: the board is sometimes **not the player's to touch**.
/// Input is refused during the AI's turn, and the AI moves on a delay so its
/// play is visible rather than instantaneous.
class DotsAndBoxesView extends StatefulWidget {
  const DotsAndBoxesView({
    required this.session,
    this.rows = 4,
    this.columns = 4,
    this.level = DotsAiLevel.smart,
    this.seed,
    super.key,
  });

  final GameSession session;
  final int rows;
  final int columns;
  final DotsAiLevel level;
  final int? seed;

  @override
  State<DotsAndBoxesView> createState() => _DotsAndBoxesViewState();
}

class _DotsAndBoxesViewState extends State<DotsAndBoxesView> {
  late DotsAndBoxes _board = _deal();
  late Random _random = _newRandom();
  Timer? _aiTimer;

  /// Long enough to read as deliberation, short enough not to feel like waiting.
  static const Duration _aiThinkTime = Duration(milliseconds: 450);

  Random _newRandom() => widget.seed != null ? Random(widget.seed) : Random();

  DotsAndBoxes _deal() =>
      DotsAndBoxes.empty(rows: widget.rows, columns: widget.columns);

  /// The human is always player one.
  bool get _isPlayerTurn => _board.currentPlayer == BoxOwner.one;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    // Otherwise a scheduled AI move fires against a disposed State when the
    // player quits mid-turn.
    _aiTimer?.cancel();
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (widget.session.state.status == GameStatus.ready) {
      _aiTimer?.cancel();
      setState(() {
        _random = _newRandom();
        _board = _deal();
      });
      widget.session.start();
    }
  }

  void _tapEdge(Edge edge) {
    if (!widget.session.state.isPlaying) return;
    // The board is not the player's to touch while the opponent is thinking.
    if (!_isPlayerTurn) return;

    final next = _board.draw(edge);
    if (next == null) return;

    _applyMove(next, scoring: true);
  }

  /// Commits a board, updates the session, and hands over to the AI if needed.
  void _applyMove(DotsAndBoxes next, {required bool scoring}) {
    final gained = next.scoreFor(BoxOwner.one) - _board.scoreFor(BoxOwner.one);

    setState(() => _board = next);

    if (scoring) {
      widget.session.recordMove();
      if (gained > 0) widget.session.addScore(gained * 100);
    }

    if (next.isComplete) {
      widget.session.finish(_outcomeFor(next));
      return;
    }

    if (next.currentPlayer == BoxOwner.two) {
      _scheduleAiMove();
    }
  }

  GameOutcome _outcomeFor(DotsAndBoxes board) => switch (board.winner) {
        BoxOwner.one => GameOutcome.won,
        BoxOwner.two => GameOutcome.lost,
        BoxOwner.none => GameOutcome.draw,
      };

  void _scheduleAiMove() {
    _aiTimer?.cancel();
    _aiTimer = Timer(_aiThinkTime, () {
      if (!mounted) return;
      // The player may have paused or quit while the AI was thinking.
      if (!widget.session.state.isPlaying) return;
      if (_board.isComplete || _board.currentPlayer != BoxOwner.two) return;

      final edge = DotsAndBoxesAi.chooseEdge(_board, widget.level, _random);
      final next = _board.draw(edge)!;

      // The AI's own moves are not the player's move count, and its boxes are
      // not the player's score — _applyMove handles both by diffing player one.
      _applyMove(next, scoring: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _ScoreBar(board: _board, isPlayerTurn: _isPlayerTurn),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(JpSpace.lg),
              child: AspectRatio(
                aspectRatio: widget.columns / widget.rows,
                child: _Grid(
                  board: _board,
                  interactive: _isPlayerTurn && widget.session.state.isPlaying,
                  onTapEdge: _tapEdge,
                  scheme: scheme,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.board, required this.isPlayerTurn});

  final DotsAndBoxes board;
  final bool isPlayerTurn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget side(String label, int score, Color colour, bool active) {
      return AnimatedContainer(
        duration: JpDuration.quick,
        padding: const EdgeInsets.symmetric(
          horizontal: JpSpace.lg,
          vertical: JpSpace.sm,
        ),
        decoration: BoxDecoration(
          // The active side is filled rather than merely labelled. Whose turn it
          // is has to be readable at a glance or the game feels unresponsive.
          color: active ? colour.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: JpRadius.full,
          border: Border.all(
            color: active ? colour : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            const SizedBox(width: JpSpace.sm),
            Text('$label  $score', style: theme.textTheme.labelLarge),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: JpSpace.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          side('You', board.scoreFor(BoxOwner.one), scheme.primary, isPlayerTurn),
          side('CPU', board.scoreFor(BoxOwner.two), scheme.tertiary, !isPlayerTurn),
        ],
      ),
    );
  }
}

/// Dots, edges and boxes laid out as a `(2r+1) x (2c+1)` grid.
///
/// Built from nested rows rather than a CustomPaint so each edge is a real
/// widget with its own hit target and its own animation — painting would mean
/// hand-rolling hit testing and lose both.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.board,
    required this.interactive,
    required this.onTapEdge,
    required this.scheme,
  });

  final DotsAndBoxes board;
  final bool interactive;
  final ValueChanged<Edge> onTapEdge;
  final ColorScheme scheme;

  /// Size of a dot's slot — and therefore the short dimension of every edge's
  /// tap target, since edges fill the gaps between dots.
  ///
  /// Was 10, which made the game's *only* interaction a ten-pixel strip. The dot
  /// drawn inside stays 6px; this is hit area, not ink.
  ///
  /// 24 is still under Material's 48dp minimum, so `androidTapTargetGuideline`
  /// legitimately fails for this game and the exception is recorded in
  /// docs/TESTING.md rather than hidden. Reaching 48 by widening these slots
  /// would leave the dots floating in space; the real fix is to hit-test the
  /// nearest edge across a whole box quadrant, which is a rewrite of _Grid and
  /// has not been done.
  static const double _dotSize = 24;

  Color _ownerColour(BoxOwner owner) => switch (owner) {
        BoxOwner.one => scheme.primary,
        BoxOwner.two => scheme.tertiary,
        BoxOwner.none => Colors.transparent,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r <= board.rows; r++) ...[
          // Row of dots separated by horizontal edges.
          SizedBox(
            height: _dotSize,
            child: Row(
              children: [
                for (var c = 0; c <= board.columns; c++) ...[
                  _dot(),
                  if (c < board.columns)
                    Expanded(
                      child: _edge(Edge(EdgeOrientation.horizontal, r * board.columns + c)),
                    ),
                ],
              ],
            ),
          ),
          // Row of vertical edges separated by boxes.
          if (r < board.rows)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c <= board.columns; c++) ...[
                    SizedBox(
                      width: _dotSize,
                      child: _edge(Edge(EdgeOrientation.vertical, r * (board.columns + 1) + c)),
                    ),
                    if (c < board.columns) Expanded(child: _box(r * board.columns + c)),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _dot() => SizedBox(
        width: _dotSize,
        height: _dotSize,
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );

  Widget _edge(Edge edge) {
    final drawn = board.isDrawn(edge);

    final horizontal = edge.orientation == EdgeOrientation.horizontal;

    return Semantics(
      button: true,
      enabled: !drawn && interactive,
      label: drawn
          ? '${horizontal ? 'Horizontal' : 'Vertical'} line, already drawn'
          : 'Draw ${horizontal ? 'horizontal' : 'vertical'} line',
      excludeSemantics: true,
      onTap: drawn || !interactive ? null : () => onTapEdge(edge),
      child: GestureDetector(
      key: dotsEdgeKey(edge),
      // Opaque so the whole slot is tappable, not just the thin drawn line —
      // a 4px hit target would be unusable on a phone.
      behavior: HitTestBehavior.opaque,
      onTap: drawn || !interactive ? null : () => onTapEdge(edge),
      child: Center(
        child: AnimatedContainer(
          duration: JpDuration.quick,
          curve: JpCurve.standard,
          width: edge.orientation == EdgeOrientation.horizontal ? double.infinity : 4,
          height: edge.orientation == EdgeOrientation.horizontal ? 4 : double.infinity,
          decoration: BoxDecoration(
            color: drawn ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.08),
            borderRadius: JpRadius.xs,
          ),
        ),
        ),
      ),
    );
  }

  Widget _box(int index) {
    final owner = board.owners[index];

    return AnimatedContainer(
      duration: JpDuration.normal,
      curve: JpCurve.enter,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: _ownerColour(owner).withValues(alpha: owner == BoxOwner.none ? 0 : 0.35),
        borderRadius: JpRadius.xs,
      ),
    );
  }
}
