import 'package:flutter/widgets.dart';
import 'package:jp_ui/jp_ui.dart';

import 'reaction_view.dart';

/// Tap the moment the screen turns green.
///
/// Shows score and moves but **not** the timer. That looks backwards for a game
/// about speed, and is deliberate: the shell's clock measures how long the
/// session has been open, which here is mostly the randomised waiting between
/// rounds. Surfacing it would imply the player is being timed on something they
/// cannot influence. The reaction times that matter are shown on the board
/// itself, where they mean something.
class ReactionDefinition extends GameDefinition {
  const ReactionDefinition({this.rounds = 5, this.seed});

  final int rounds;
  final int? seed;

  @override
  String get id => 'reaction_$rounds';

  @override
  String get nameKey => 'game.reaction.name';

  @override
  String get descriptionKey => 'game.reaction.description';

  @override
  GameCapabilities get capabilities => const GameCapabilities(
        showsScore: true,
        showsMoves: true,
        showsTimer: false,
      );

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return ReactionView(session: session, rounds: rounds, seed: seed);
  }
}
