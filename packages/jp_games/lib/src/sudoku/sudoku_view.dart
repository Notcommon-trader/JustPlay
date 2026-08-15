import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// Key for the grid cell at [index].
ValueKey<String> sudokuCellKey(int index) => ValueKey('sudoku-cell-$index');

/// Key for the number pad button for [digit].
ValueKey<String> sudokuPadKey(int digit) => ValueKey('sudoku-pad-$digit');

const ValueKey<String> sudokuNotesKey = ValueKey('sudoku-notes');
const ValueKey<String> sudokuEraseKey = ValueKey('sudoku-erase');
const ValueKey<String> sudokuHintKey = ValueKey('sudoku-hint');

/// The playable sudoku.
///
/// Select a cell, then tap a number. The alternative — select a number, then
/// paint cells — is faster for filling in a whole digit but wrong far more
/// often, because a mis-tap writes a digit instead of just moving the cursor.
class SudokuView extends StatefulWidget {
  const SudokuView({
    required this.session,
    this.difficulty = SudokuDifficulty.medium,
    this.seed,
    super.key,
  });

  final GameSession session;
  final SudokuDifficulty difficulty;
  final int? seed;

  @override
  State<SudokuView> createState() => _SudokuViewState();
}

class _SudokuViewState extends State<SudokuView> {
  late SudokuBoard _board = _deal();
  int? _selected;
  bool _noteMode = false;

