# JustPlay — Architecture

Flutter monorepo for publishing casual game apps to Android and iOS at a target cadence of two apps
per month.

The cadence is the requirement that drives every decision here. Two apps a month is only reachable
if an app is **content plus configuration on top of a shared framework** — never a project built
from scratch. Everything below exists to make app #2 onward cheap.

---

## 1. Repository layout

```
justplay/
  packages/
    jp_core/            Pure Dart. Game rules, scoring, no Flutter import.
    jp_framework/       The platform: DI, settings, theming, l10n, storage, consent.
    jp_monetization/    Ads, IAP, subscriptions. Isolated because it changes on vendor whim.
    jp_backend/         Auth, cloud sync, online play.
    jp_ui/              Design system: tokens, widgets, animations, game shell.
    jp_games/           The game catalogue. One folder per game.
  apps/
    timekiller/         App #1. Assembles framework + a subset of games.
    <app_2>/            App #2. Same framework, different games and branding.
  tooling/
    melos.yaml          Monorepo task runner
```

**Why a monorepo rather than one repo per app.** Two apps a month means a framework fix must reach
every app without a publish-and-bump dance across a dozen repositories. Melos gives one command to
test, analyse, and version everything.

**The dependency rule is one-directional and enforced:**

```
apps  ->  jp_games  ->  jp_ui         ->  jp_core
   \  ->  jp_framework                ->/
   \  ->  jp_monetization             ->/
   \  ->  jp_backend                  ->/
```

*Revised 2026-08-14.* `jp_ui` does **not** depend on `jp_framework`. The two meet in the app, not in
the design system: `GameShell` takes a `bestScore` in and reports a finished session out through
`onFinished`, and the app is what turns that into a saved record. Wiring storage into the shell would
have dragged a storage dependency into the widget tests of every game in the catalogue, which is a
steep price for saving one callback.

`jp_core` imports nothing from Flutter. That is what makes game logic testable in milliseconds
without a widget tree, and it is the single most valuable constraint in this document.

## 2. Why these boundaries

**`jp_core` has no Flutter import.** Rules, win detection, scoring, difficulty. Runs in plain Dart
tests, thousands per second. When a scoring bug appears, it is reproduced in a unit test rather than
by tapping through an app.

**`jp_monetization` is quarantined.** AdMob, RevenueCat and store policies change constantly, and
those changes must never ripple into game code. Games ask an interface — "may I show an interstitial
now?" — and know nothing about who answers.

**`jp_ui` owns everything visual.** Design tokens, themed widgets, the animation vocabulary, and the
game shell. This is where "modern looking" is won or lost, and it is deliberately a single package so
a visual upgrade lands in every app at once.

**`jp_games` holds each game as an independent unit** — logic in `jp_core`, presentation using
`jp_ui`. A game never imports another game. That is what makes "ship the same game in a different
app" a config line rather than a copy-paste.

## 3. The game shell — the core abstraction

Every game implements one interface. The shell owns everything that is identical across games, which
is most of what a casual game actually does.

```dart
abstract class GameDefinition {
  String get id;                    // stable; save keys and analytics depend on it
  String get nameKey;               // localization key, never a literal
  GameCategory get category;
  GameCapabilities get capabilities;

  Widget buildGame(BuildContext context, GameSession session);
  GameState createInitialState(GameConfig config);
}
```

The shell provides, once, for all ten games:

- Pause, resume, restart, quit-confirm
- Score, timer, and move counters with consistent presentation
- Game-over sheet, with best-score and streak comparison
- Tutorial / how-to-play overlay on first run
- Ad placement at natural breaks — the game never calls an ad SDK
- Statistics recording
- Save and restore of an in-progress game
- Haptics and sound hooks

**The rule: a new game writes rules and a board widget. Nothing else.** If a game needs to touch
pause, ads, or stats directly, the shell has a gap and the shell gets fixed — not the game.

## 4. Which of the ten games need a game loop

Most do not, and this matters: plain Flutter widgets look more modern with less effort than a canvas.

| Type | Rendering | Examples |
|---|---|---|
| **Turn-based, no loop** | Flutter widgets + implicit animation | 2048, sudoku, memory match, word search, solitaire, minesweeper, tic-tac-toe |
| **Timed, light loop** | Widgets + `AnimationController` | Reaction tap, speed-math, simon-says |
| **Continuous simulation** | **Flame** | Only if a game needs per-frame physics or many moving sprites |

Expect roughly 8 of 10 to be pure widgets. **Do not reach for Flame by default** — it opts out of
Flutter's widget layer, which is precisely the thing giving you a modern look for free.

## 5. State management

**Riverpod** throughout.

Chosen over Bloc because game state changes at high frequency (every tap, every tick) and Riverpod's
granular rebuilds avoid rebuilding a board when only a timer moved. Chosen over `setState` because
game state must survive navigation and be serialisable for save/restore.

Convention: game state is an immutable class with `copyWith`, driven by a `Notifier`. Immutability is
what makes undo, replay, and save/restore fall out almost free.

## 6. Offline first

Every game is fully playable with no network. This is non-negotiable — casual play happens on
commutes and in queues.

