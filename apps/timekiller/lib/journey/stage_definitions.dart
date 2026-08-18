import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

/// Turns an abstract [Stage] into a board.
///
/// The ladder lives in `jp_core` and deliberately knows nothing about
/// `GameDefinition`, so the pacing stays testable without a widget tree. This is
/// the one place the two meet, and it is the only file that has to change when a
/// game's difficulty knobs change.
///
/// Every stage gets a **fresh seed derived from its number and attempt count**,
/// so a retry is a genuinely new board rather than the one you just failed.
/// Replaying the same losing position is the fastest way to end a session.
GameDefinition definitionFor(Stage stage, {int attempt = 0}) {
  final seed = Object.hash(stage.number, attempt) & 0x7fffffff;
  final d = stage.difficulty;

  return switch (stage.game) {
    StageGame.game2048 => Game2048Definition(
        // Smaller boards are harder, not easier: less room to manoeuvre. So the
        // curve runs the other way here than everywhere else.
        boardSize: d <= 1 ? 5 : (d <= 4 ? 4 : 3),
        seed: seed,
      ),
    StageGame.slidingPuzzle => SlidingPuzzleDefinition(
        boardSize: d <= 2 ? 3 : 4,
        seed: seed,
      ),
    StageGame.memoryMatch => MemoryMatchDefinition(
        pairs: d <= 1 ? 6 : 8,
        columns: d <= 1 ? 3 : 4,
        seed: seed,
      ),
    StageGame.wordSearch => WordSearchDefinition(
        size: d <= 3 ? 10 : 12,
        wordCount: 6 + d,
        seed: seed,
      ),
    StageGame.nonogram => NonogramDefinition(
        columns: d <= 2 ? 5 : 10,
        rows: d <= 2 ? 5 : 10,
        sizeName: d <= 2 ? 'five' : 'ten',
        seed: seed,
      ),
    StageGame.minesweeper => MinesweeperDefinition(
        columns: 9,
        rows: 9,
        mineCount: 8 + d * 2,
        difficultyName: 'stage',
        seed: seed,
      ),
    StageGame.reaction => ReactionDefinition(rounds: 5, seed: seed),
    StageGame.dotsAndBoxes => DotsAndBoxesDefinition(
        rows: d <= 3 ? 3 : 4,
        columns: d <= 3 ? 3 : 4,
        level: d <= 2 ? DotsAiLevel.easy : DotsAiLevel.smart,
        seed: seed,
      ),
    StageGame.solitaire => SolitaireDefinition(
        drawCount: d <= 4 ? 1 : 3,
        seed: seed,
      ),
  };
}

/// The colour a stage wears, matching the game's identity in the catalogue.
///
/// Duplicated from the catalogue rather than looked up through it: the Journey
/// must not depend on which games the *catalogue* happens to list, or removing a
/// game from the home grid would silently break the ladder.
int stageColourValue(StageGame game) => switch (game) {
      StageGame.game2048 => 0xFFF57C00,
      StageGame.slidingPuzzle => 0xFF00897B,
      StageGame.memoryMatch => 0xFFD81B60,
      StageGame.minesweeper => 0xFFE53935,
      StageGame.dotsAndBoxes => 0xFF43A047,
      StageGame.reaction => 0xFFF9A825,
      StageGame.wordSearch => 0xFF00ACC1,
      StageGame.nonogram => 0xFF8E24AA,
      StageGame.solitaire => 0xFF2E7D32,
    };

/// The game's name as a player would read it.
String stageGameName(StageGame game) => switch (game) {
      StageGame.game2048 => '2048',
      StageGame.slidingPuzzle => 'Sliding Puzzle',
      StageGame.memoryMatch => 'Memory Match',
      StageGame.minesweeper => 'Minesweeper',
      StageGame.dotsAndBoxes => 'Dots & Boxes',
      StageGame.reaction => 'Reaction',
      StageGame.wordSearch => 'Word Search',
      StageGame.nonogram => 'Nonogram',
      StageGame.solitaire => 'Solitaire',
    };
