import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// Key for the letter cell at [index].
ValueKey<String> wordSearchCellKey(int index) => ValueKey('word-cell-$index');

/// Key for the square that owns the drag gesture. Tests use it to convert
/// positions into cells the same way the game does.
const ValueKey<String> wordSearchBoardKey = ValueKey('word-board');

/// Key for the chip listing [word] in the word bank.
ValueKey<String> wordSearchChipKey(String word) => ValueKey('word-chip-$word');

/// The playable word search.
///
/// Selection is a single drag: press the first letter, drag to the last, release.
/// Tap-first-then-tap-last is easier to implement but worse to use — it needs a
/// visible mode, and an accidental tap on the grid leaves a half-made selection
/// the player has to cancel.
class WordSearchView extends StatefulWidget {
  const WordSearchView({
    required this.session,
    this.size = 10,
    this.wordCount = 8,
    this.packId,
    this.seed,
    super.key,
  });

  final GameSession session;

  /// Grid side. Words longer than this are excluded from the sample.
  final int size;

  final int wordCount;

  /// Fixes the subject. Null picks a pack at random, which is what makes a
  /// second round of the same game feel like a different puzzle.
  final String? packId;

  final int? seed;

  @override
  State<WordSearchView> createState() => _WordSearchViewState();
}

class _WordSearchViewState extends State<WordSearchView> {
  late WordPack _pack;
  late WordSearchGrid _grid;

  int? _dragStart;
  int? _dragCurrent;

  /// The word found by the most recent completed drag, kept only so the chip can
  /// pulse. Cleared on the next drag.
  String? _justFound;