- **Local:** a `KeyValueStore` port in `jp_framework`, with a `shared_preferences` adapter today.

  *Revised 2026-08-14, from Isar.* What the app actually persists is one small JSON record per
  game — best score, best time, plays, wins, last played. A database would have bought build_runner,
  generated code, and native binaries in the Android and iOS builds against a need that has not
  arrived. The port is the point: when statistics grow real queries (per-day history, aggregates
  across games), only the adapter changes, because `GameRecordStore` and everything above it never
  learn how the bytes are stored. Isar remains the intended answer for that day.

- **Cloud:** Firestore, but only as a *sync* layer over local. The app never blocks on network.
- **Conflict rule:** last-write-wins per game, with best-score taking the maximum rather than the
  latest. A player who beats their record offline must not lose it to an older cloud value.
- **Online multiplayer** is a per-game capability, not a platform assumption. Most time-killers never
  need it.

## 7. Monetization

Three revenue paths, one gate.

```dart
abstract class EntitlementService {
  bool get isPremium;              // subscription or lifetime removes ads
  Stream<bool> get premiumChanges;
}
```

- **Ads (AdMob):** interstitials only at natural breaks — game over, never mid-game. Rewarded ads for
  hints and continues, which convert far better than forced interstitials in casual games.
- **IAP + subscriptions: RevenueCat.** Non-negotiable recommendation. It handles both stores' receipt
  validation, entitlement state, subscription lifecycle, and grace periods. Hand-rolling that across
  two stores is where small teams lose months.
- **Consent gates everything.** Same model as the previous project and it was right: nothing
  initialises before the player answers, and declining is as easy as accepting.

**Ad frequency lives in remote config, not code.** Tuning monetisation must never require a release.

## 8. Design system — how "modern" is actually achieved

This is the requirement most likely to be lost through drift, so it is mechanised:

- **Tokens, not literals.** Spacing on a 4pt scale, a fixed type ramp, one elevation set, one motion
  curve set. A hardcoded `EdgeInsets.all(13)` is a bug.
- **Material 3 as the base**, restyled — not shipped default, which reads as generic.
- **Motion is a first-class citizen.** Every state change animates: shared-axis screen transitions,
  scale-on-press, staggered list entry, celebratory game-over. This is the single biggest driver of
  perceived quality, and it is cheap in Flutter and expensive elsewhere.
- **Rive** for anything hand-crafted — celebration, empty states, tutorials.
- **Dark and light from day one**, plus dynamic type and reduced motion. Retrofitting accessibility is
  what the previous project had to do, and it cost a full pass over every screen.

## 9. Testing

Three layers, in the ratio that catches the most for the least time:

| Layer | Tool | Covers |
|---|---|---|
| Unit | `dart test` on `jp_core` | Rules, scoring, AI. Fast, exhaustive |
| Widget | `flutter_test` | Each game renders, accepts input, reaches game-over |
| Golden | `golden_toolkit` | **Catches visual regressions** |
| Integration | `integration_test` | Boot, consent, purchase, sync — the wiring |

**Golden tests are the direct answer to what went wrong on the last project**, where everything
compiled and passed while nobody had looked at the screen. A golden test fails when pixels change,
which is the only automated way to notice that a layout broke.

## 10. Release pipeline

- **Melos** for repo-wide test/analyse/version.
- **CI on GitHub Actions**: analyse, test, and golden-diff on every PR.
- **Fastlane** for store upload, screenshots, and metadata. At two apps a month, manual Console work
  is the bottleneck; metadata belongs in version control.
- **Internal testing track first, always.** Never straight to production.

### iOS without a Mac — decided 2026-08-10

There is no Mac on the development machine, and iOS cannot be built, signed, or submitted from
Windows. The strategy is **Android-first, iOS-ready**:

1. Ship app #1 to Android only. That is the fast local loop and the larger market.
2. Write cross-platform from day one regardless — no Android-only APIs, respect safe areas, and
   include iPhone aspect ratios in golden tests. The cost of staying portable is near zero; the cost
   of retrofitting it is a full pass over every screen.
3. Add **Codemagic** for iOS when app #1 is stable. Its automatic code signing provisions
   certificates from an App Store Connect API key, which is what makes Mac-free iOS release
   practical rather than a workaround.
4. Buy a used Mac mini once iOS revenue justifies it. At this cadence it pays back inside a year and
   removes the real risk below.

**Accepted risk:** without an iOS device, iOS ships unvalidated by eye. Safe areas, notch insets,
keyboard behaviour and font metrics differ from Android, and the feedback loop for an iOS-only bug
is a CI round trip rather than a hot reload. **Acquire at least one iPhone or iPad before the first
iOS submission** — golden tests catch layout regressions, not platform feel.

**Also required and independent of CI:** Apple Developer Program membership, $99/year.

---

## Decisions deliberately deferred

- **Firebase vs Supabase** for backend. Firebase is the safer default given AdMob and Crashlytics are
  already Google; Supabase is cheaper at scale and less lock-in. Decide before writing `jp_backend`.
- **Which ten games** ship in app #1. Architecture is agnostic; the mix affects the schedule.
- **Free vs paid tier boundary.** Affects the entitlement model but not its shape.
