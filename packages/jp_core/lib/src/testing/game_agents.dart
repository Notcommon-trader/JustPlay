import 'dart:math';

import '../games/dots_and_boxes/dots_and_boxes.dart';
import '../games/game_2048/board_2048.dart';
import '../games/memory_match/memory_board.dart';
import '../games/minesweeper/minesweeper_board.dart';
import '../games/nonogram/nonogram_puzzle.dart';
import '../games/sliding_puzzle/sliding_puzzle.dart';
import '../games/solitaire/solitaire_game.dart';
import '../games/sudoku/sudoku_board.dart';
import '../games/word_search/word_packs.dart';
import '../games/word_search/word_search_grid.dart';
import 'playable_game.dart';

/// Every game, wired for automated play.
///
/// Each agent plays *badly* on purpose — random legal moves, not good ones. A
/// strong player visits a narrow, sensible slice of the state space; a random
/// one wanders into the corners where the bugs live.
List<PlayableGame<Object?>> allAgents() => [
      Game2048Agent(),
      Game2048Agent(size: 3),
      SlidingPuzzleAgent(),
      MemoryMatchAgent(),
      MinesweeperAgent(),
      DotsAndBoxesAgent(),
      WordSearchAgent(),
      NonogramAgent(),
      SudokuAgent(),
      SolitaireAgent(),
      SolitaireAgent(drawCount: 3),
    ];

class Game2048Agent extends PlayableGame<Board2048> {
  Game2048Agent({this.size = 4});

  final int size;

  @override
  String get name => '2048 (${size}x$size)';

  @override
  Board2048 deal(Random random) => Board2048.newGame(size: size, random: random);

  @override
  Board2048? step(Board2048 state, Random random) {
    // Try directions in a random order and take the first that changes
    // anything. Swiping into a wall is legal but must not spawn a tile, so an
    // agent that counted no-ops as moves would fill the board and mask the bug.
    final directions = [...SlideDirection.values]..shuffle(random);

    for (final direction in directions) {
      final result = state.move(direction);
      if (!result.changed) continue;
      return result.board.spawnTile(random);
    }
    return null;
  }

  @override
  bool isFinished(Board2048 state) => state.isGameOver;

  @override
  void verify(Board2048 state) {
    if (state.tiles.length != size * size) {
      invalid('board has ${state.tiles.length} cells, expected ${size * size}');
    }
    if (state.score < 0) invalid('score went negative: ${state.score}');

    for (final tile in state.tiles) {
      if (tile == 0) continue;
      if (tile < 2 || (tile & (tile - 1)) != 0) {
        invalid('tile $tile is not a power of two');
      }
    }
  }
}

class SlidingPuzzleAgent extends PlayableGame<SlidingPuzzle> {
  SlidingPuzzleAgent({this.size = 4});

  final int size;

  @override
  String get name => 'Sliding puzzle (${size}x$size)';

  @override
  SlidingPuzzle deal(Random random) =>
      SlidingPuzzle.shuffled(size: size, random: random);

  @override
  SlidingPuzzle? step(SlidingPuzzle state, Random random) {
    final movable = state.movableTiles;
    if (movable.isEmpty) return null;
    return state.move(movable[random.nextInt(movable.length)]);
  }

  @override
  bool isFinished(SlidingPuzzle state) => state.isSolved;

  @override
  void verify(SlidingPuzzle state) {
    final seen = state.tiles.toSet();
    if (seen.length != state.tiles.length) invalid('a tile was duplicated');
    for (var i = 0; i < state.tiles.length; i++) {
      if (!seen.contains(i)) invalid('tile $i vanished');
    }
    // Sliding a tile can never make a solvable puzzle unsolvable. If this ever
    // fires, the move logic is moving something it should not.
    if (!state.isSolvable) invalid('puzzle became unsolvable');
  }
}

class MemoryMatchAgent extends PlayableGame<MemoryBoard> {
  MemoryMatchAgent({this.pairs = 8, this.columns = 4});

  final int pairs;
  final int columns;

  @override
  String get name => 'Memory match ($pairs pairs)';

  @override
  MemoryBoard deal(Random random) =>
      MemoryBoard.deal(pairs: pairs, columns: columns, random: random);

  @override
  MemoryBoard? step(MemoryBoard state, Random random) {
    // A real player is looking at a mismatch here and waiting for it to clear;
    // the agent clears it immediately.
    if (state.hasUnresolvedMismatch) return state.resolveMismatch();

    final choices = [
      for (var i = 0; i < state.cardCount; i++)
        if (state.canReveal(i)) i,
    ];
    if (choices.isEmpty) return null;

    return state.reveal(choices[random.nextInt(choices.length)]);
  }

