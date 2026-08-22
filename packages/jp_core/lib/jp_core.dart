/// Pure Dart game rules and scoring for every JustPlay title.
///
/// This library must never import `package:flutter/*`. That constraint is what
/// keeps rules testable in milliseconds without a widget tree, and what would
/// let the logic outlive a change of UI framework.
library;

export 'src/games/cascade/cascade_board.dart';
export 'src/games/dots_and_boxes/dots_and_boxes.dart';
export 'src/journey/journey.dart';
export 'src/games/game_2048/board_2048.dart';
export 'src/games/memory_match/memory_board.dart';
export 'src/games/minesweeper/minesweeper_board.dart';
export 'src/games/nonogram/nonogram_puzzle.dart';
export 'src/games/reaction/reaction_run.dart';
export 'src/games/sliding_puzzle/sliding_puzzle.dart';
export 'src/games/solitaire/solitaire_game.dart';
export 'src/games/sudoku/sudoku_board.dart';
export 'src/games/word_search/word_packs.dart';
export 'src/games/word_search/word_search_grid.dart';
export 'src/session/game_session_state.dart';
export 'src/testing/game_agents.dart';
export 'src/testing/playable_game.dart';
