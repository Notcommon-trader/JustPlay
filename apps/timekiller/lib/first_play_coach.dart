import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jp_ui/jp_ui.dart';

/// One gesture to demonstrate, in fractions of the board.
///
/// Fractions rather than pixels because the same hint has to sit correctly on a
/// 5×5 nonogram and a 9×9 sudoku, on any screen.
class CoachMove {
  const CoachMove({
    required this.from,
    required this.text,
    this.to,
  });

  /// Where the finger starts, 0–1 across the board.
  final Offset from;

  /// Where it ends. Null means a tap rather than a drag.
  final Offset? to;

  /// What the gesture achieves, in a handful of words. The finger says *how*;
  /// this only says *why*.
  final String text;

  bool get isDrag => to != null;
}

/// Shows the real gesture on the real board, the first time a game is opened.
///
/// This replaces a looping diagram that sat in the game sheet. The diagram was a
/// miniature of a board, on a different screen, before play started — so it was
/// something to watch rather than something to do, and it got skipped. Pointing
/// at the actual board a player is about to touch is the difference between a
/// demonstration and an instruction.
///
/// It removes itself the moment the player touches anything. Someone who already
/// knows the game should never have to dismiss a tutorial.
class FirstPlayCoach extends StatefulWidget {
  const FirstPlayCoach({
    required this.moves,
    required this.accent,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final List<CoachMove> moves;
  final Color accent;
  final Widget child;

  /// False once the game has been played before.
  final bool enabled;

  @override
  State<FirstPlayCoach> createState() => _FirstPlayCoachState();
}

class _FirstPlayCoachState extends State<FirstPlayCoach> {
  late bool _showing = widget.enabled && widget.moves.isNotEmpty;
  int _index = 0;
  bool _atEnd = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_showing) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Each move plays as: appear at the start point, travel to the end, pause.
  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _atEnd = true);

      _timer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        setState(() {
          _atEnd = false;
          _index = (_index + 1) % widget.moves.length;
        });
        _schedule();
      });
    });
  }

  void _dismiss() {
    if (!_showing) return;
    _timer?.cancel();
    setState(() => _showing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_showing) return widget.child;

    final move = widget.moves[_index];
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(child: widget.child),

        // Listener, not GestureDetector, and non-blocking: the player's first
        // touch reaches the board *and* clears the coach. Swallowing that touch
        // would mean the tutorial costs a move, which is exactly the kind of
        // small insult that makes people close an app.
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _dismiss(),
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final target = _atEnd && move.isDrag ? move.to! : move.from;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 900),
                        curve: JpCurve.standard,
                        left: target.dx * constraints.maxWidth - 22,
                        top: target.dy * constraints.maxHeight - 22,
                        child: _Finger(accent: widget.accent),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: JpSpace.lg,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: JpSpace.lg,
                              vertical: JpSpace.md,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.inverseSurface,
                              borderRadius: JpRadius.full,
                            ),
                            child: Text(
                              move.text,
                              style: TextStyle(
                                color: scheme.onInverseSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The pointer: a ring, so the cell it is pointing at stays visible.
class _Finger extends StatelessWidget {
  const _Finger({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.22),
        border: Border.all(color: accent, width: 3),
      ),
    );
  }
}
