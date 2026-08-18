# Journey — the long-session design

The goal is not daily retention. It is **one sitting of three to four hours**.
Those need different designs, and conflating them is how this app ended up as ten
correct puzzles that nobody wants to keep playing.

## What actually ends a long session

Not boredom with the mechanic — that comes later than people think. It is:

1. **Being asked to decide.** Finish a round, land back on a grid of ten tiles,
   and now there is a choice to make. Every choice is an exit. The current app
   asks for one after every single game.
2. **Fatigue with one mechanic.** Nobody plays sudoku for four hours. Anyone
   might play a mixed run for four hours.
3. **A wall with no way through.** A stage that cannot be beaten ends the sitting
   at that stage.
4. **A natural stopping point.** "You've finished!" is permission to leave.

The design is the inverse of that list: never ask, always vary, always passable,
never finish.

## The shape

A numbered ladder of **stages**. Each stage is one short round of one game with a
specific goal. Beat it and the next stage begins **immediately** — same screen,
no menu, no return to the grid.

```
Stage 41   2048        Reach 256                    ~90s
Stage 42   Word Search Find 5 words                 ~60s
Stage 43   Nonogram    Clear the 5x5                ~2m
Stage 44   Minesweeper Open 20 squares, no mine     ~90s
Stage 45   Solitaire   Send 6 cards home            ~3m
```

**One to three minutes each.** Short enough that "one more" is always cheap, and
short enough that a loss costs almost nothing.

**Goals, not just wins.** The same 2048 board is a different task at "reach 256"
than at "reach 512 in 40 moves". This is where variety comes from — one mechanic,
many objectives — and it is the thing Candy Crush does that the current app does
not do at all.

**Never the same game three times running.** The generator enforces it. Rotation
is what defeats mechanic fatigue, and it is the reason ten games is an asset here
rather than a scattered catalogue.

## Rules that protect the session

**No lives, no energy, no timers between stages.** These exist to cap sessions
and sell the cap. They are the opposite of the goal. This is not a monetisation
decision to revisit later — a four-hour session and an energy meter cannot both
exist.

**Retry is instant.** Lose a stage and the retry button is under your thumb, with
a fresh board, in under a second. No interstitial, no "out of lives", no penalty.

**No stage is a hard wall.** After three failures the stage offers an easier
variant — quietly, without announcing that the player is being helped. A wall
ends the sitting; nothing else about the design matters if the player is stuck.

**No end.** Stages are generated, not authored, so the ladder does not run out.
A "congratulations, you finished" screen is permission to stop.

## What makes a stage feel worth finishing

**Stars.** One for beating it, two and three for the stretch goal (faster, fewer
moves). Gives a reason to replay a stage already beaten, without ever requiring
it to progress.

**The next stage is already visible** as the current one ends — the win panel
shows what is coming, with the button on it. The player's eye should land on
"Stage 42 · Word Search · Find 5 words" before they have decided to stop.

**Real feedback.** Sound, haptics, a score that counts up rather than appearing.
The app currently makes no sound at all and shows a grey panel on a win. Whatever
else is built, this is the part that makes a moment feel like a reward.

## Milestones, so hours feel like progress

Every ten stages, something visibly changes — a new game enters the rotation, a
colour theme shifts, a chapter name appears. Not a reward to collect; a marker
that says *you have come a distance*. Three hours of identical stages feels like
one hour repeated.

## What this reuses

Almost everything. `GameDefinition` already builds a board from a config, and
`GameSession` already reports score, moves, time and outcome — which is exactly
what a stage goal needs to be evaluated against. A stage is a definition plus a
goal plus a target.

What is genuinely new: the goal types, the stage generator, the run state, and
the between-stage screen.

## Build order

1. **Goals and stage model** — pure Dart in `jp_core`, so pacing is testable
   without a UI.
2. **The stage generator** — with the no-repeats and difficulty-curve rules, and
   tests that play a hundred stages and assert nobody meets an impossible one.
3. **The run screen** — board, goal banner, and the immediate next-stage flow.
4. **Juice and audio** — the moment-to-moment reward. Improves every game at
   once, and the current silence is the single biggest thing making a win feel
   like nothing happened.
5. **Stars and milestones.**

Steps 1 and 2 are where the product is decided. If the pacing is wrong, no amount
of step 4 rescues it.