  @override
  bool isFinished(MemoryBoard state) => state.isComplete;

  @override
  void verify(MemoryBoard state) {
    if (state.cardCount != pairs * 2) invalid('card count changed');
    if (state.matchedCount.isOdd) invalid('an odd number of cards is matched');

    final counts = <int, int>{};
    for (final symbol in state.symbols) {
      counts[symbol] = (counts[symbol] ?? 0) + 1;
    }
    for (final entry in counts.entries) {
      if (entry.value != 2) {
        invalid('symbol ${entry.key} appears ${entry.value} times, not twice');
      }
    }
  }
}

class MinesweeperAgent extends PlayableGame<MinesweeperBoard> {
  MinesweeperAgent({this.columns = 9, this.rows = 9, this.mineCount = 10});

  final int columns;
  final int rows;
  final int mineCount;

  @override
  String get name => 'Minesweeper (${columns}x$rows, $mineCount mines)';

  @override
  MinesweeperBoard deal(Random random) => MinesweeperBoard.empty(
        columns: columns,
        rows: rows,
        mineCount: mineCount,
      );

  @override
  MinesweeperBoard? step(MinesweeperBoard state, Random random) {
    if (state.isOver) return null;

    final hidden = [
      for (var i = 0; i < state.cellCount; i++)
        if (state.states[i] == CellState.hidden) i,
    ];
    if (hidden.isEmpty) return null;

    final index = hidden[random.nextInt(hidden.length)];
    // Occasionally flag instead of revealing, so the flag path gets exercised
    // and flagged cells end up protecting themselves from later reveals.
    if (random.nextInt(5) == 0) {
      return state.toggleFlag(index) ?? state.reveal(index, random: random);
    }
    return state.reveal(index, random: random);
  }

  @override
  bool isFinished(MinesweeperBoard state) => state.isOver;

  @override
  void verify(MinesweeperBoard state) {
    if (state.cellCount != columns * rows) invalid('cell count changed');

    final mines = state.mines.where((m) => m).length;
    // Mines are placed lazily on the first reveal, so zero is legitimate until
    // then — but any other count is not.
    if (mines != 0 && mines != mineCount) {
      invalid('board has $mines mines, expected $mineCount');
    }
    if (state.flagsPlaced > state.cellCount) invalid('more flags than cells');

    if (!state.isLost) {
      for (var i = 0; i < state.cellCount; i++) {
        if (state.states[i] == CellState.revealed && state.mines[i]) {
          invalid('cell $i is a revealed mine but the game is not lost');
        }
      }
    }
  }
}

class DotsAndBoxesAgent extends PlayableGame<DotsAndBoxes> {
  DotsAndBoxesAgent({this.rows = 3, this.columns = 3});

  final int rows;
  final int columns;

  @override
  String get name => 'Dots and boxes (${rows}x$columns)';

  @override
  DotsAndBoxes deal(Random random) =>
      DotsAndBoxes.empty(rows: rows, columns: columns);

  @override
  DotsAndBoxes? step(DotsAndBoxes state, Random random) {
    final edges = state.availableEdges;
    if (edges.isEmpty) return null;
    return state.draw(edges[random.nextInt(edges.length)]);
  }

  @override
  bool isFinished(DotsAndBoxes state) => state.isComplete;

  @override
  void verify(DotsAndBoxes state) {
    final claimed = state.scoreFor(BoxOwner.one) + state.scoreFor(BoxOwner.two);
    if (claimed > state.boxCount) {
      invalid('$claimed boxes claimed on a board of ${state.boxCount}');
    }

    // A claimed box must have all four sides drawn. Claiming one early would
    // hand a player points for a box still open.
    for (var box = 0; box < state.boxCount; box++) {
      if (state.owners[box] == BoxOwner.none) continue;
      if (state.drawnSidesOf(box) != 4) {
        invalid('box $box is owned with only ${state.drawnSidesOf(box)} sides');
      }
    }

    if (state.isComplete && claimed != state.boxCount) {
      invalid('board is complete but only $claimed boxes are owned');
    }
  }
}

class WordSearchAgent extends PlayableGame<WordSearchGrid> {
  WordSearchAgent({this.size = 10, this.wordCount = 8});

  final int size;
  final int wordCount;

  @override
  String get name => 'Word search (${size}x$size)';

  @override
  WordSearchGrid deal(Random random) {
    final pack = wordPacks[random.nextInt(wordPacks.length)];
    return WordSearchGrid.generate(
      words: pack.sample(wordCount, maxLength: size, random: random),
      size: size,
      random: random,
    );
  }

