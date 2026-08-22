import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_games/jp_games.dart';
import 'package:jp_ui/jp_ui.dart';

import 'coach_moves.dart';
import 'first_play_coach.dart';

/// One step of a game's rules, as a player would be told them out loud.
///
/// An icon and a sentence, not a paragraph. Nobody reads a wall of rules on a
/// phone — they tap Play and work it out, and the only instructions that get
/// read are the ones that fit on a card.
class HowToStep {
  const HowToStep({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

/// One difficulty or board size within a game.
///
/// These used to be separate rows on the home screen: "Sudoku · Easy", "Sudoku",
/// "Sudoku · Hard" sat as three unrelated entries among twenty-one, which made
/// the list long enough that whole games went unnoticed, and made the app read
/// as a directory rather than something to play. A level belongs *inside* its
/// game, chosen after you have decided what you want to play.
class GameLevel {
  const GameLevel({
    required this.label,
    required this.definition,
    this.detail,
  });

  /// Shown on the chip. Short — it has to fit four across.
  final String label;

  /// One line under the chosen chip, for what the label cannot say.
  final String? detail;

  final GameDefinition definition;
}

/// A game, with everything the app needs to present it.
class CatalogueEntry {
  const CatalogueEntry({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.colour,
    required this.coachMoves,
    required this.howToPlay,
    required this.levels,
  });

  final String name;
  final String tagline;
  final IconData icon;

  /// The game's own identity colour.
  ///
  /// Seeds the whole theme while that game is open, so Minesweeper is red and
  /// Solitaire is green rather than every screen being the same indigo. This is
  /// the cheapest thing that separates an app that feels like a game from one
  /// that feels like a settings menu — and the previous build was uniformly one
  /// hue, which is exactly how it read.
  final Color colour;

  /// Gestures the coach points out on the real board, the first time this game
  /// is played.
  ///
  /// This carries the explaining now. It replaced a looping animation in the
  /// game sheet, which sat on a different screen, before play, on a miniature of
  /// a board — something to watch rather than something to do. The text below is
  /// for anyone who wants the detail afterwards.
  final List<CoachMove> coachMoves;

  final List<HowToStep> howToPlay;
  final List<GameLevel> levels;

  /// The level a player gets if they just hit Play. The middle one where there
  /// are three, so the default is neither patronising nor punishing.
  GameLevel get defaultLevel => levels[levels.length ~/ 2];
}

/// What ships in this app: ten games, each with its own levels.
const List<CatalogueEntry> appCatalogue = [
  CatalogueEntry(
    name: 'Cascade',
    tagline: 'Match three, then watch it chain',
    icon: Icons.auto_awesome,
    colour: Color(0xFF00BFA5),
    coachMoves: CoachMoves.cascade,
    howToPlay: [
      HowToStep(
        icon: Icons.swap_horiz,
        text: 'Swap two touching tiles to line up three of a colour.',
      ),
      HowToStep(
        icon: Icons.auto_awesome,
        text: 'They clear, everything above drops — and often matches again.',
      ),
      HowToStep(
        icon: Icons.trending_up,
        text: 'Each link of a chain is worth more than the last.',
      ),
      HowToStep(
        icon: Icons.block,
        text: 'A swap that matches nothing is refused, so nothing is wasted.',
      ),
    ],
    levels: [
      GameLevel(
        label: 'Small',
        detail: 'Six by seven — matches sit closer, so chains fire more often',
        definition: CascadeDefinition.small,
      ),
      GameLevel(
        label: 'Standard',
        detail: 'Seven by eight',
        definition: CascadeDefinition(),
      ),
    ],
  ),
  CatalogueEntry(
    name: 'Sudoku',
    tagline: 'Fill the grid, one to nine',
    icon: Icons.grid_on,
    colour: Color(0xFF1E88E5),
    coachMoves: CoachMoves.sudoku,
    howToPlay: [
      HowToStep(
        icon: Icons.looks_one,
        text: 'Every row, column and 3×3 box holds 1 to 9, once each.',
      ),
      HowToStep(
        icon: Icons.touch_app,
        text: 'Tap a square, then tap a number. Tap it again to clear it.',
      ),
    ],
    levels: [
      GameLevel(
        label: 'Easy',
        detail: '42 given numbers — room to breathe',
        definition: SudokuDefinition(difficulty: SudokuDifficulty.easy),
      ),
      GameLevel(
        label: 'Medium',
        detail: '34 given numbers',
        definition: SudokuDefinition(),
      ),
      GameLevel(
        label: 'Hard',
        detail: '28 given numbers — bring pencil marks',
        definition: SudokuDefinition(difficulty: SudokuDifficulty.hard),
      ),
    ],
  ),
  CatalogueEntry(
    name: 'Solitaire',
    tagline: 'Klondike, the way you remember it',
    icon: Icons.style,
    colour: Color(0xFF2E7D32),
    coachMoves: CoachMoves.solitaire,
    howToPlay: [
      HowToStep(
        icon: Icons.swap_vert,
        text: 'Build the four piles at the top up from ace to king, by suit.',
      ),
      HowToStep(
        icon: Icons.drag_indicator,
        text: 'Down the board, stack cards in falling order, alternating red '
            'and black.',
      ),
    ],
    levels: [
      GameLevel(
        label: 'Draw one',
        detail: 'One card at a time — the friendlier rule',
        definition: SolitaireDefinition(),
      ),
      GameLevel(
        label: 'Draw three',
        detail: 'Three at a time — the traditional, harder rule',
        definition: SolitaireDefinition.drawThree,
      ),
    ],
  ),
  CatalogueEntry(
    name: '2048',
    tagline: 'Slide, merge, and keep going',
    icon: Icons.dialpad,
    colour: Color(0xFFF57C00),
    coachMoves: CoachMoves.game2048,
    howToPlay: [
      HowToStep(
        icon: Icons.swipe,
        text: 'Swipe any direction. Every tile slides as far as it can.',
      ),
      HowToStep(
        icon: Icons.merge_type,
        text: 'Two matching tiles that touch become one, worth double.',
      ),
    ],
    levels: [
      GameLevel(
        label: '3×3',
        detail: 'Cramped and quick',
        definition: Game2048Definition(boardSize: 3),
      ),
      GameLevel(
        label: '4×4',
        detail: 'The original',
        definition: Game2048Definition(),
      ),
      GameLevel(
        label: '5×5',
        detail: 'More room, longer game',
        definition: Game2048Definition(boardSize: 5),
      ),
    ],
  ),
  CatalogueEntry(
    name: 'Minesweeper',
    tagline: 'Clear the board, avoid the mines',
    icon: Icons.flag,
    colour: Color(0xFFE53935),
    coachMoves: CoachMoves.minesweeper,
    howToPlay: [
      HowToStep(
        icon: Icons.touch_app,
        text: 'Tap to open a square. Your first tap is always safe.',
      ),
      HowToStep(
        icon: Icons.pin,
        text: 'A number says how many mines touch that square.',
      ),
    ],
    levels: [
      GameLevel(
        label: 'Beginner',
        detail: '9×9 with 10 mines',
        definition: MinesweeperDefinition.beginner,
      ),
      GameLevel(
        label: 'Harder',
        detail: '12×12 with 25 mines',
        definition: MinesweeperDefinition.intermediate,
      ),
    ],
  ),
  CatalogueEntry(
    name: 'Word Search',
    tagline: 'Find the hidden words',
    icon: Icons.search,
    colour: Color(0xFF00ACC1),
    coachMoves: CoachMoves.wordSearch,
    howToPlay: [
      HowToStep(
        icon: Icons.list_alt,
        text: 'The words to find are listed under the grid.',
      ),
      HowToStep(
        icon: Icons.swipe,
        text: 'Drag from the first letter to the last to select a word.',
      ),
    ],
    levels: [
      GameLevel(
        label: 'Standard',
        detail: '10×10 grid, 8 words',
        definition: WordSearchDefinition(),
      ),
      GameLevel(
        label: 'Long haul',
        detail: '12×12 grid, 12 words',
        definition: WordSearchDefinition.large,
      ),
    ],
  ),
  CatalogueEntry(
    name: 'Nonogram',
    tagline: 'Numbers in, picture out',
    icon: Icons.blur_linear,
    colour: Color(0xFF8E24AA),
    coachMoves: CoachMoves.nonogram,
    howToPlay: [
      HowToStep(
        icon: Icons.numbers,
        text: 'Numbers beside a line say how many squares to fill, in order.',
      ),
      HowToStep(
        icon: Icons.space_bar,
        text: '"3 1" means three filled, a gap, then one filled.',
      ),
    ],
    levels: [
      GameLevel(
        label: '5×5',
        detail: 'A coffee break',
        definition: NonogramDefinition.small,
      ),
      GameLevel(
        label: '10×10',
        detail: 'A proper sitting',
        definition: NonogramDefinition(),
      ),
    ],
  ),
  CatalogueEntry(
    name: 'Memory Match',
    tagline: 'Find every pair',
    icon: Icons.style_outlined,
    colour: Color(0xFFD81B60),
    coachMoves: CoachMoves.memory,
    howToPlay: [
      HowToStep(
        icon: Icons.touch_app,
        text: 'Turn over two cards.',
      ),
      HowToStep(
        icon: Icons.compare_arrows,
        text: 'Matching pair? It stays face up. Otherwise both turn back.',
      ),
    ],
    levels: [
      GameLevel(
        label: 'Quick',
        detail: 'Six pairs',
        definition: MemoryMatchDefinition(pairs: 6, columns: 3),
      ),
      GameLevel(
        label: 'Standard',
        detail: 'Eight pairs',
        definition: MemoryMatchDefinition(),
      ),
    ],
  ),
  CatalogueEntry(
    name: 'Sliding Puzzle',
    tagline: 'Get the tiles back in order',
    icon: Icons.apps,
    colour: Color(0xFF00897B),
    coachMoves: CoachMoves.slidingPuzzle,
    howToPlay: [
      HowToStep(
        icon: Icons.touch_app,
        text: 'Tap a tile next to the gap and it slides across.',
      ),
      HowToStep(
        icon: Icons.sort,
        text: 'Put the numbers back in order, gap at the end.',
      ),
    ],
    levels: [
      GameLevel(
        label: 'Eight',
        detail: '3×3 — the gentler one',
        definition: SlidingPuzzleDefinition(boardSize: 3),
      ),
      GameLevel(
        label: 'Fifteen',
        detail: '4×4 — the classic',
        definition: SlidingPuzzleDefinition(),
      ),
    ],
  ),
  CatalogueEntry(
    name: 'Dots & Boxes',
    tagline: 'Close more boxes than the computer',
    icon: Icons.border_all,
    colour: Color(0xFF43A047),
    coachMoves: CoachMoves.dotsAndBoxes,
    howToPlay: [
      HowToStep(
        icon: Icons.linear_scale,
        text: 'Take turns drawing one line between two dots.',
      ),
      HowToStep(
        icon: Icons.check_box,
        text: 'Draw a box\'s fourth side and you claim it.',
      ),
    ],
    levels: [
      GameLevel(
        label: 'Gentle',
        detail: '3×3 grid, easier opponent',
        definition: DotsAndBoxesDefinition(
          rows: 3,
          columns: 3,
          level: DotsAiLevel.easy,
        ),
      ),
      GameLevel(
        label: 'Standard',
        detail: '4×4 grid',
        definition: DotsAndBoxesDefinition(),
      ),
    ],
  ),
  CatalogueEntry(
    name: 'Reaction',
    tagline: 'How fast are you, really?',
    icon: Icons.bolt,
    colour: Color(0xFFF9A825),
    coachMoves: CoachMoves.reaction,
    howToPlay: [
      HowToStep(
        icon: Icons.hourglass_empty,
        text: 'Tap to start, then wait. The screen turns green when it wants to.',
      ),
      HowToStep(
        icon: Icons.flash_on,
        text: 'Tap the instant it does. Faster scores higher.',
      ),
    ],
    levels: [
      GameLevel(
        label: '5 rounds',
        detail: 'About a minute',
        definition: ReactionDefinition(),
      ),
      GameLevel(
        label: '10 rounds',
        detail: 'A steadier average',
        definition: ReactionDefinition(rounds: 10),
      ),
    ],
  ),
];
