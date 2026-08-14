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
