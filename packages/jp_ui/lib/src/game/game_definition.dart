import 'package:flutter/widgets.dart';

import 'game_session.dart';

/// What a game can do, so the shell knows which chrome to show.
class GameCapabilities {
  const GameCapabilities({
    this.showsScore = true,
    this.showsMoves = false,
    this.showsTimer = true,
    this.canPause = true,
    this.canRestart = true,
  });

  /// A puzzle with no score and no clock — just moves.
  static const GameCapabilities puzzle = GameCapabilities(
    showsScore: false,
    showsMoves: true,
    showsTimer: false,
  );

  /// A timed reaction game: the clock is the point, moves are noise.
  static const GameCapabilities timed = GameCapabilities(showsMoves: false);

  final bool showsScore;
  final bool showsMoves;
  final bool showsTimer;
  final bool canPause;
  final bool canRestart;
}

/// The contract every game implements.
///
/// **A new game writes rules and a board widget. Nothing else.** Pause, timing,
/// scoring display, the game-over sheet, statistics, ad placement and
/// save/restore all belong to the shell. If a game finds itself needing to touch
/// any of those directly, the shell has a gap and the shell gets fixed — adding
/// a bypass is how a platform stops being one.
///
/// Deliberately not a widget. A definition is cheap, const-constructible
/// metadata that the catalogue can list without building anything, which is what
/// lets a hub of twenty games render instantly.
abstract class GameDefinition {
  const GameDefinition();

  /// Stable identifier. Save keys, statistics and analytics all hang off this,
  /// so changing it on a shipped game orphans every player's history.
  String get id;

  /// Localization key for the display name — never a literal, or the game is
  /// untranslatable the moment a second language ships.
  String get nameKey;

  /// Short one-line description key, shown on the catalogue card.
  String get descriptionKey;

  GameCapabilities get capabilities => const GameCapabilities();

  /// Builds the playable surface.
  ///
  /// The board only. No app bar, no score display, no pause button — the shell
  /// draws all of that around whatever this returns, which is what keeps twenty
  /// games visually consistent without twenty implementations agreeing by luck.
  Widget buildBoard(BuildContext context, GameSession session);
}