  SudokuBoard _deal() => SudokuBoard.generate(
        difficulty: widget.difficulty,
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
      setState(() {
        _board = _deal();
        _selected = null;
        _noteMode = false;
      });
      widget.session.start();
    }
  }

  void _select(int index) {
    if (!widget.session.state.isPlaying) return;
    // Selecting a given is allowed: it highlights every other cell holding that
    // digit, which is how players scan a grid.
    setState(() => _selected = index);
  }

  void _apply(SudokuBoard next) {
    if (identical(next, _board)) return;

    setState(() => _board = next);
    widget.session.recordMove();

    if (next.isSolved) {
      widget.session.finish(GameOutcome.won);
    }
  }

  void _enter(int digit) {
    final index = _selected;
    if (!widget.session.state.isPlaying || index == null) return;

    if (_noteMode) {
      _apply(_board.toggleNote(index, digit));
      return;
    }

    // Tapping the digit already in the cell clears it. Otherwise correcting a
    // mistake means finding the erase button for something the player has
    // already told the app they want gone.
    final next = _board.entries[index] == digit ? null : digit;
    _apply(_board.setDigit(index, next));
  }

  void _erase() {
    final index = _selected;
    if (!widget.session.state.isPlaying || index == null) return;
    _apply(_board.setDigit(index, null));
  }

  void _hint() {
    if (!widget.session.state.isPlaying) return;

    final index = _selected != null && !_board.isGiven(_selected!)
        ? _selected!
        : _board.firstUnsolvedIndex;
    if (index == null) return;

    setState(() => _selected = index);
    _apply(_board.revealHint(index));
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = _board.conflicts;
    final selected = _selected;
    final selectedDigit = selected == null ? null : _board.entries[selected];

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: JpSpace.lg),
              child: AspectRatio(
                aspectRatio: 1,
                child: _Grid(
                  board: _board,
                  selected: selected,
                  selectedDigit: selectedDigit,
                  conflicts: conflicts,
                  onTap: _select,
                ),
              ),
            ),
          ),
        ),
        _Controls(
          noteMode: _noteMode,
          onToggleNotes: () => setState(() => _noteMode = !_noteMode),
          onErase: _erase,
          onHint: _hint,
        ),
        _NumberPad(
          board: _board,
          noteMode: _noteMode,
          onDigit: _enter,
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.board,
    required this.selected,
    required this.selectedDigit,
    required this.conflicts,
    required this.onTap,
  });

  final SudokuBoard board;
  final int? selected;
  final int? selectedDigit;
  final Set<int> conflicts;
  final void Function(int index) onTap;

  /// Whether [index] shares a row, column or box with the selected cell.
  bool _isPeer(int index) {
    final at = selected;
    if (at == null) return false;
    return board.rowOf(at) == board.rowOf(index) ||
        board.columnOf(at) == board.columnOf(index) ||
        board.boxOf(at) == board.boxOf(index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: JpRadius.sm,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                for (var row = 0; row < SudokuBoard.size; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var column = 0; column < SudokuBoard.size; column++)
                          Builder(
                            builder: (context) {
                              final index = row * SudokuBoard.size + column;
                              return Expanded(
                                child: _Cell(
                                  key: sudokuCellKey(index),
                                  row: row + 1,
                                  column: column + 1,
                                  digit: board.entries[index],
                                  notes: board.notes[index],
                                  isGiven: board.isGiven(index),
                                  isSelected: index == selected,
                                  isPeer: _isPeer(index),
                                  sharesDigit: selectedDigit != null &&
                                      board.entries[index] == selectedDigit,
                                  isConflict: conflicts.contains(index),
                                  onTap: () => onTap(index),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GridPainter(
                  cellLine: scheme.outlineVariant,
                  boxLine: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.row,
    required this.column,
    required this.digit,
    required this.notes,
    required this.isGiven,
    required this.isSelected,
    required this.isPeer,
    required this.sharesDigit,
    required this.isConflict,
    required this.onTap,
    super.key,
  });

  final int row;
  final int column;
  final int? digit;
  final Set<int> notes;
  final bool isGiven;
  final bool isSelected;

  /// Shares a row, column or box with the selection.
  final bool isPeer;

  /// Holds the same digit as the selected cell.
  final bool sharesDigit;

  final bool isConflict;
  final VoidCallback onTap;

  /// Row and column are 1-based here because they are read aloud, and "row one"
  /// is what a person says. Notes are announced too — a screen-reader user is
  /// carrying the whole grid in their head and pencil marks are how anyone does
  /// that.
  String get semanticLabel {
    final where = 'Row $row, column $column';
    if (digit != null) {
      final kind = isGiven ? 'given' : 'your answer';
      final clash = isConflict ? ', conflicts' : '';
      return '$where, $digit, $kind$clash';
    }
    if (notes.isNotEmpty) {
      final marks = (notes.toList()..sort()).join(', ');
      return '$where, empty, notes $marks';
    }
    return '$where, empty';
  }

  Color _background(ColorScheme scheme) {
    if (isConflict) return scheme.errorContainer;
    if (isSelected) return scheme.primaryContainer;
    if (sharesDigit) return scheme.secondaryContainer.withValues(alpha: 0.7);
    // Peer tinting is what makes scanning a row possible without a finger on the
    // screen. It has to stay subtle, or the grid reads as three colours of noise.
    if (isPeer) return scheme.surfaceContainerHigh;
    return scheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: JpDuration.instant,
        // No margin: the rules between cells are painted over the whole grid in
        // one pass. Drawing them as per-cell borders doubles every shared edge,
        // and the doubled line is visibly heavier than the outer ones.
        decoration: BoxDecoration(color: _background(scheme)),
        child: Center(
          child: digit != null
              ? FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(JpSpace.xs),
                    child: Text(
                      '$digit',
                      style: TextStyle(
                        // Givens are heavier than the player's own entries, so
                        // the shape of the original puzzle stays readable.
                        fontWeight: isGiven ? FontWeight.w800 : FontWeight.w500,
                        color: isConflict
                            ? scheme.onErrorContainer
                            : isGiven
                                ? scheme.onSurface
                                : scheme.primary,
                      ),
                    ),
                  ),
                )
              : _Notes(notes: notes, colour: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Pencil marks, laid out where the digit itself would sit on a phone keypad.
class _Notes extends StatelessWidget {
  const _Notes({required this.notes, required this.colour});

  final Set<int> notes;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            for (var row = 0; row < 3; row++)
              Expanded(
                child: Row(
                  children: [
                    for (var column = 0; column < 3; column++)
                      Expanded(
                        child: Center(
                          child: notes.contains(row * 3 + column + 1)
                              ? FittedBox(
                                  child: Text(
                                    '${row * 3 + column + 1}',
                                    style: TextStyle(color: colour),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Every rule on the grid: a hairline between cells, a heavy line between boxes,
/// and a border around the outside.
///
/// The two weights are not decoration. Without the heavy box lines the eye
/// cannot find a 3×3 block, and a sudoku is unplayable — which is exactly what
/// the first version of this screen looked like, with cells separated only by a
/// half-pixel gap that vanished at every scale.
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.cellLine, required this.boxLine});

  final Color cellLine;
  final Color boxLine;

  @override
  void paint(Canvas canvas, Size size) {
    final thin = Paint()
      ..color = cellLine
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = boxLine
      ..strokeWidth = 2;

    for (var i = 1; i < SudokuBoard.size; i++) {
      final paint = i % 3 == 0 ? thick : thin;
      final x = size.width / SudokuBoard.size * i;
      final y = size.height / SudokuBoard.size * i;
      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), paint)
        ..drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      thick..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.cellLine != cellLine || old.boxLine != boxLine;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.noteMode,
    required this.onToggleNotes,
    required this.onErase,
    required this.onHint,
  });

  final bool noteMode;
  final VoidCallback onToggleNotes;
  final VoidCallback onErase;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: JpSpace.lg,
        vertical: JpSpace.md,
      ),
      // Wrap, not Row. These three chips need about 369pt laid out in a line,
      // so on a 360pt phone they overflowed by 9.5pt and on a 320pt one by 50 —
      // a yellow-and-black stripe across the controls of the app's flagship
      // puzzle. Wrapping moves the third chip to a second line instead, which
      // costs a few points of height on small screens and nothing on large ones.
      //
      // Scaling the row down with a FittedBox would also have "fixed" it, by
      // shrinking the text below the size it was chosen to be.
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: JpSpace.md,
        runSpacing: JpSpace.sm,
        children: [
          _ControlButton(
            key: sudokuEraseKey,
            icon: Icons.backspace_outlined,
            label: 'Erase',
            onTap: onErase,
          ),
          _ControlButton(
            key: sudokuNotesKey,
            icon: Icons.edit_note,
            label: 'Notes',
            active: noteMode,
            onTap: onToggleNotes,
          ),
          _ControlButton(
            key: sudokuHintKey,
            icon: Icons.lightbulb_outline,
            label: 'Hint',
            onTap: onHint,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: JpDuration.quick,
          padding: const EdgeInsets.symmetric(
            horizontal: JpSpace.md,
            vertical: JpSpace.sm,
          ),
          decoration: BoxDecoration(
            color: active ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            borderRadius: JpRadius.full,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: JpSpace.xs),
              Text(
                label,
                style: TextStyle(
                  color:
                      active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.board,
    required this.noteMode,
    required this.onDigit,
  });

  final SudokuBoard board;
  final bool noteMode;
  final void Function(int digit) onDigit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        JpSpace.sm,
        0,
        JpSpace.sm,
        JpSpace.lg,
      ),
      child: Row(
        children: [
          for (var digit = 1; digit <= SudokuBoard.size; digit++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  key: sudokuPadKey(digit),
                  onTap: () => onDigit(digit),
                  child: AspectRatio(
                    aspectRatio: 0.85,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: noteMode
                            ? scheme.secondaryContainer
                            : scheme.surfaceContainerHighest,
                        borderRadius: JpRadius.sm,
                      ),
                      child: Center(
                        child: FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.all(JpSpace.sm),
                            child: Text(
                              '$digit',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                // A digit with all nine placed fades out. It is
                                // still tappable — the count can be wrong — but
                                // it stops competing for attention.
                                color: board.countOf(digit) >= SudokuBoard.size
                                    ? scheme.onSurfaceVariant
                                        .withValues(alpha: 0.35)
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