  @override
  void initState() {
    super.initState();
    _deal();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _deal() {
    final rng = widget.seed != null ? Random(widget.seed) : Random();
    _pack = widget.packId != null
        ? packById(widget.packId!)
        : wordPacks[rng.nextInt(wordPacks.length)];

    final words = _pack.sample(
      widget.wordCount,
      maxLength: widget.size,
      random: rng,
    );

    _grid = WordSearchGrid.generate(
      words: words,
      size: widget.size,
      random: rng,
    );
    _dragStart = null;
    _dragCurrent = null;
    _justFound = null;
  }

  void _onSessionChanged() {
    if (widget.session.state.status == GameStatus.ready) {
      setState(_deal);
      widget.session.start();
    }
  }

  /// The cell under [position], or null if the point is outside the board.
  int? _cellAt(Offset position, double side) {
    final extent = side / widget.size;
    final column = (position.dx / extent).floor();
    final row = (position.dy / extent).floor();

    if (column < 0 || column >= widget.size) return null;
    if (row < 0 || row >= widget.size) return null;
    return row * widget.size + column;
  }

  void _startDrag(int? index) {
    if (!widget.session.state.isPlaying || index == null) return;
    setState(() {
      _dragStart = index;
      _dragCurrent = index;
      _justFound = null;
    });
  }

  void _extendDrag(int? index) {
    if (_dragStart == null || index == null || index == _dragCurrent) return;
    setState(() => _dragCurrent = index);
  }

  void _endDrag() {
    final from = _dragStart;
    final to = _dragCurrent;
    if (from == null || to == null) return;

    final match = _grid.wordForSelection(from, to);

    setState(() {
      _dragStart = null;
      _dragCurrent = null;
      if (match != null) {
        _grid = _grid.markFound(match.word);
        _justFound = match.word;
      }
    });

    // A wrong drag costs nothing but the time spent on it. Penalising misses
    // would push players toward not trying, which is the opposite of the game.
    if (match == null) return;

    widget.session.addScore(WordSearchGrid.pointsFor(match.word));

    if (_grid.isComplete) {
      widget.session.finish(GameOutcome.won);
    }
  }

  /// Cells in the drag currently under the finger, if it forms a legal line.
  Set<int> get _selection {
    final from = _dragStart;
    final to = _dragCurrent;
    if (from == null || to == null) return const {};
    return _grid.lineBetween(from, to)?.toSet() ?? const {};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = _selection;
    final found = _grid.foundCells;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: JpSpace.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = min(constraints.maxWidth, constraints.maxHeight);
                  return SizedBox(
                    width: side,
                    height: side,
                    child: GestureDetector(
                      key: wordSearchBoardKey,
                      // Pan rather than a drag recogniser: the selection runs in
                      // eight directions, so restricting to one axis would refuse
                      // the diagonals outright.
                      onPanStart: (d) => _startDrag(_cellAt(d.localPosition, side)),
                      onPanUpdate: (d) => _extendDrag(_cellAt(d.localPosition, side)),
                      onPanEnd: (_) => _endDrag(),
                      onPanCancel: _endDrag,
                      child: _Grid(
                        grid: _grid,
                        selection: selection,
                        found: found,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        _WordBank(
          pack: _pack,
          words: _grid.words,
          found: _grid.found,
          justFound: _justFound,
          style: theme.textTheme.labelLarge,
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.grid,
    required this.selection,
    required this.found,
  });

  final WordSearchGrid grid;
  final Set<int> selection;
  final Set<int> found;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: JpRadius.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(JpSpace.xs),
        child: Column(
          children: [
            for (var row = 0; row < grid.size; row++)
              Expanded(
                child: Row(
                  children: [
                    for (var column = 0; column < grid.size; column++)
                      Expanded(
                        child: _Letter(
                          key: wordSearchCellKey(row * grid.size + column),
                          letter: grid.letterAt(row, column),
                          selected: selection.contains(row * grid.size + column),
                          found: found.contains(row * grid.size + column),
                          scheme: scheme,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({
    required this.letter,
    required this.selected,
    required this.found,
    required this.scheme,
    super.key,
  });

  final String letter;
  final bool selected;
  final bool found;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    // Selection wins over found, so dragging across an already-solved word still
    // shows where the finger is.
    final background = selected
        ? scheme.primary
        : found
            ? scheme.tertiaryContainer
            : Colors.transparent;

    final foreground = selected
        ? scheme.onPrimary
        : found
            ? scheme.onTertiaryContainer
            : scheme.onSurface;

    return AnimatedContainer(
      duration: JpDuration.instant,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: JpRadius.xs,
      ),
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The list of words still to find.
///
/// Found words stay on the list, struck through, rather than disappearing.
/// Removing them would reflow the whole bank on every find and lose the sense of
/// progress that seeing the completed ones gives.
class _WordBank extends StatelessWidget {
  const _WordBank({
    required this.pack,
    required this.words,
    required this.found,
    required this.justFound,
    required this.style,
  });

  final WordPack pack;
  final List<PlacedWord> words;
  final Set<String> found;
  final String? justFound;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        JpSpace.lg,
        JpSpace.md,
        JpSpace.lg,
        JpSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pack.name.toUpperCase(),
            style: style?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: JpSpace.sm),
          Wrap(
            spacing: JpSpace.sm,
            runSpacing: JpSpace.sm,
            children: [
              for (final placed in words)
                _Chip(
                  key: wordSearchChipKey(placed.word),
                  word: placed.word,
                  found: found.contains(placed.word),
                  emphasised: placed.word == justFound,
                  style: style,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.word,
    required this.found,
    required this.emphasised,
    required this.style,
    super.key,
  });

  final String word;
  final bool found;
  final bool emphasised;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedScale(
      scale: emphasised ? 1.08 : 1.0,
      duration: JpDuration.quick,
      curve: JpCurve.pop,
      child: AnimatedContainer(
        duration: JpDuration.quick,
        padding: const EdgeInsets.symmetric(
          horizontal: JpSpace.sm,
          vertical: JpSpace.xs,
        ),
        decoration: BoxDecoration(
          color: found ? scheme.tertiaryContainer : scheme.surfaceContainerHighest,
          borderRadius: JpRadius.full,
        ),
        child: Text(
          word,
          style: style?.copyWith(
            color: found
                ? scheme.onTertiaryContainer.withValues(alpha: 0.6)
                : scheme.onSurface,
            decoration: found ? TextDecoration.lineThrough : null,
            decorationColor: scheme.onTertiaryContainer.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
