import 'package:flutter/widgets.dart';

import 'first_play_coach.dart';

/// Where the first-play coach points, per game.
///
/// Positions are fractions of the board area, so one set of numbers works on
/// every screen and every board size. They aim at the *kind* of place a move
/// happens — the middle of a grid, the deck, the number pad — rather than at a
/// specific cell, because the board is randomly generated and a hint that points
/// at "the 7" would be pointing at nothing half the time.
///
/// These replaced a looping animation shown in the game sheet. That played on a
/// different screen, before the game started, on a miniature of a board — so it
/// was something to watch rather than something to do. Pointing at the board the
/// player is about to touch is the whole difference.
abstract final class CoachMoves {
  static const List<CoachMove> sudoku = [
    CoachMove(from: Offset(0.5, 0.42), text: 'Tap a square'),
    CoachMove(from: Offset(0.28, 0.93), text: 'Then tap a number'),
  ];

  static const List<CoachMove> solitaire = [
    CoachMove(from: Offset(0.09, 0.12), text: 'Tap the deck for a card'),
    CoachMove(
      from: Offset(0.22, 0.45),
      to: Offset(0.62, 0.5),
      text: 'Drag cards onto a higher card of the other colour',
    ),
    CoachMove(from: Offset(0.5, 0.5), text: 'Or tap a card to send it home'),
  ];

  static const List<CoachMove> game2048 = [
    CoachMove(
      from: Offset(0.25, 0.5),
      to: Offset(0.75, 0.5),
      text: 'Swipe to slide every tile',
    ),
    CoachMove(
      from: Offset(0.5, 0.7),
      to: Offset(0.5, 0.3),
      text: 'Matching tiles merge and double',
    ),
  ];

  static const List<CoachMove> minesweeper = [
    CoachMove(from: Offset(0.5, 0.5), text: 'Tap to open — the first is safe'),
    CoachMove(from: Offset(0.3, 0.35), text: 'Hold to flag a mine'),
  ];

  static const List<CoachMove> wordSearch = [
    CoachMove(
      from: Offset(0.2, 0.35),
      to: Offset(0.7, 0.35),
      text: 'Drag across a word — any direction',
    ),
    CoachMove(from: Offset(0.5, 0.88), text: 'The words to find are listed here'),
  ];

  static const List<CoachMove> nonogram = [
    CoachMove(from: Offset(0.6, 0.55), text: 'Tap to fill a square'),
    CoachMove(from: Offset(0.6, 0.55), text: 'Tap again to rule it out'),
    CoachMove(
      from: Offset(0.15, 0.55),
      text: 'The numbers say how many in a row',
    ),
  ];

  static const List<CoachMove> memory = [
    CoachMove(from: Offset(0.25, 0.3), text: 'Turn over a card'),
    CoachMove(from: Offset(0.7, 0.6), text: 'Then find its pair'),
  ];

  static const List<CoachMove> slidingPuzzle = [
    CoachMove(
      from: Offset(0.35, 0.5),
      text: 'Tap a tile beside the gap and it slides',
    ),
  ];

  static const List<CoachMove> dotsAndBoxes = [
    CoachMove(from: Offset(0.4, 0.35), text: 'Tap a line between two dots'),
    CoachMove(from: Offset(0.55, 0.5), text: 'Close a box and you go again'),
  ];

  static const List<CoachMove> reaction = [
    CoachMove(from: Offset(0.5, 0.45), text: 'Tap to start, then wait'),
    CoachMove(from: Offset(0.5, 0.45), text: 'Tap the moment it turns green'),
  ];
}
