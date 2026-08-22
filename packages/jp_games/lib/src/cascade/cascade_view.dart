import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// Key for the tile at [index].
ValueKey<String> cascadeTileKey(int index) => ValueKey('cascade-$index');

/// Match-three with visible cascades.
///
/// **The animation is the game.** The rules hand back every link of a chain as a
/// separate step precisely so this can play them one at a time — clear, pause,
/// drop, clear again. Jumping to the final board would turn a four-link cascade
/// into the same flat result as a lucky single match, and the unplanned payout
/// is the entire reason this game exists.
class CascadeView extends StatefulWidget {
  const CascadeView({
    required this.session,
    this.columns = 7,
    this.rows = 8,
    this.seed,
    super.key,
  });

  final GameSession session;
  final int columns;
  final int rows;
  final int? seed;

  @override
  State<CascadeView> createState() => _CascadeViewState();
}

class _CascadeViewState extends State<CascadeView> {
  late Random _random = _newRandom();
  late CascadeBoard _board = _deal();

  /// Cells lit up in the current step, and the chain number driving the banner.
  Set<int> _clearing = const {};
  int _chain = 0;

  int? _selected;

  /// True while a cascade is playing. Input is refused throughout: a swap made
  /// mid-chain would race the animation and land on a board that no longer
  /// exists.
  bool _busy = false;

  Timer? _timer;

  Random _newRandom() => widget.seed != null ? Random(widget.seed) : Random();

  CascadeBoard _deal() => CascadeBoard.deal(
        columns: widget.columns,
        rows: widget.rows,
        random: _random,
      );

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (widget.session.state.status == GameStatus.ready) {
      _timer?.cancel();
      setState(() {
        _random = _newRandom();
        _board = _deal();
        _selected = null;
        _clearing = const {};
        _chain = 0;
        _busy = false;
      });
      widget.session.start();
    }
  }

  void _tap(int index) {
    if (_busy || !widget.session.state.isPlaying) return;

    final selected = _selected;
    if (selected == null) {
      setState(() => _selected = index);
      return;
    }

    if (selected == index) {
      setState(() => _selected = null);
      return;
    }

    if (!_board.areAdjacent(selected, index)) {
      // Treat a far tap as picking a new tile rather than as an error. The
      // player is choosing, not failing.
      setState(() => _selected = index);
      return;
    }

    setState(() => _selected = null);
    _play(_board.swap(selected, index));
  }

  void _play(CascadeResult result) {
    if (!result.isLegal) {
      widget.session.addScore(0);
      return;
    }

    setState(() => _busy = true);
    _runStep(result, 0);
  }

  /// Walks the chain, one link every [_stepDuration].
  static const Duration _stepDuration = Duration(milliseconds: 340);

  void _runStep(CascadeResult result, int stepIndex) {
    if (!mounted) return;

    if (stepIndex >= result.steps.length) {
      _finishCascade(result);
      return;
    }

    final step = result.steps[stepIndex];

    // Show the matched tiles lit, on the board as it was before they went.
    setState(() {
      _board = step.board;
      _clearing = step.cleared;
      _chain = step.chain;
    });

    // Score lands per link rather than in a lump, so the number climbs while the
    // chain plays and the reward is spread across the whole animation.
    widget.session.addScore(step.scoreGained);

    _timer = Timer(_stepDuration, () {
      if (!mounted) return;
      setState(() => _clearing = const {});
      _runStep(result, stepIndex + 1);
    });
  }

  void _finishCascade(CascadeResult result) {
    var board = result.board;

    // A board with no move left is a dead end. Reshuffling is quieter and
    // fairer than ending the game on it.
    if (!board.hasMove) board = board.shuffled(_random);

    setState(() {
      _board = board;
      _clearing = const {};
      _chain = 0;
      _busy = false;
    });

    widget.session.recordMove();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChainBanner(chain: _chain),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(JpSpace.md),
              child: AspectRatio(
                aspectRatio: widget.columns / widget.rows,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        for (var row = 0; row < widget.rows; row++)
                          Expanded(
                            child: Row(
                              children: [
                                for (var column = 0;
                                    column < widget.columns;
                                    column++)
                                  Expanded(
                                    child: _Tile(
                                      key: cascadeTileKey(
                                        _board.indexOf(row, column),
                                      ),
                                      colour: _board.tileAt(row, column),
                                      selected: _selected ==
                                          _board.indexOf(row, column),
                                      clearing: _clearing.contains(
                                        _board.indexOf(row, column),
                                      ),
                                      onTap: () =>
                                          _tap(_board.indexOf(row, column)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Announces the chain while it is running.
///
/// Only from the second link. Calling a single ordinary match "Chain 1" would
/// spend the celebration on the thing that happens every turn, and leave nothing
/// to escalate to.
class _ChainBanner extends StatelessWidget {
  const _ChainBanner({required this.chain});

  final int chain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showing = chain >= 2;

    return SizedBox(
      height: 44,
      child: Center(
        child: AnimatedScale(
          scale: showing ? 1 : 0.6,
          duration: JpDuration.quick,
          curve: JpCurve.pop,
          child: AnimatedOpacity(
            opacity: showing ? 1 : 0,
            duration: JpDuration.quick,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: JpSpace.lg,
                vertical: JpSpace.xs,
              ),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: JpRadius.full,
              ),
              child: Text(
                chain >= 4 ? 'Chain ×$chain!' : 'Chain ×$chain',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: JpTextSize.body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.colour,
    required this.selected,
    required this.clearing,
    required this.onTap,
    super.key,
  });

  final int colour;
  final bool selected;

  /// Part of the run currently being cleared.
  final bool clearing;

  final VoidCallback onTap;

  /// Fixed hues rather than theme colours.
  ///
  /// A match-three needs its colours to be instantly and unmistakably distinct;
  /// a generated palette produces harmonious neighbours, which is exactly wrong
  /// when telling two tiles apart at a glance is the entire skill of the game.
  static const List<Color> _palette = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFDD835),
    Color(0xFF8E24AA),
    Color(0xFFFF7043),
  ];

  @override
  Widget build(BuildContext context) {
    final fill = colour >= 0 && colour < _palette.length
        ? _palette[colour]
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        // Clearing tiles shrink away rather than blinking out. Watching them go
        // is what makes the chain legible.
        scale: clearing ? 0.2 : (selected ? 1.12 : 1),
        duration: JpDuration.quick,
        curve: clearing ? JpCurve.exit : JpCurve.pop,
        child: AnimatedOpacity(
          opacity: clearing ? 0 : 1,
          duration: JpDuration.quick,
          child: Container(
            margin: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: JpRadius.sm,
              border: selected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: JpElevation.low(Colors.black),
            ),
          ),
        ),
      ),
    );
  }
}
