import 'package:flutter/widgets.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

import 'dots_and_boxes_view.dart';

/// Dots and boxes against the computer.
///
/// No timer: this is a thinking game played against an opponent, and a running
/// clock would push the player to move fast in a game that rewards moving well.
/// Moves and boxes-won are the honest measures.
class DotsAndBoxesDefinition extends GameDefinition {
  const DotsAndBoxesDefinition({
    this.rows = 4,
    this.columns = 4,
    this.level = DotsAiLevel.smart,
    this.seed,
  });

  final int rows;
  final int columns;
  final DotsAiLevel level;
  final int? seed;

  @override
  String get id => 'dots_and_boxes_${rows}x${columns}_${level.name}';

  @override
  String get nameKey => 'game.dots_and_boxes.name';

  @override
  String get descriptionKey => 'game.dots_and_boxes.description';

  @override
  GameCapabilities get capabilities => const GameCapabilities(
        showsScore: true,
        showsMoves: true,
        showsTimer: false,
      );

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return DotsAndBoxesView(
      session: session,
      rows: rows,
      columns: columns,
      level: level,
      seed: seed,
    );
  }
}
