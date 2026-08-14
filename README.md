# JustPlay

A Flutter monorepo for shipping casual game apps to Android and iOS — a shared framework plus a
catalogue of games, assembled into an app per release.

`timekiller` is app #1: ten games meant to absorb a few minutes or a few hours.

## Getting started

```bash
flutter pub get                 # one resolve for the whole workspace
dart analyze
cd apps/timekiller && flutter run -d windows
```

Flutter 3.44.9 / Dart 3.12.2. Pub workspaces, so every package resolves from the root — there is no
per-package `pub get` and no Melos to install.

## Layout

```
packages/
  jp_core/        Pure Dart game rules. No Flutter import, ever.
  jp_framework/   Platform services: storage, records. Settings and consent to come.
  jp_ui/          Design system: tokens, widgets, the game shell.
  jp_games/       The catalogue. One folder per game; games never import each other.
apps/
  timekiller/     App #1. Assembles the framework and a subset of games.
```

Adding a game is a rules file in `jp_core`, a view and definition in `jp_games`, and one entry in the
app's `catalogue.dart`. Nothing in the shell or the home screen needs to know it happened — that is
the mechanism that keeps a second app cheap.

## Tests

```bash
cd packages/jp_core      && dart test
cd packages/jp_framework && flutter test
cd packages/jp_ui        && flutter test
cd packages/jp_games     && flutter test
cd apps/timekiller       && flutter test
```

Golden images are generated on Windows and are platform-sensitive, which is why CI runs the suite on
a Windows runner. See [docs/TESTING.md](docs/TESTING.md) before regenerating any.

## Documents

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — layout, boundaries, state, offline, monetisation
- [docs/DECISIONS.md](docs/DECISIONS.md) — the calls that were genuinely open, and what would reopen them
- [docs/TESTING.md](docs/TESTING.md) — the five layers and how to work with goldens

## Not in place yet

Version control (this tree is not a git repository), monetisation, backend, localization, and any
run on real Android or iOS hardware.
