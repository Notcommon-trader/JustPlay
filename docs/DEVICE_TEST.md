# On-device test pass

**Nobody has run this app on a real phone.** Everything so far is the test
harness, a Windows desktop build, and an Android emulator. That is a real gap:
the emulator has already caught four visual defects the 20-odd golden tests
missed, and a physical device catches a different class again — the ones about
fingers, panels and heat.

This has to be done by someone holding a phone. It cannot be automated from here.

## Getting the build onto a phone

```bash
cd C:\dev\justplay\apps\timekiller
```

```bash
flutter build apk --release
```

The APK lands at `build/app/outputs/flutter-apk/app-release.apk` (44.5 MB — a fat
APK carrying every ABI; the Play bundle will be about a third of that per device).
Transfer it and install, or with the phone plugged in and USB debugging on:

```bash
flutter install --release
```

It is signed with debug keys, which is fine for sideloading and useless for Play.

---

## What only a real device tells you

### Touch and gesture — the highest-risk area

- [ ] **Solitaire drag.** The whole game rests on it. Does a card pick up on the
      first attempt? Does the run follow your finger or lag behind it? Can you
      drop accurately on a pile that is half-covered by your own hand?
- [ ] **Word Search drag.** Diagonals especially — can you select a diagonal word
      without the selection jumping to the row or column?
- [ ] **2048 swipes.** Do all four directions register from anywhere on the board,
      including a short flick?
- [ ] **Nonogram and Minesweeper cell taps.** Cells are small. Do you hit the one
      you meant, one-handed, thumb-only?
- [ ] **Minesweeper long-press to flag.** Does it fire before you expect it, or
      after you have given up?
- [ ] **Sudoku number pad.** Nine buttons across a phone width. Reachable?

### Layout on real hardware

- [ ] **Notch and cutout.** Nothing hidden behind the camera on any screen.
- [ ] **Gesture bar.** The Sudoku number pad and the Word Search word bank sit
      lowest — is either under the home indicator?
- [ ] **Rounded corners.** Cards and boards should not be clipped at the edges.
- [ ] **A small phone.** Everything so far assumes a 1080×2400-ish screen. Try
      something narrower and check Solitaire's seven columns and Sudoku's number
      pad, the two tightest layouts.
- [ ] **Large system font.** Accessibility → Font size at maximum. Which screens
      overflow?

### Performance

- [ ] **Sustained frame rate**, not just first impression. Play 2048 for two
      minutes and watch for stutter as tiles animate.
- [ ] **Solitaire drag smoothness** while a pile is fanned deep.
- [ ] **Cold start.** How long from tap to the home list? `main()` awaits storage
      before the first frame, so a slow device is where that shows.
- [ ] **Battery and heat** after fifteen minutes. Casual games are played in long
      sittings; a phone that gets warm gets uninstalled.

### Lifecycle

- [ ] **Background mid-game**, take a call, come back. The session should be
      paused, not lost, and the timer should not have run.
- [ ] **Rotate.** The app is locked to portrait — confirm it actually stays there.
- [ ] **Kill from recents and reopen.** Best scores must survive.
- [ ] **Dark mode.** Toggle the system theme with the app open.

## A known gap to check first

The Android **back button** appears to pop straight out of a game without the
"Quit this game?" confirmation that the close button shows — the shell wires
confirmation to its own control, not to a system back gesture. Verify on device;
if confirmed, it needs a `PopScope` in `GameShell`. Losing a half-finished sudoku
to a stray back-swipe is exactly the kind of thing that gets an app deleted.

## Recording what you find

Anything visual: screenshot it. Anything about feel — lag, mis-taps, a gesture
that needed two tries — write it down in the moment, because it will not
reproduce in a test and it will not be remembered accurately an hour later.
