# Testing

Five layers, each catching what the others cannot.

| Layer | Where | Runs in | Catches |
|---|---|---|---|
| Unit | `jp_core`, `jp_framework` | `dart test` / `flutter test` | Game rules, scoring, solvability, persistence |
| Widget | `jp_ui`, `jp_games` | `flutter test` | Interaction, state, shell wiring |
| **Golden** | `test/golden/` | `flutter test` | **Visual regressions** |
| **Wiring** | `apps/*/test/` | `flutter test` | **Whether the pieces are connected** |
| Integration | *(not yet)* | `integration_test` | Boot, purchase, sync |

Current: **413 tests** — 212 in `jp_core`, 26 in `jp_framework`, 40 in `jp_ui`, 130 in `jp_games`,
5 in `timekiller`.

```bash
cd C:\dev\justplay
C:\dev\flutter\bin\dart.bat analyze
cd packages\jp_core      && C:\dev\flutter\bin\dart.bat test
cd packages\jp_framework && C:\dev\flutter\bin\flutter.bat test
cd packages\jp_ui        && C:\dev\flutter\bin\flutter.bat test
cd packages\jp_games     && C:\dev\flutter\bin\flutter.bat test
cd apps\timekiller       && C:\dev\flutter\bin\flutter.bat test
```

### Why the wiring layer exists

`apps/timekiller/test/records_wiring_test.dart` plays a game to completion through the real app tree
and then asserts the record reached storage *and* the home card. Every piece of that path is already
unit tested where it lives. The layer exists because the pieces being individually right has never
once meant they were connected — the app-scoped store, the shell's `onFinished`, and the card that
reads it are three separate files, and any one of them can be correct while doing nothing.

---

## Golden tests

A golden is a committed PNG of what a widget should look like. The test re-renders and compares
pixel by pixel.

**Why they exist here specifically.** Every other layer can pass while the app looks wrong. A
spacing token nudged, a colour role swapped, a corner radius reset — all compile, all pass their
widget tests, all visible to a user. Goldens are the only automated check on appearance.

They have already earned their place twice on their first day:

- **Muted palette.** `ColorScheme.fromSeed` desaturates by default; a vivid indigo came back as a
  slate grey. Switching to `DynamicSchemeVariant.vibrant` produced a 30.8% pixel diff — invisible to
  every other test, obvious in the image.
- **Invisible 2048 tiles.** Low tiles started at `surfaceContainerHighest`, which is almost exactly
  the empty-cell colour. A "2" was indistinguishable from an empty square. Nothing but a rendered
  image would have caught that.

### Regenerating

```bash
flutter test --update-goldens
```

Then **look at the images**. A regenerated golden is only as good as the eyes on it — running
`--update-goldens` to make a red test green, without opening the PNG, converts the whole layer into
a rubber stamp.

Failures write a diff to `test/golden/failures/`, showing expected, actual, and the masked
difference. That directory is gitignored.

### Two things to know before writing one

**Text renders as solid blocks.** Flutter's test environment substitutes a placeholder font so
goldens do not depend on which fonts a machine has installed. Layout, sizing, colour, spacing and
shape are all captured faithfully; only glyph shapes are not. This is a feature — a golden that
changed because someone installed a font would be noise.

**Every board must be seeded.** `Game2048Definition(seed: 7)`, `SlidingPuzzleDefinition(seed: 3)`.
An unseeded board deals differently on every run and the golden fails constantly.

### Platform sensitivity

Goldens are rendered by the host machine, so antialiasing can differ subtly between operating
systems. **These were generated on Windows.** If CI runs on Linux, regenerate there and treat that
as the source of truth — otherwise the first CI run fails on rendering differences alone, and the
usual response to that is to stop trusting the layer.

### Surface sizes

Use `GoldenSize` from `jp_ui` rather than the host default, so the capture size is reproducible:

- `GoldenSize.phone` — 390×844, the default
- `GoldenSize.phoneShort` — 360×640, where fixed-height layouts overflow first
- `GoldenSize.component` — for a single widget rather than a screen

Always restore it: `addTearDown(() => tester.binding.setSurfaceSize(null))`.

---

## UI and UX testing

Two suites in `jp_games`, both automated.

### `accessibility_test.dart` — Flutter's own guideline audits

`textContrastGuideline` (WCAG AA), `androidTapTargetGuideline` (Material's 48dp
minimum) and `labeledTapTargetGuideline`, run against every game. These are not
opinions — they are requirements a store review can cite, and all three are
invisible in a screenshot. A control can look perfectly fine and still be
unreadable or untappable.

The first run failed **nine** checks. What it found:

| Problem | Measured | Required |
|---|---|---|
| Pause/game-over overlay: "Quit" button | 1.43:1 | 4.5:1 |
| Pause/game-over overlay: "Paused" heading | 2.75:1 | 3.0:1 |
| Solitaire foundation suit watermarks | 2.02:1 | 3.0:1 |
| Six games: cells with no semantic label | — | any label |
| Dots & Boxes edge tap target | 10pt | 48pt |

