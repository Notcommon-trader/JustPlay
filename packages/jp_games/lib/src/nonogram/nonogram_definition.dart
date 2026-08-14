import 'package:flutter/widgets.dart';
import 'package:jp_ui/jp_ui.dart';

import 'nonogram_view.dart';

/// Nonogram (picross).
///
/// Moves and time, no score. Picross has no natural points system, and the
/// number a player actually cares about is how long a grid took them.
class NonogramDefinition extends GameDefinition {
  const NonogramDefinition({
    this.columns = 10,
    this.rows = 10,
    this.sizeName = 'ten',
    this.seed,
  });

  /// A five-by-five grid. Short enough to finish in a couple of minutes, which
  /// is what makes it the right first puzzle for someone who has never seen the
  /// rules.
  static const NonogramDefinition small = NonogramDefinition(
    columns: 5,
    rows: 5,
    sizeName: 'five',
  );

  final int columns;
  final int rows;
  final String sizeName;
  final int? seed;

  @override
  String get id => 'nonogram_$sizeName';

  @override
  String get nameKey => 'game.nonogram.name';

  @override
  String get descriptionKey => 'game.nonogram.description';

  @override
  GameCapabilities get capabilities => const GameCapabilities(
        showsScore: false,
        showsMoves: true,
        showsTimer: true,
      );

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return NonogramView(
      session: session,
      columns: columns,
      rows: rows,
      seed: seed,
    );
  }
}
