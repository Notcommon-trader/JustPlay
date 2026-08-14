import 'package:flutter/widgets.dart';
import 'package:jp_ui/jp_ui.dart';

import 'board_2048_view.dart';

/// 2048, in three sizes.
///
/// The whole definition is this file: an id, some metadata, and a board widget.
/// Everything else a player sees — the header, score, timer, pause, game over,
/// quit confirmation — comes from [GameShell]. That is the test of whether the
/// shell abstraction is doing its job.
class Game2048Definition extends GameDefinition {
  const Game2048Definition({this.boardSize = 4, this.seed});

  /// 4x4 is classic. 5x5 is noticeably easier, 3x3 is brutally hard — three
  /// distinct games from one implementation and one set of rules tests.
  final int boardSize;

  /// Fixes the spawn sequence, for daily challenges and for golden tests that
  /// need a board that looks the same on every run.
  final int? seed;

  @override
  String get id => boardSize == 4 ? 'game_2048' : 'game_2048_${boardSize}x$boardSize';

  @override
  String get nameKey => 'game.2048.name';

  @override
  String get descriptionKey => 'game.2048.description';

  @override
  GameCapabilities get capabilities => const GameCapabilities(
        showsScore: true,
        showsMoves: true,
        showsTimer: true,
      );

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return Board2048View(session: session, size: boardSize, seed: seed);
  }
}
