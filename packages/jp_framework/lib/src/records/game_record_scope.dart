import 'package:flutter/widgets.dart';

import 'game_record_store.dart';

/// Puts one [GameRecordStore] in scope for the whole app.
///
/// An [InheritedNotifier] rather than a Riverpod provider: this is a single
/// long-lived object with no derived state, and it is the exact thing
/// [InheritedNotifier] exists for. Riverpod earns its place when providers start
/// depending on each other — entitlements gating ads gating the catalogue — and
/// adding it for one store would be architecture ahead of need.
///
/// Widgets that call [of] rebuild when a record changes, which is what makes a
/// new best score appear on the home screen the moment the player earns it.
class GameRecordScope extends InheritedNotifier<GameRecordStore> {
  const GameRecordScope({
    required GameRecordStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  /// The store, rebuilding the caller when records change.
  static GameRecordStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GameRecordScope>();
    assert(scope != null, 'No GameRecordScope above this widget');
    return scope!.notifier!;
  }

  /// The store without subscribing. For callbacks that write a record and do not
  /// care about being rebuilt — subscribing there would rebuild a screen that is
  /// already going away.
  static GameRecordStore read(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<GameRecordScope>();
    assert(scope != null, 'No GameRecordScope above this widget');
    return scope!.notifier!;
  }
}
