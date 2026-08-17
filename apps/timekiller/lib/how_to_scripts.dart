import 'package:flutter/material.dart';

import 'how_to_demo.dart';

/// Animated demonstrations, one per game.
///
/// Every script is the same shape: a few keyframes showing a finger doing the
/// one gesture that game is built on, with the board changing underneath it.
/// The engine tweens between frames, so three or four frames read as a
/// continuous move.
///
/// **Kept deliberately short.** A demo that teaches the whole game is a video
/// nobody watches. Each of these answers one question — "what do I actually do
/// with my thumb?" — and leaves the rules to the two lines of text beside it.
///
/// Colours come from the scheme at build time rather than being baked in here,
/// so a demo inherits its game's accent like everything else.
class HowToScripts {
  const HowToScripts._();

  /// Sudoku: choose a square, then choose a number.
  static DemoScript sudoku(ColorScheme scheme) {
    final selected = scheme.primaryContainer;
    final ink = scheme.primary;

    return DemoScript(
      columns: 4,
      rows: 3,
      caption: 'Tap a square, then tap a number.',
      frames: [
        const DemoFrame(
          cells: [
            DemoCell(0, text: '5'),
            DemoCell(2, text: '1'),
            DemoCell(7, text: '9'),
            DemoCell(9, text: '3'),
          ],
          pointer: Offset(0.38, 0.5),
        ),
        DemoFrame(
          cells: [
            const DemoCell(0, text: '5'),
            const DemoCell(2, text: '1'),
            DemoCell(5, fill: selected),
            const DemoCell(7, text: '9'),
            const DemoCell(9, text: '3'),
          ],
          pointer: const Offset(0.38, 0.5),
        ),
        DemoFrame(
          cells: [
            const DemoCell(0, text: '5'),
            const DemoCell(2, text: '1'),
            DemoCell(5, fill: selected, text: '7', textColour: ink),
            const DemoCell(7, text: '9'),
            const DemoCell(9, text: '3'),
          ],
          pointer: const Offset(0.38, 0.5),
          duration: const Duration(milliseconds: 1100),
        ),
      ],
    );
  }

  /// 2048: swipe, and two matching tiles become one.
  static DemoScript game2048(ColorScheme scheme) {
    final low = scheme.secondaryContainer;
    final high = scheme.primary;
    final onHigh = scheme.onPrimary;
    final onLow = scheme.onSecondaryContainer;

    return DemoScript(
      columns: 4,
      rows: 2,
      caption: 'Swipe. Matching tiles merge and double.',
      frames: [
        DemoFrame(
          cells: [
            DemoCell(1, fill: low, text: '2', textColour: onLow),
            DemoCell(3, fill: low, text: '2', textColour: onLow),
          ],
          pointer: const Offset(0.85, 0.25),
        ),
        DemoFrame(
          cells: [
            DemoCell(0, fill: low, text: '2', textColour: onLow),
            DemoCell(1, fill: low, text: '2', textColour: onLow),
          ],
          pointer: const Offset(0.1, 0.25),
        ),
        DemoFrame(
          cells: [
            DemoCell(0, fill: high, text: '4', textColour: onHigh),
          ],
          duration: const Duration(milliseconds: 1100),
        ),
      ],
    );
  }

  /// Minesweeper: tap opens, and a number counts the mines around it.
  static DemoScript minesweeper(ColorScheme scheme) {
    final hidden = Color.lerp(scheme.surfaceContainerHighest, scheme.primary, 0.22)!;
    final open = scheme.surfaceContainerHighest;

    List<DemoCell> allHidden({Map<int, DemoCell> except = const {}}) => [
          for (var i = 0; i < 12; i++) except[i] ?? DemoCell(i, fill: hidden),
        ];

    return DemoScript(
      columns: 4,
      rows: 3,
      caption: 'Tap to open. The number counts nearby mines.',
      frames: [
        DemoFrame(cells: allHidden(), pointer: const Offset(0.38, 0.5)),
        DemoFrame(
          cells: allHidden(
            except: {
              5: DemoCell(5, fill: open, text: '2', textColour: scheme.primary),
            },
          ),
          pointer: const Offset(0.38, 0.5),
        ),
        DemoFrame(
          cells: allHidden(
            except: {
              5: DemoCell(5, fill: open, text: '2', textColour: scheme.primary),
              6: DemoCell(6, fill: open, text: '1', textColour: scheme.primary),
              9: DemoCell(9, fill: scheme.errorContainer, text: '⚑',
                  textColour: scheme.error),
            },
          ),
          duration: const Duration(milliseconds: 1200),
        ),
      ],
    );
  }

