import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_ui/jp_ui.dart';

import 'catalogue.dart';
import 'home_screen.dart';

Future<void> main() async {
  // Required before touching any plugin, and shared_preferences is one.
  WidgetsFlutterBinding.ensureInitialized();

  final records = GameRecordStore(store: PrefsKeyValueStore());
  // Loaded before the first frame. Records are a few hundred bytes, so this is
  // imperceptible — and it means the home screen never renders a best score of
  // zero and then corrects itself a frame later.
  await records.load();

  runApp(TimeKillerApp(records: records));
}

class TimeKillerApp extends StatelessWidget {
  const TimeKillerApp({required this.records, super.key});

  final GameRecordStore records;

  @override
  Widget build(BuildContext context) {
    return GameRecordScope(
      store: records,
      child: MaterialApp(
        title: 'JustPlay',
        debugShowCheckedModeBanner: false,
        theme: JpTheme.light(),
        darkTheme: JpTheme.dark(),
        // Follows the device. Dark mode is not a setting people go looking for —
        // it is an expectation that the app already matches the system.
        themeMode: ThemeMode.system,
        home: const HomeScreen(entries: appCatalogue),
      ),
    );
  }
}

/// Opens a game inside the shell.
///
/// Routing lives here rather than in the catalogue so a game never knows how it
/// was launched — the same definition can be opened from the home grid, a
/// "continue playing" card, or a deep link without changing.
void openGame(BuildContext context, CatalogueEntry entry) {
  // Read, not watch: pushing a route from a callback must not also subscribe the
  // screen that is about to be covered.
  final records = GameRecordScope.read(context);
  final gameId = entry.definition.id;

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => GameShell(
        definition: entry.definition,
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
  );
}