The overlay was the worst and affected every game: theme text meant for a light
surface was being painted straight onto a dark scrim, at the exact moment the
player is being asked to make a decision. It is now a proper elevated panel.

**Accepted exceptions**, listed rather than hidden:

- **Dense grids** (sudoku, minesweeper, nonogram, word search, solitaire) cannot
  meet the 48dp tap target. A 9×9 sudoku on a 390pt phone gives each cell about
  39pt; meeting the guideline would need a board wider than the screen. Every
  sudoku app makes this trade. It is a real accessibility cost, not a
  technicality.
- **Dots & Boxes** edges went from 10pt to 24pt — a large improvement to a
  genuinely frustrating control, still short of 48. The proper fix is
  hit-testing the nearest edge across a whole box quadrant, which is a rewrite of
  its grid and has not been done.

### `ui_soak_test.dart` — the UI monkey

The rules agent proves the *logic* survives extended play. This proves the
*widgets* do, which is a different bug class: hit-testing outside a parent's
bounds, a timer firing after dispose, `setState` on an unmounted `State`, a board
that overflows when it reflows.

It fires random taps and drags at every screen — on the board, off the board,
mid-animation — hammers pause and restart, tears the screen down while animations
are still running, and renders every game at four screen sizes from 320×568 up.
Any exception fails, because an unhandled exception in a widget test is a red
screen in production.

It found Sudoku's control row overflowing by 50pt at 320 and 9.5pt at 360: the
three chips need 337.5pt laid out in a line and only 304pt is available. They
wrap now.

**One trap worth knowing.** Pumping games one after another into the same tester
reuses `GameShell`'s `State`, and with it the previous game's session — so a
failure gets blamed on whichever game is on screen when you check. The layout
tests mount a blank widget between games. The real app never hits this, because
every game is pushed as its own route.

## The test agent

`packages/jp_core/lib/src/testing/` holds an automated player. Every game
implements `PlayableGame`, which the runner uses to deal a board, play legal
moves until the game ends, and **re-check that game's invariants after every
single move**.

```bash
dart run jp_core:soak --games 5000 --seed 90000
```

A small soak runs in the test suite on every commit; CI runs a larger one with a
seed derived from the run number, so it keeps exploring new positions instead of
re-testing the same games forever.

**Why this earns its place.** A hand-written test plays one scripted game and
asserts what the author already suspected. The agent plays millions of moves and
asserts things that must hold in *all* of them. The strongest invariants are the
ones nobody would think to assert by hand:

- Solitaire counts all 52 distinct cards after every move. Any move that
  duplicates or loses a card fails immediately.
- Word search reads every placed word back off the grid.
- Sliding puzzle checks the tiles are still a permutation *and* still solvable.
- Sudoku checks no given ever changed.
- Nonogram checks `isSolved` agrees with the row and column checks it is built
  from.

The runner also treats **"no legal move but the game is not finished"** as a
failure. That is a softlock, and it is the bug class random play finds best.

### It has already paid for itself

The first real run reported: *"no legal move remains but the game is not
finished"* on Solitaire, seed 96, move 119. That was not a test bug — a Klondike
deal can genuinely die, and `SolitaireView` only ever called `finish(won)`. A
player reaching a dead board would have sat there with no moves and no message.
Fixed by adding `Solitaire.hasMoves`, and guarded by a test that replays seed 96.

### Reading the report

Always look at the counts, not just pass/fail:

```
Solitaire (draw 1): 200 games, 490120 moves, 80 finished, 0 exhausted, 120 truncated
```

`finished 0` means the agent never reached a terminal state — the win path is
untested however green the run looks. That is exactly how the solitaire livelock
was spotted: every game hit the move ceiling and none ever ended.

The sliding puzzle truncates by design; random moves solve a 15-puzzle at a rate
indistinguishable from never, so its value is the per-move invariant, not
completion.

### Adding a game

Implement `PlayableGame` in `game_agents.dart` and add it to `allAgents()`. Make
`step` play *badly* — random legal moves, not good ones. A strong player visits a
narrow, sensible slice of the state space; a random one wanders into the corners
where the bugs live.

## Conventions

**Seed every source of randomness.** Rules take an injected `Random`; nothing calls
`Random()` internally where a test can see it. This is also what makes daily-challenge modes
possible later.

**Assert on intent, not on rendering.** `JpButton`'s press test reads `AnimatedScale.scale` — the
target the button is animating toward — rather than a rendered transform matrix that depends on how
far the animation has progressed at the moment of the assertion.

**Scope finders.** A test helper that counts numbers on screen will happily include the score, best
and move counters in the shell's stat bar. The 2048 helper reported four tiles on a two-tile board
until it was scoped to `Board2048View`.

**Dispose in the test body, not `addTearDown`.** `testWidgets` asserts no timers are pending
*before* tear-downs run, so a still-ticking `GameSession` fails the test even though it is cleaned
up a moment later.
