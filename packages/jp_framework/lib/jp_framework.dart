/// Platform services shared by every JustPlay app.
///
/// Sits between `jp_core` (pure rules) and `jp_ui` (widgets): anything that
/// touches the device — storage, settings, later consent and entitlements —
/// lives here behind a port, so a game or a screen never talks to a plugin
/// directly.
library;

export 'src/records/game_record.dart';
export 'src/records/game_record_scope.dart';
export 'src/records/game_record_store.dart';
export 'src/records/journey_progress.dart';
export 'src/storage/key_value_store.dart';
export 'src/storage/prefs_key_value_store.dart';