  @override
  WordSearchGrid? step(WordSearchGrid state, Random random) {
    final remaining = [
      for (final word in state.words)
        if (!state.found.contains(word.word)) word,
    ];
    if (remaining.isEmpty) return null;

    final target = remaining[random.nextInt(remaining.length)];
    // Drag it the way a player would — and half the time, backwards. Selection
    // must match in both directions.
    final match = random.nextBool()
        ? state.wordForSelection(target.start, target.end)
        : state.wordForSelection(target.end, target.start);

    if (match == null) {
      invalid('${target.word} is on the grid but cannot be selected');
    }
    return state.markFound(match.word);
  }

  @override
  bool isFinished(WordSearchGrid state) => state.isComplete;

  @override
  void verify(WordSearchGrid state) {
    // The generator's core promise: every word it claims to have placed can
    // actually be read off the grid.
    if (!state.verifyPlacements()) invalid('a placed word is not on the grid');

    if (state.letters.length != size * size) invalid('grid changed size');
    if (state.remainingCount < 0) invalid('negative words remaining');

    final placed = {for (final word in state.words) word.word};
    for (final found in state.found) {
      if (!placed.contains(found)) invalid('found a word that was never placed');
    }
  }
}

class NonogramAgent extends PlayableGame<NonogramPuzzle> {
  NonogramAgent({this.size = 5});

  final int size;

  @override
  String get name => 'Nonogram (${size}x$size)';

  @override
  NonogramPuzzle deal(Random random) =>
      NonogramPuzzle.generate(columns: size, rows: size, random: random);

  @override
  NonogramPuzzle? step(NonogramPuzzle state, Random random) {
    // Random cycling never finishes a nonogram — it would have to land on
    // exactly the right dozen cells — so the agent solves the clues and plays
    // the answer. That exercises the win path, which random tapping never
    // reached. The solver is the game's own, so this also checks that a puzzle
    // the generator called solvable really can be solved from its clues.
    final answer = NonogramPuzzle.solveByLines(
      rowClues: state.rowClues,
      columnClues: state.columnClues,
      columns: state.columns,
      rows: state.rows,
    );
    if (answer == null) invalid('a shipped puzzle cannot be solved by logic');

    final wrong = [
      for (var i = 0; i < state.cellCount; i++)
        if (answer[i] && state.marks[i] != NonogramMark.filled) i,
    ];
    if (wrong.isEmpty) return null;

    final index = wrong[random.nextInt(wrong.length)];
    // cycle() reaches filled from blank in one step and from crossed in two, so
    // stepping it drives the same three-state control a player uses.
    return state.cycle(index);
  }

  @override
  bool isFinished(NonogramPuzzle state) => state.isSolved;

  @override
  void verify(NonogramPuzzle state) {
    if (state.marks.length != size * size) invalid('mark count changed');
    if (state.rowClues.length != size) invalid('row clues changed');
    if (state.columnClues.length != size) invalid('column clues changed');

    // isSolved must agree with the per-line checks it is built from. If these
    // ever disagree, one of them is lying to the player about their progress.
    final everyLineSatisfied =
        List.generate(size, (i) => i).every(state.isRowSatisfied) &&
            List.generate(size, (i) => i).every(state.isColumnSatisfied);
    if (state.isSolved != everyLineSatisfied) {
      invalid('isSolved disagrees with the row and column checks');
    }
  }
}

class SudokuAgent extends PlayableGame<SudokuBoard> {
  SudokuAgent({this.difficulty = SudokuDifficulty.easy});

  final SudokuDifficulty difficulty;

  @override
  String get name => 'Sudoku (${difficulty.name})';

  @override
  SudokuBoard deal(Random random) =>
      SudokuBoard.generate(difficulty: difficulty, random: random);

  @override
  SudokuBoard? step(SudokuBoard state, Random random) {
    final open = [
      for (var i = 0; i < SudokuBoard.cellCount; i++)
        if (!state.isGiven(i) && state.entries[i] != state.solution[i]) i,
    ];
    if (open.isEmpty) return null;

    final index = open[random.nextInt(open.length)];
    // Mostly play correctly so games finish, but sometimes write a wrong digit
    // or a note, so the conflict and pencil-mark paths are exercised too.
    return switch (random.nextInt(10)) {
      0 => state.toggleNote(index, random.nextInt(9) + 1),
      1 => state.setDigit(index, random.nextInt(9) + 1),
      _ => state.revealHint(index),
    };
  }

  @override
  bool isFinished(SudokuBoard state) => state.isSolved;

