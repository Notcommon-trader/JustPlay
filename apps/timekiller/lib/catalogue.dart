import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

/// One entry in the app's game list.
///
/// Names and descriptions are plain strings here rather than localization keys,
/// because no l10n package has landed yet. When it does, this is the one place
/// that changes — the [GameDefinition]s already carry their key names.
class CatalogueEntry {
  const CatalogueEntry({
    required this.definition,
    required this.name,
    required this.tagline,
    required this.icon,
  });

  final GameDefinition definition;
  final String name;
  final String tagline;
  final IconData icon;
}

/// What ships in this app.
///
/// The catalogue is data, not code: adding a game is one entry here plus its
/// package. Nothing in the home screen or the shell needs to know it happened,
/// which is the mechanism that keeps a second app cheap.
const List<CatalogueEntry> appCatalogue = [
  CatalogueEntry(
    definition: Game2048Definition(),
    name: '2048',
    tagline: 'Slide and merge to reach 2048',
    icon: Icons.grid_4x4,
  ),
  CatalogueEntry(
    definition: Game2048Definition(boardSize: 5),
    name: '2048 · Relaxed',
    tagline: 'A bigger board and more room to think',
    icon: Icons.grid_on,
  ),
  CatalogueEntry(
    definition: Game2048Definition(boardSize: 3),
    name: '2048 · Tight',
    tagline: 'Three by three. Good luck',
    icon: Icons.grid_3x3,
  ),
  CatalogueEntry(
    definition: SlidingPuzzleDefinition(),
    name: 'Sliding Puzzle',
    tagline: 'Slide the tiles back into order',
    icon: Icons.apps,
  ),
  CatalogueEntry(
    definition: SlidingPuzzleDefinition(boardSize: 3),
    name: 'Sliding Puzzle · Eight',
    tagline: 'The gentler eight-tile version',
    icon: Icons.apps_outlined,
  ),
  CatalogueEntry(
    definition: MemoryMatchDefinition(),
    name: 'Memory Match',
    tagline: 'Find every pair before the clock runs away',
    icon: Icons.style,
  ),
  CatalogueEntry(
    definition: MemoryMatchDefinition(pairs: 6, columns: 3),
    name: 'Memory Match · Quick',
    tagline: 'Six pairs, a two-minute round',
    icon: Icons.style_outlined,
  ),
  CatalogueEntry(
    definition: MinesweeperDefinition.beginner,
    name: 'Minesweeper',
    tagline: 'Nine by nine, ten mines. Long press to flag',
    icon: Icons.flag,
  ),
  CatalogueEntry(
    definition: MinesweeperDefinition.intermediate,
    name: 'Minesweeper · Harder',
    tagline: 'Twelve by twelve, twenty-five mines',
    icon: Icons.flag_outlined,
  ),
  CatalogueEntry(
    definition: DotsAndBoxesDefinition(),
    name: 'Dots & Boxes',
    tagline: 'Close more boxes than the computer',
    icon: Icons.border_all,
  ),
  CatalogueEntry(
    definition: DotsAndBoxesDefinition(rows: 3, columns: 3, level: DotsAiLevel.easy),
    name: 'Dots & Boxes · Gentle',
    tagline: 'A smaller grid and an easier opponent',
    icon: Icons.border_outer,
  ),
  CatalogueEntry(
    definition: ReactionDefinition(),
    name: 'Reaction',
    tagline: 'Tap the moment it turns green',
    icon: Icons.bolt,
  ),
  CatalogueEntry(
    definition: SolitaireDefinition(),
    name: 'Solitaire',
    tagline: 'Klondike, one card at a time',
    icon: Icons.style_rounded,
  ),
  CatalogueEntry(
    definition: SolitaireDefinition.drawThree,
    name: 'Solitaire · Draw Three',
    tagline: 'The traditional rule, and the harder one',
    icon: Icons.filter_3,
  ),
  CatalogueEntry(
    definition: SudokuDefinition(difficulty: SudokuDifficulty.easy),
    name: 'Sudoku · Easy',
    tagline: 'Forty-two givens and room to breathe',
    icon: Icons.calculate_outlined,
  ),
  CatalogueEntry(
    definition: SudokuDefinition(),
    name: 'Sudoku',
    tagline: 'The standard grid, with notes and hints',
    icon: Icons.calculate,
  ),
  CatalogueEntry(
    definition: SudokuDefinition(difficulty: SudokuDifficulty.hard),
    name: 'Sudoku · Hard',
    tagline: 'Twenty-eight givens. Bring pencil marks',
    icon: Icons.functions,
  ),
  CatalogueEntry(
    definition: NonogramDefinition.small,
    name: 'Nonogram · Five',
    tagline: 'Picross for a coffee break',
    icon: Icons.blur_linear,
  ),
  CatalogueEntry(
    definition: NonogramDefinition(),
    name: 'Nonogram',
    tagline: 'Ten by ten. Read the numbers, fill the picture',
    icon: Icons.blur_on,
  ),
  CatalogueEntry(
    definition: WordSearchDefinition(),
    name: 'Word Search',
    tagline: 'Drag across the hidden words',
    icon: Icons.search,
  ),
  CatalogueEntry(
    definition: WordSearchDefinition.large,
    name: 'Word Search · Long Haul',
    tagline: 'Twelve by twelve, twelve words',
    icon: Icons.manage_search,
  ),
];