  /// Word search: drag from the first letter to the last.
  static DemoScript wordSearch(ColorScheme scheme) {
    final found = scheme.primary;
    final onFound = scheme.onPrimary;

    const letters = ['C', 'A', 'T', 'X', 'Q', 'R', 'M', 'B'];
    List<DemoCell> base({Set<int> lit = const {}}) => [
          for (var i = 0; i < letters.length; i++)
            DemoCell(
              i,
              fill: lit.contains(i) ? found : null,
              text: letters[i],
              textColour: lit.contains(i) ? onFound : null,
            ),
        ];

    return DemoScript(
      columns: 4,
      rows: 2,
      caption: 'Drag from the first letter to the last.',
      frames: [
        DemoFrame(cells: base(), pointer: const Offset(0.125, 0.25)),
        DemoFrame(cells: base(lit: {0, 1}), pointer: const Offset(0.375, 0.25)),
        DemoFrame(
          cells: base(lit: {0, 1, 2}),
          pointer: const Offset(0.625, 0.25),
          duration: const Duration(milliseconds: 1100),
        ),
      ],
    );
  }

  /// Nonogram: the numbers say how many to fill.
  static DemoScript nonogram(ColorScheme scheme) {
    final filled = scheme.primary;
    final marked = scheme.surfaceContainerHighest;

    return DemoScript(
      columns: 4,
      rows: 2,
      caption: '"3" means three in a row. Tap to fill.',
      frames: [
        DemoFrame(
          cells: [
            DemoCell(0, text: '3', textColour: scheme.onSurfaceVariant),
          ],
          pointer: const Offset(0.375, 0.25),
        ),
        DemoFrame(
          cells: [
            DemoCell(0, text: '3', textColour: scheme.onSurfaceVariant),
            DemoCell(1, fill: filled),
            DemoCell(2, fill: filled),
          ],
          pointer: const Offset(0.875, 0.25),
        ),
        DemoFrame(
          cells: [
            DemoCell(0, text: '3', textColour: scheme.onSurfaceVariant),
            DemoCell(1, fill: filled),
            DemoCell(2, fill: filled),
            DemoCell(3, fill: filled),
            DemoCell(5, fill: marked, text: '×',
                textColour: scheme.onSurfaceVariant),
          ],
          duration: const Duration(milliseconds: 1200),
        ),
      ],
    );
  }

  /// Memory: turn two, keep them if they match.
  static DemoScript memory(ColorScheme scheme) {
    final back = scheme.primary;
    final face = scheme.tertiaryContainer;
    final onFace = scheme.onTertiaryContainer;

    List<DemoCell> cards({Map<int, DemoCell> faceUp = const {}}) => [
          for (var i = 0; i < 6; i++) faceUp[i] ?? DemoCell(i, fill: back),
        ];

    return DemoScript(
      columns: 3,
      rows: 2,
      caption: 'Turn two. A pair stays up.',
      frames: [
        DemoFrame(cells: cards(), pointer: const Offset(0.17, 0.25)),
        DemoFrame(
          cells: cards(faceUp: {0: DemoCell(0, fill: face, text: '★', textColour: onFace)}),
          pointer: const Offset(0.83, 0.75),
        ),
        DemoFrame(
          cells: cards(
            faceUp: {
              0: DemoCell(0, fill: face, text: '★', textColour: onFace),
              5: DemoCell(5, fill: face, text: '★', textColour: onFace),
            },
          ),
          duration: const Duration(milliseconds: 1200),
        ),
      ],
    );
  }

