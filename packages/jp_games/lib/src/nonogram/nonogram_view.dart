import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// Key for the cell at [index].
ValueKey<String> nonogramCellKey(int index) => ValueKey('nono-cell-$index');

/// Key for the clue gutter beside [row].
ValueKey<String> nonogramRowClueKey(int row) => ValueKey('nono-row-clue-$row');

/// Key for the clue gutter above [column].
ValueKey<String> nonogramColumnClueKey(int column) =>
    ValueKey('nono-col-clue-$column');

/// The playable nonogram.
///
/// Tap cycles a cell: blank → filled → crossed → blank. Long-press clears it
/// outright. A mode toggle would be cheaper to build, but crosses outnumber
/// fills in real play and a toggle taxes every one of them.
class NonogramView extends StatefulWidget {
  const NonogramView({
    required this.session,
    this.columns = 10,
    this.rows = 10,
    this.seed,
    super.key,
  });

  final GameSession session;
  final int columns;
  final int rows;
  final int? seed;

  @override
  State<NonogramView> createState() => _NonogramViewState();
}

class _NonogramViewState extends State<NonogramView> {
  late NonogramPuzzle _puzzle = _deal();

  NonogramPuzzle _deal() => NonogramPuzzle.generate(
        columns: widget.columns,
        rows: widget.rows,
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
      setState(() => _puzzle = _deal());
      widget.session.start();
    }
  }

  void _apply(NonogramPuzzle next) {
    if (identical(next, _puzzle)) return;

    setState(() => _puzzle = next);
    widget.session.recordMove();

    if (next.isSolved) {
      widget.session.finish(GameOutcome.won);
    }
  }

  void _cycle(int index) {
    if (!widget.session.state.isPlaying) return;
    _apply(_puzzle.cycle(index));
  }

  void _clear(int index) {
    if (!widget.session.state.isPlaying) return;
    _apply(_puzzle.setMark(index, NonogramMark.blank));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(JpSpace.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The gutters are sized to the longest clue, not to a fixed
            // fraction. A fixed fraction has to guess, and it guesses wrong in
            // both directions: too small and a four-number clue overflows its
            // slot, too large and the grid is squeezed for gutters that are
            // mostly empty. Measuring costs one pass over the clues.
            final rowClueSlots =
                _puzzle.rowClues.fold(1, (m, clue) => max(m, clue.length));
            final columnClueSlots =
                _puzzle.columnClues.fold(1, (m, clue) => max(m, clue.length));

            // One cell size for everything, so clue numbers sit on the same grid
            // as the cells they describe. Whichever axis is tighter decides it.
            final cell = min(
              constraints.maxWidth / (widget.columns + rowClueSlots),
              constraints.maxHeight / (widget.rows + columnClueSlots),
            );

            final rowGutter = cell * rowClueSlots;
            final columnGutter = cell * columnClueSlots;

            return SizedBox(
              width: rowGutter + cell * widget.columns,
              height: columnGutter + cell * widget.rows,
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: rowGutter, height: columnGutter),
                      for (var c = 0; c < widget.columns; c++)
                        _ColumnClue(
                          key: nonogramColumnClueKey(c),
                          clue: _puzzle.columnClues[c],
                          satisfied: _puzzle.isColumnSatisfied(c),
                          width: cell,
                          height: columnGutter,
                        ),
                    ],
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Column(
                          children: [
                            for (var r = 0; r < widget.rows; r++)
                              _RowClue(
                                key: nonogramRowClueKey(r),
                                clue: _puzzle.rowClues[r],
                                satisfied: _puzzle.isRowSatisfied(r),
                                width: rowGutter,
                                height: cell,
                              ),
                          ],
                        ),
                        Expanded(
                          child: _Board(
                            puzzle: _puzzle,
                            onTap: _cycle,
                            onLongPress: _clear,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.puzzle,
    required this.onTap,
    required this.onLongPress,
  });

  final NonogramPuzzle puzzle;
  final void Function(int index) onTap;
  final void Function(int index) onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              for (var r = 0; r < puzzle.rows; r++)
                Expanded(
                  child: Row(
                    children: [
                      for (var c = 0; c < puzzle.columns; c++)
                        Expanded(
                          child: _Cell(
                            key: nonogramCellKey(puzzle.indexOf(r, c)),
                            mark: puzzle.markAt(r, c),
                            onTap: () => onTap(puzzle.indexOf(r, c)),
                            onLongPress: () => onLongPress(puzzle.indexOf(r, c)),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Heavy rules every five cells. Without them a 10x10 grid cannot be
        // counted at a glance, and counting is the entire game.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GuidePainter(
                columns: puzzle.columns,
                rows: puzzle.rows,
                colour: scheme.outline,
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
    required this.mark,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final NonogramMark mark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: switch (mark) {
        NonogramMark.filled => 'Filled',
        NonogramMark.crossed => 'Crossed out',
        NonogramMark.blank => 'Blank',
      },
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: JpDuration.instant,
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: mark == NonogramMark.filled
              ? scheme.primary
              : scheme.surfaceContainerHighest,
          borderRadius: JpRadius.xs,
        ),
        child: mark == NonogramMark.crossed
            ? Center(
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(JpSpace.xs),
                    child: Icon(Icons.close, color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            : null,
        ),
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  const _GuidePainter({
    required this.columns,
    required this.rows,
    required this.colour,
  });

  final int columns;
  final int rows;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;

    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;

    for (var c = 5; c < columns; c += 5) {
      final x = cellWidth * c;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var r = 5; r < rows; r += 5) {
      final y = cellHeight * r;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.columns != columns || old.rows != rows || old.colour != colour;
}

/// Clue numbers above a column, read top to bottom.
///
/// Each number occupies one cell-sized slot, stacked upward from the grid. The
/// first version gave every number an [Expanded] slot instead, which divided the
/// gutter by however many clues that column had — so a two-clue column and a
/// three-clue column put their numbers at different heights and nothing lined
/// up across the board. A nonogram is read by scanning rows and columns of
/// numbers; misaligned clues make that scan impossible.
class _ColumnClue extends StatelessWidget {
  const _ColumnClue({
    required this.clue,
    required this.satisfied,
    required this.width,
    required this.height,
    super.key,
  });

  final List<int> clue;
  final bool satisfied;

  /// One cell wide. Also the height of each clue slot, so numbers sit on the
  /// same grid as the cells they describe.
  final double width;

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (final number in clue)
              SizedBox(
                height: width,
                child: _ClueNumber(number: number, satisfied: satisfied),
              ),
          ],
        ),
      ),
    );
  }
}

/// Clue numbers beside a row, read left to right.
class _RowClue extends StatelessWidget {
  const _RowClue({
    required this.clue,
    required this.satisfied,
    required this.width,
    required this.height,
    super.key,
  });

  final List<int> clue;
  final bool satisfied;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (final number in clue)
              SizedBox(
                // One cell wide, so the last number of every row ends flush
                // against the grid and the columns of clues align. See
                // _ColumnClue for why Expanded was wrong here.
                width: height,
                child: _ClueNumber(number: number, satisfied: satisfied),
              ),
          ],
        ),
      ),
    );
  }
}

/// One clue number.
///
/// Dims once its line is satisfied. This is the most useful feedback in the
/// game: without it the player re-verifies finished lines by hand, over and
/// over, which is where the tedium in a bad picross app comes from.
class _ClueNumber extends StatelessWidget {
  const _ClueNumber({required this.number, required this.satisfied});

  final int number;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: AnimatedDefaultTextStyle(
            duration: JpDuration.quick,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: satisfied
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                  : scheme.onSurface,
            ),
            // A zero clue means an empty line. Printed nonograms show the zero,
            // and hiding it would leave a blank gutter that reads as a bug.
            child: Text('$number'),
          ),
        ),
      ),
    );
  }
}
