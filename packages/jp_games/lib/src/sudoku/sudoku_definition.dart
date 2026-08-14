import 'package:flutter/widgets.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

import 'sudoku_view.dart';

/// Sudoku, in three difficulties.
///
/// Time and moves, no score. Sudoku's only real measure is how long it took, and
/// a points system would have to invent a value for a hint — which is exactly
/// the kind of number players stop trusting.
class SudokuDefinition extends GameDefinition {
  const SudokuDefinition({
    this.difficulty = SudokuDifficulty.medium,
    this.seed,
  });

  final SudokuDifficulty difficulty;
  final int? seed;

  @override
  String get id => 'sudoku_${difficulty.name}';

  @override
  String get nameKey => 'game.sudoku.name';

  @override
  String get descriptionKey => 'game.sudoku.description';

  @override
  GameCapabilities get capabilities => const GameCapabilities(
        showsScore: false,
        showsMoves: true,
        showsTimer: true,
      );

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return SudokuView(
      session: session,
      difficulty: difficulty,
      seed: seed,
    );
  }
}
