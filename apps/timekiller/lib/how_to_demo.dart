import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jp_ui/jp_ui.dart';

/// One cell of a demo board at a given moment.
class DemoCell {
  const DemoCell(this.index, {this.fill, this.text, this.textColour});

  /// Position in the demo grid, row-major.
  final int index;

  /// Null leaves the cell in its resting state.
  final Color? fill;

  final String? text;
  final Color? textColour;
}

/// One keyframe: what the board looks like, and where the finger is.
///
/// The animation between frames is done for us — every cell is an implicitly
/// animated box, so a cell that changes colour between frames slides to the new
/// one, and a pointer that moves between frames travels there. That is what
/// makes a four-frame script read as a gesture rather than a slideshow.
class DemoFrame {
  const DemoFrame({
    this.cells = const [],
    this.pointer,
    this.duration = const Duration(milliseconds: 900),
  });

  final List<DemoCell> cells;

  /// Fractional position across the board, 0–1 on each axis. Null hides the
  /// finger, which is how a pause between gestures is expressed.
  final Offset? pointer;

  final Duration duration;
}

/// A looping demonstration of how a game is played.
class DemoScript {
  const DemoScript({
    required this.columns,
    required this.rows,
    required this.frames,
    this.caption,
  });

  final int columns;
  final int rows;
  final List<DemoFrame> frames;

  /// One short line under the animation. The picture does the work; this only
  /// names the gesture for anyone who wants it named.
  final String? caption;
}

/// Plays a [DemoScript] on a loop.
///
/// Text instructions get skipped — people look at a picture and try it. This
/// shows the actual gesture on a miniature of the actual board, so the thing a
/// player sees here is the thing they are about to do.
class HowToDemo extends StatefulWidget {
  const HowToDemo({required this.script, required this.accent, super.key});

  final DemoScript script;
  final Color accent;

  @override
  State<HowToDemo> createState() => _HowToDemoState();
}

class _HowToDemoState extends State<HowToDemo> {
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    // Without this the loop keeps firing after the sheet closes, against a
    // disposed State.
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    final frames = widget.script.frames;
    _timer = Timer(frames[_frame].duration, () {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % frames.length);
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final script = widget.script;
    final frame = script.frames[_frame];

    // Cells named in this frame; everything else rests.
    final byIndex = {for (final cell in frame.cells) cell.index: cell};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Capped, and centred within the cap.
        //
        // Without a ceiling the board is as tall as its aspect ratio demands at
        // whatever width it is given — fine on a phone, absurd on a tablet where
        // the sheet is wide, and an overflow in anything narrower still. A demo
        // is an illustration; it does not need to fill the screen.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190, maxWidth: 420),
            child: ClipRRect(
          borderRadius: JpRadius.md,
          child: Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(JpSpace.md),
            child: AspectRatio(
              aspectRatio: script.columns / script.rows,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / script.columns;
                  final cellHeight = constraints.maxHeight / script.rows;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        children: [
                          for (var r = 0; r < script.rows; r++)
                            Expanded(
                              child: Row(
                                children: [
                                  for (var c = 0; c < script.columns; c++)
                                    Expanded(
                                      child: _Cell(
                                        cell: byIndex[r * script.columns + c],
                                        scheme: scheme,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (frame.pointer != null)
                        AnimatedPositioned(
                          duration: frame.duration,
                          curve: JpCurve.standard,
                          left: frame.pointer!.dx * script.columns * cellWidth -
                              14,
                          top: frame.pointer!.dy * script.rows * cellHeight - 14,
                          child: _Finger(accent: widget.accent),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
            ),
          ),
        ),
        if (script.caption != null) ...[
          const SizedBox(height: JpSpace.sm),
          Text(
            script.caption!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell, required this.scheme});

  final DemoCell? cell;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: JpDuration.normal,
      curve: JpCurve.standard,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: cell?.fill ?? scheme.surface,
        borderRadius: JpRadius.xs,
      ),
      child: cell?.text == null
          ? null
          : Center(
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Text(
                    cell!.text!,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cell!.textColour ?? scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// The pointer. A ring rather than a filled dot, so it never hides the cell it
/// is pointing at — which would defeat the entire purpose.
class _Finger extends StatelessWidget {
  const _Finger({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.25),
          border: Border.all(color: accent, width: 2.5),
        ),
      ),
    );
  }
}
