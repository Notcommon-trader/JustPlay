import 'package:flutter/widgets.dart';
import 'package:jp_ui/jp_ui.dart';

import 'solitaire_view.dart';

/// Klondike solitaire.
///
/// Score, moves and time all shown: solitaire is the one game here with a real
/// scoring tradition, and players who care about it care about all three.
class SolitaireDefinition extends GameDefinition {
  const SolitaireDefinition({this.drawCount = 1, this.seed});

  /// The traditional three-card draw. Much harder, and the version most
  /// long-time players mean when they say "solitaire".
  static const SolitaireDefinition drawThree = SolitaireDefinition(drawCount: 3);

  final int drawCount;
  final int? seed;

  @override
  String get id => 'solitaire_draw$drawCount';

  @override
  String get nameKey => 'game.solitaire.name';

  @override
  String get descriptionKey => 'game.solitaire.description';

  @override
  GameCapabilities get capabilities => const GameCapabilities(
        showsScore: true,
        showsMoves: true,
        showsTimer: true,
      );

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return SolitaireView(
      session: session,
      drawCount: drawCount,
      seed: seed,
    );
  }
}