  @override
  void verify(SudokuBoard state) {
    for (var i = 0; i < SudokuBoard.cellCount; i++) {
      // A given must survive every operation. If one ever changes, the player's
      // puzzle has silently become a different puzzle.
      if (state.isGiven(i) && state.entries[i] != state.givens[i]) {
        invalid('given at $i changed from ${state.givens[i]} to ${state.entries[i]}');
      }
      final entry = state.entries[i];
      if (entry != null && (entry < 1 || entry > 9)) {
        invalid('cell $i holds $entry');
      }
      if (entry != null && state.notes[i].isNotEmpty) {
        invalid('cell $i has both a digit and pencil marks');
      }
    }

    if (state.isSolved && state.conflicts.isNotEmpty) {
      invalid('solved with ${state.conflicts.length} conflicting cells');
    }
  }
}

class SolitaireAgent extends PlayableGame<Solitaire> {
  SolitaireAgent({this.drawCount = 1});

  final int drawCount;

  @override
  String get name => 'Solitaire (draw $drawCount)';

  @override
  Solitaire deal(Random random) =>
      Solitaire.deal(drawCount: drawCount, random: random);

  @override
  Solitaire? step(Solitaire state, Random random) {
    // Priority tiers, not pure randomness.
    //
    // A purely random agent livelocks: it takes a card off a foundation, puts it
    // back, and repeats forever. Every game hit the move ceiling and none ever
    // won, so the win path — the one that matters most — was never tested at
    // all. Tiers make the agent play roughly like a person: bank cards, uncover
    // face-down cards, and only draw when there is nothing better.
    //
    // Randomness stays *within* each tier, so the agent still wanders rather
    // than following one deterministic line.
    Solitaire? tryAll(List<Solitaire? Function()> moves) {
      moves.shuffle(random);
      for (final move in moves) {
        final next = move();
        if (next != null) return next;
      }
      return null;
    }

    // 1. Bank anything that will go up.
    final banked = tryAll([
      () => state.playWasteToFoundation(),
      for (var pile = 0; pile < Solitaire.tableauPiles; pile++)
        () => state.playTableauToFoundation(pile),
    ]);
    if (banked != null) return banked;

    // 2. Tableau moves that uncover a face-down card or empty a pile. These are
    //    the only tableau moves that make real progress.
    final uncovering = <Solitaire? Function()>[];
    final shuffling = <Solitaire? Function()>[];
    for (var from = 0; from < Solitaire.tableauPiles; from++) {
      for (var card = 0; card < state.tableau[from].length; card++) {
        final revealsSomething = card == 0 || !state.tableau[from][card - 1].faceUp;
        for (var to = 0; to < Solitaire.tableauPiles; to++) {
          if (to == from) continue;
          // A king shuffled between two empty piles is the other livelock.
          if (card == 0 && state.tableau[to].isEmpty) continue;
          Solitaire? move() => state.moveTableau(from, card, to);
          (revealsSomething ? uncovering : shuffling).add(move);
        }
      }
    }

    final uncovered = tryAll(uncovering);
    if (uncovered != null) return uncovered;

    // 3. Play the waste down, then draw.
    final placed = tryAll([
      for (var pile = 0; pile < Solitaire.tableauPiles; pile++)
        () => state.playWasteToTableau(pile),
    ]);
    if (placed != null) return placed;

    final drawn = state.draw();
    if (drawn != null) return drawn;

    // 4. Nothing productive left. Rearranging face-up runs occasionally opens a
    //    game up, so it is worth trying — but only once the useful moves are
    //    exhausted, and never in preference to them.
    return tryAll(shuffling);
  }

  @override
  bool isFinished(Solitaire state) => state.isOver;

  @override
  void verify(Solitaire state) {
    // The strong one. Fifty-two distinct cards, always, wherever they sit. Any
    // move that duplicates or loses a card fails here immediately, and no
    // scripted test would think to count the deck after every move.
    final all = [
      ...state.stock,
      ...state.waste,
      for (final pile in state.foundations) ...pile,
      for (final pile in state.tableau) ...pile,
    ];
    if (all.length != 52) invalid('deck has ${all.length} cards');

    final ids = all.map((card) => card.id).toSet();
    if (ids.length != 52) invalid('deck has duplicates');

    for (final card in state.waste) {
      if (!card.faceUp) invalid('a face-down card is on the waste');
    }
    for (final pile in state.foundations) {
      for (var i = 0; i < pile.length; i++) {
        if (pile[i].rank != i + 1) invalid('foundation is out of order');
        if (pile[i].suit != pile.first.suit) invalid('foundation mixes suits');
      }
    }
    if (state.tableau.length != Solitaire.tableauPiles) {
      invalid('tableau lost a pile');
    }
    if (state.isWon && state.remainingCards != 0) {
      invalid('won with ${state.remainingCards} cards still out');
    }
  }
}
