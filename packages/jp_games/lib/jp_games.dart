/// The JustPlay game catalogue.
///
/// One folder per game. A game never imports another game — that constraint is
/// what makes "ship this game in a different app" a config line rather than a
/// copy-paste.
library;

export 'src/cascade/cascade_definition.dart';
export 'src/cascade/cascade_view.dart';
export 'src/dots_and_boxes/dots_and_boxes_definition.dart';
export 'src/dots_and_boxes/dots_and_boxes_view.dart';
export 'src/game_2048/board_2048_view.dart';
export 'src/game_2048/game_2048_definition.dart';
export 'src/game_2048/tile_palette.dart';
export 'src/memory_match/memory_match_definition.dart';
export 'src/memory_match/memory_match_view.dart';
export 'src/minesweeper/minesweeper_definition.dart';
export 'src/minesweeper/minesweeper_view.dart';
export 'src/nonogram/nonogram_definition.dart';
export 'src/nonogram/nonogram_view.dart';
export 'src/reaction/reaction_definition.dart';
export 'src/reaction/reaction_view.dart';
export 'src/sliding_puzzle/sliding_puzzle_definition.dart';
export 'src/sliding_puzzle/sliding_puzzle_view.dart';
export 'src/solitaire/solitaire_definition.dart';
export 'src/solitaire/solitaire_view.dart';
export 'src/sudoku/sudoku_definition.dart';
export 'src/sudoku/sudoku_view.dart';
export 'src/word_search/word_search_definition.dart';
export 'src/word_search/word_search_view.dart';
