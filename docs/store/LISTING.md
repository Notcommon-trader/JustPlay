# Play Store listing — JustPlay

Copy for the Google Play console. Paste as-is; the character counts are Play's
hard limits and these are already inside them.

---

## App name (30 max)

```
JustPlay: 10 Puzzle Games
```

*27 characters.* The number is doing the work — "10 games" is the whole pitch and
it survives truncation in a search result, which a cleverer name would not.

## Short description (80 max)

```
Sudoku, solitaire, 2048 and seven more. No timer pressure, no internet needed.
```

*77 characters.* Names the two games people search for, then answers the two
things that make someone close a casual game: forced timers and a network check.

## Full description (4000 max)

```
Ten classic puzzle games in one app. Play for two minutes or two hours.

No account. No internet. Nothing to sign up for — open it and play.

WHAT'S INSIDE

• Sudoku — three difficulties, with pencil marks and hints. Every puzzle has
  exactly one solution and can be solved by reasoning alone. No guessing.
• Solitaire — Klondike, draw one or draw three. Drag cards, or tap to send them
  home automatically.
• 2048 — the sliding number game, on a 3x3, 4x4 or 5x5 board.
• Nonogram — picross by another name. Read the numbers, fill in the picture.
  Every puzzle is solvable by logic; none of them needs a lucky guess.
• Word Search — five themed word packs, hidden in eight directions.
• Minesweeper — nine by nine, or twelve by twelve for a longer sit.
• Memory Match — find every pair before the clock gets away from you.
• Sliding Puzzle — eight or fifteen tiles, always solvable.
• Dots and Boxes — close more boxes than the computer.
• Reaction — tap the moment it turns green. Ten seconds a round.

TWENTY-ONE WAYS TO PLAY

Most games come in more than one size or difficulty, so there are 21 entries in
the list. Start on Sudoku Easy, work up to Hard. Try 2048 on a three-by-three
board when four feels too comfortable.

BUILT TO GET OUT OF YOUR WAY

• Works completely offline. On a plane, on the underground, anywhere.
• No account, no login, no email address.
• Your best scores and times are saved on your device.
• Dark mode follows your phone automatically.
• Every game pauses when you leave, and is still there when you come back.

FAIR PUZZLES

Every generated puzzle is checked before you see it. Sudoku boards have exactly
one answer. Nonograms can always be finished by logic. Sliding puzzles are always
solvable. Minesweeper never puts a mine under your first tap.

That sounds obvious. It is not — plenty of puzzle apps ship boards that cannot be
solved without guessing, and you cannot tell the difference from the inside.
```

## What's new (500 max) — first release

```
First release. Ten games, twenty-one ways to play, all of it offline.
```

---

## Graphics

| Asset | Spec | Status |
|---|---|---|
| Phone screenshots | 1080×2400, min 2, max 8 | **Six, in `screenshots/`.** Captured from the release build on an Android 15 emulator. |
| App icon | 512×512, 32-bit PNG | **Missing.** Still Flutter's default. |
| Feature graphic | 1024×500 | **Missing.** Required — Play will not publish without it. |

The two missing items are artwork. They are not written here because inventing
placeholder art produces something that looks like placeholder art on a store
page, which is worse than an empty slot in a checklist. They need a designer or
an image generator, and then dropping the files in.

The screenshots are real captures of the shipping build, not mockups.

---

## Category and tags

- **Category:** Games → Puzzle
- **Tags:** puzzle, brain games, offline games, sudoku, solitaire
- **Content rating:** expect Everyone / PEGI 3 — no violence, no user content, no
  purchases yet. The questionnaire answer changes the moment ads land.
- **Target audience:** 13+ and up. Do **not** tick any under-13 age group; see
  [DECISIONS.md](../DECISIONS.md) for why, and for what that obliges the app to
  keep being.