  /// Sliding puzzle: tap a tile beside the gap.
  static DemoScript slidingPuzzle(ColorScheme scheme) {
    final tile = scheme.primaryContainer;
    final ink = scheme.onPrimaryContainer;

    DemoCell numbered(int index, String text) =>
        DemoCell(index, fill: tile, text: text, textColour: ink);

    return DemoScript(
      columns: 3,
      rows: 2,
      caption: 'Tap a tile next to the gap.',
      frames: [
        DemoFrame(
          cells: [
            numbered(0, '1'),
            numbered(1, '2'),
            numbered(3, '4'),
            numbered(4, '5'),
            numbered(5, '3'),
          ],
          pointer: const Offset(0.83, 0.75),
        ),
        DemoFrame(
          cells: [
            numbered(0, '1'),
            numbered(1, '2'),
            numbered(2, '3'),
            numbered(3, '4'),
            numbered(4, '5'),
          ],
          pointer: const Offset(0.83, 0.25),
          duration: const Duration(milliseconds: 1200),
        ),
      ],
    );
  }

  /// Solitaire: drag a card onto the next rank up, in the other colour.
  static DemoScript solitaire(ColorScheme scheme) {
    const red = Color(0xFFC62828);
    const black = Color(0xFF1A1A1A);
    const cardFace = Color(0xFFFAFAFA);

    return const DemoScript(
      columns: 4,
      rows: 2,
      caption: 'Drag onto the next number up, in the other colour.',
      frames: [
        DemoFrame(
          cells: [
            DemoCell(1, fill: cardFace, text: '8♠', textColour: black),
            DemoCell(6, fill: cardFace, text: '7♦', textColour: red),
          ],
          pointer: Offset(0.625, 0.75),
        ),
        DemoFrame(
          cells: [
            DemoCell(1, fill: cardFace, text: '8♠', textColour: black),
            DemoCell(5, fill: cardFace, text: '7♦', textColour: red),
          ],
          pointer: Offset(0.375, 0.75),
        ),
        DemoFrame(
          cells: [
            DemoCell(1, fill: cardFace, text: '8♠', textColour: black),
            DemoCell(5, fill: cardFace, text: '7♦', textColour: red),
          ],
          duration: Duration(milliseconds: 1100),
        ),
      ],
    );
  }

  /// Dots and boxes: the fourth side claims the box.
  static DemoScript dotsAndBoxes(ColorScheme scheme) {
    final line = scheme.primary;
    final claimed = scheme.primaryContainer;

    return DemoScript(
      columns: 3,
      rows: 3,
      caption: 'Draw the fourth side to claim a box.',
      frames: [
        DemoFrame(
          cells: [
            DemoCell(1, fill: line),
            DemoCell(3, fill: line),
            DemoCell(5, fill: line),
          ],
          pointer: const Offset(0.5, 0.83),
        ),
        DemoFrame(
          cells: [
            DemoCell(1, fill: line),
            DemoCell(3, fill: line),
            DemoCell(5, fill: line),
            DemoCell(7, fill: line),
          ],
          pointer: const Offset(0.5, 0.83),
        ),
        DemoFrame(
          cells: [
            DemoCell(1, fill: line),
            DemoCell(3, fill: line),
            DemoCell(4, fill: claimed, text: '★', textColour: line),
            DemoCell(5, fill: line),
            DemoCell(7, fill: line),
          ],
          duration: const Duration(milliseconds: 1200),
        ),
      ],
    );
  }

  /// Reaction: wait for green, then tap.
  static DemoScript reaction(ColorScheme scheme) {
    const waiting = Color(0xFF8D6E63);
    const go = Color(0xFF2E7D32);

    return const DemoScript(
      columns: 2,
      rows: 1,
      caption: 'Wait… then tap the moment it turns green.',
      frames: [
        DemoFrame(
          cells: [DemoCell(0, fill: waiting), DemoCell(1, fill: waiting)],
          duration: Duration(milliseconds: 1100),
        ),
        DemoFrame(
          cells: [DemoCell(0, fill: go), DemoCell(1, fill: go)],
          pointer: Offset(0.5, 0.5),
          duration: Duration(milliseconds: 700),
        ),
        DemoFrame(
          cells: [
            DemoCell(0, fill: go, text: '182', textColour: Colors.white),
            DemoCell(1, fill: go),
          ],
          duration: Duration(milliseconds: 1100),
        ),
      ],
    );
  }
}
