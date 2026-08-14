import 'package:flutter/widgets.dart';
import 'package:jp_ui/jp_ui.dart';

import 'sliding_puzzle_view.dart';

/// The 15-puzzle, at any square size.
///
/// Declares [GameCapabilities.puzzle]: no score, no clock, moves only. A sliding
/// puzzle has no scoring dimension — fewer moves is the whole objective — and a
/// running timer would add pressure the game was never designed around.
///
/// That single line is the shell abstraction paying off: the same shell that
/// renders a score and a clock for 2048 renders neither here, without either
/// game knowing the other exists.
class SlidingPuzzleDefinition extends GameDefinition {
  const SlidingPuzzleDefinition({this.boardSize = 4, this.seed});

  final int boardSize;
  final int? seed;

  @override
  String get id => 'sliding_puzzle_${boardSize}x$boardSize';

  @override
  String get nameKey => 'game.sliding_puzzle.name';

  @override
  String get descriptionKey => 'game.sliding_puzzle.description';

  @override
  GameCapabilities get capabilities => GameCapabilities.puzzle;

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return SlidingPuzzleView(session: session, size: boardSize, seed: seed);
  }
}
