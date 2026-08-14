import 'package:flutter/widgets.dart';
import 'package:jp_ui/jp_ui.dart';

import 'minesweeper_view.dart';

/// Minesweeper, in the three classic difficulties.
///
/// No score: minesweeper has never had one, and inventing a points system for a
/// game whose whole culture is "clear it, fast" would be noise. Time and moves
/// are the real measures, so those are what the shell shows.
class MinesweeperDefinition extends GameDefinition {
  const MinesweeperDefinition({
    this.columns = 9,
    this.rows = 9,
    this.mineCount = 10,
    this.difficultyName = 'beginner',
    this.seed,
  });

  /// Standard difficulties. Grid sizes and mine counts are the ones the original
  /// used, because players calibrate against them.
  static const MinesweeperDefinition beginner = MinesweeperDefinition();

  static const MinesweeperDefinition intermediate = MinesweeperDefinition(
    columns: 12,
    rows: 12,
    mineCount: 25,
    difficultyName: 'intermediate',
  );

  final int columns;
  final int rows;
  final int mineCount;
  final String difficultyName;
  final int? seed;

  @override
  String get id => 'minesweeper_$difficultyName';

  @override
  String get nameKey => 'game.minesweeper.name';

  @override
  String get descriptionKey => 'game.minesweeper.description';

  @override
  GameCapabilities get capabilities => const GameCapabilities(
        showsScore: false,
        showsMoves: true,
        showsTimer: true,
      );

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return MinesweeperView(
      session: session,
      columns: columns,
      rows: rows,
      mineCount: mineCount,
      seed: seed,
    );
  }
}
