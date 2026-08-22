import 'package:flutter/widgets.dart';
import 'package:jp_ui/jp_ui.dart';

import 'cascade_view.dart';

/// Match-three with chain reactions.
///
/// Score and moves, no timer. A cascade is a thing to watch, and a running clock
/// turns watching it into a cost.
class CascadeDefinition extends GameDefinition {
  const CascadeDefinition({
    this.columns = 7,
    this.rows = 8,
    this.sizeName = 'standard',
    this.seed,
  });

  /// A smaller board. Fewer columns means matches are closer together and
  /// chains fire more often — the gentler version is the *more* explosive one,
  /// which is the opposite of how difficulty usually works here.
  static const CascadeDefinition small = CascadeDefinition(
    columns: 6,
    rows: 7,
    sizeName: 'small',
  );

  final int columns;
  final int rows;
  final String sizeName;
  final int? seed;

  @override
  String get id => 'cascade_$sizeName';

  @override
  String get nameKey => 'game.cascade.name';

  @override
  String get descriptionKey => 'game.cascade.description';

  @override
  GameCapabilities get capabilities => const GameCapabilities(
        showsScore: true,
        showsMoves: true,
        showsTimer: false,
      );

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return CascadeView(
      session: session,
      columns: columns,
      rows: rows,
      seed: seed,
    );
  }
}
