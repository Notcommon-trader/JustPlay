import 'package:flutter/widgets.dart';

import '../storage/key_value_store.dart';

/// How far a player has come in the Journey.
///
/// Kept apart from [GameRecordStore]: a record is a personal best at one game,
/// and this is a position on a ladder. Merging them would mean the day a game
/// leaves the catalogue, someone's run resets.
class JourneyProgress extends ChangeNotifier {
  JourneyProgress({required this.store});

  static const String _stageKey = 'journey.stage';
  static const String _starsKey = 'journey.stars';

  final KeyValueStore store;

  int _stage = 1;
  int _stars = 0;

  /// The next stage to play. 1-based, and never goes backwards — a run is a
  /// record of distance travelled, not of where you happen to be standing.
  int get stage => _stage;

  /// Stars earned across the whole run.
  int get stars => _stars;

  bool get hasStarted => _stage > 1;

  Future<void> load() async {
    await store.initialise();
    _stage = int.tryParse(store.read(_stageKey) ?? '') ?? 1;
    _stars = int.tryParse(store.read(_starsKey) ?? '') ?? 0;
    notifyListeners();
  }

  /// Records that [stageNumber] was cleared for [stars].
  ///
  /// Takes the maximum rather than the latest, so replaying an early stage for a
  /// third star can never drag a player back down the ladder.
  Future<void> recordCleared(int stageNumber, int stars) async {
    final next = stageNumber + 1;
    if (next > _stage) _stage = next;
    _stars += stars;
    notifyListeners();

    await store.write(_stageKey, '$_stage');
    await store.write(_starsKey, '$_stars');
  }

  Future<void> reset() async {
    _stage = 1;
    _stars = 0;
    notifyListeners();

    await store.write(_stageKey, '1');
    await store.write(_starsKey, '0');
  }
}

/// Puts one [JourneyProgress] in scope.
class JourneyScope extends InheritedNotifier<JourneyProgress> {
  const JourneyScope({
    required JourneyProgress progress,
    required super.child,
    super.key,
  }) : super(notifier: progress);

  static JourneyProgress of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<JourneyScope>();
    assert(scope != null, 'No JourneyScope above this widget');
    return scope!.notifier!;
  }

  static JourneyProgress read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<JourneyScope>();
    assert(scope != null, 'No JourneyScope above this widget');
    return scope!.notifier!;
  }
}
