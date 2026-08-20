import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_ui/jp_ui.dart';

import 'catalogue.dart';
import 'first_play_coach.dart';
import 'game_theme.dart';
import 'home_screen.dart';
import 'journey/journey_screen.dart';

Future<void> main() async {
  // Required before touching any plugin, and shared_preferences is one.
  WidgetsFlutterBinding.ensureInitialized();

  // One store behind both: records and journey progress are different kinds of
  // fact, but they live on the same disk.
  final store = PrefsKeyValueStore();
  final records = GameRecordStore(store: store);
  final journey = JourneyProgress(store: store);

  // Loaded before the first frame. Both are a few hundred bytes, so this is
  // imperceptible — and it means the home screen never renders "Stage 1" and
  // then corrects itself to stage 40 a frame later.
  await records.load();
  await journey.load();

  // Not awaited: sound is the least important thing on screen, and a device that
  // is slow to hand over an audio route must not delay the first frame.
  final sounds = ToneSounds();
  unawaited(sounds.initialise());

  runApp(TimeKillerApp(records: records, journey: journey, sounds: sounds));
}

class TimeKillerApp extends StatelessWidget {
  const TimeKillerApp({
    required this.records,
    this.journey,
    this.sounds,
    super.key,
  });

  final GameRecordStore records;

  /// Null in tests that only care about records. A run that has never been
  /// started is the correct default rather than a reason to fail.
  final JourneyProgress? journey;

  /// Null in tests, which run silent.
  final SoundService? sounds;

  @override
  Widget build(BuildContext context) {
    final progress = journey ?? JourneyProgress(store: InMemoryKeyValueStore());

    return GameRecordScope(
      store: records,
      child: JourneyScope(
        progress: progress,
        child: SoundScope(
          sounds: sounds ?? SilentSounds(),
          child: MaterialApp(
          title: 'JustPlay',
          debugShowCheckedModeBanner: false,
          theme: JpTheme.light(),
          darkTheme: JpTheme.dark(),
          // Follows the device. Dark mode is not a setting people go looking
          // for — it is an expectation that the app already matches the system.
          themeMode: ThemeMode.system,
            home: const HomeScreen(entries: appCatalogue),
          ),
        ),
      ),
    );
  }
}

/// Puts the app's [SoundService] in scope.
///
/// An InheritedWidget rather than a global: a test builds the app with
/// [SilentSounds] and gets silence everywhere, with no static to reset between
/// tests and no way for one test to leak audio into the next.
class SoundScope extends InheritedWidget {
  const SoundScope({required this.sounds, required super.child, super.key});

  final SoundService sounds;

  static SoundService of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SoundScope>();
    return scope?.sounds ?? SilentSounds();
  }

  @override
  bool updateShouldNotify(SoundScope oldWidget) => oldWidget.sounds != sounds;
}

/// Starts or resumes the Journey.
///
/// Pushed full-screen with no title bar of its own: the run owns the whole
/// screen, and the only way out is the close button in its header.
void openJourney(BuildContext context) {
  final journey = JourneyScope.read(context);
  final sounds = SoundScope.of(context);

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => JourneyScreen(
        startAt: journey.stage,
        sounds: sounds,
        onStageReached: (stage, stars) =>
            unawaited(journey.recordCleared(stage, stars)),
      ),
    ),
  );
}

/// Opens a game inside the shell, at [level].
///
/// Routing lives here rather than in the catalogue so a game never knows how it
/// was launched — the same definition can be opened from the home grid, a
/// "continue playing" card, or a deep link without changing.
void openGame(BuildContext context, CatalogueEntry entry, GameLevel level) {
  // Read, not watch: pushing a route from a callback must not also subscribe the
  // screen that is about to be covered.
  final records = GameRecordScope.read(context);
  final gameId = level.definition.id;
  final brightness = Theme.of(context).brightness;
  final sounds = SoundScope.of(context);

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Theme(
        // The game's own colour, all the way to the board — and the *same*
        // colour, not a palette's interpretation of it. See gameTheme.
        data: gameTheme(entry.colour, brightness),
        child: GameShell(
        // Games opened from the catalogue were silent even after the Journey had
        // sound: audio was wired into the run's result panel only, never into
        // the boards themselves.
        sounds: sounds,
        accent: gameColourFor(
          entry.colour,
          gameTheme(entry.colour, brightness).colorScheme,
          brightness,
        ),
        // Only on a game nobody has played. Someone who already knows sudoku
        // should never meet a tutorial, and `plays` is exactly that knowledge.
        boardWrapper: (context, board) => FirstPlayCoach(
          moves: entry.coachMoves,
          accent: entry.colour,
          enabled: !records.recordFor(gameId).hasBeenPlayed,
          child: board,
        ),
        definition: level.definition,
        title: entry.name,
        bestScore: records.bestScoreFor(gameId),
        onFinished: (state) {
          // `unawaited` rather than a dropped future: this repo treats a silently
          // discarded future as an error, because in ad, purchase and sync code
          // it means "the thing never happened". Saying so out loud keeps the
          // rule useful and the exceptions visible. Safe here — the store has
          // already updated in memory and notified before the disk write.
          unawaited(records.recordSession(gameId, state));
        },
        onExit: () => Navigator.of(context).pop(),
        ),
      ),
    ),
  );
}
