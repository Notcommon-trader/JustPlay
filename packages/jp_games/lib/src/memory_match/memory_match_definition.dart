import 'package:flutter/widgets.dart';
import 'package:jp_ui/jp_ui.dart';

import 'memory_match_view.dart';

/// Memory match: find every pair.
///
/// Declares score, moves *and* timer — the first game in the catalogue to use
/// all three. Speed genuinely matters here in a way it does not for a sliding
/// puzzle, and pairs found is a real score rather than a proxy for moves.
class MemoryMatchDefinition extends GameDefinition {
  const MemoryMatchDefinition({this.pairs = 8, this.columns = 4, this.seed});

  final int pairs;
  final int columns;
  final int? seed;

  @override
  String get id => 'memory_match_$pairs';

  @override
  String get nameKey => 'game.memory_match.name';

  @override
  String get descriptionKey => 'game.memory_match.description';

  @override
  GameCapabilities get capabilities => const GameCapabilities(
        showsScore: true,
        showsMoves: true,
        showsTimer: true,
      );

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return MemoryMatchView(
      session: session,
      pairs: pairs,
      columns: columns,
      seed: seed,
    );
  }
}
