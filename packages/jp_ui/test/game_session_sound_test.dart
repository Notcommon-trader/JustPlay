import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_ui/jp_ui.dart';

/// Records what it was asked to play, so a silent path is visible in a test.
class RecordingSounds implements SoundService {
  final List<Sfx> played = [];

  @override
  bool enabled = true;

  @override
  bool get isReady => true;

  @override
  Object? get lastError => null;

  @override
  Future<void> initialise() async {}

  @override
  void play(Sfx sound) => played.add(sound);

  @override
  Future<Object?> playAndReport(Sfx sound) async {
    played.add(sound);
    return null;
  }

  @override
  Future<void> dispose() async {}
}

/// Sound reaches the games through [GameSession], and these prove it stays
/// connected.
///
/// The audio worked and the app was still effectively silent, because it had
/// only ever been wired into the Journey's result panel — no board made a noise
/// while it was being played. "The sound system works" and "the game makes
/// sounds" are different claims, and only the second one matters.
void main() {
  test('a move is audible', () {
    final sounds = RecordingSounds();
    final session = GameSession(sounds: sounds);
    addTearDown(session.dispose);

    session.recordMove();
    expect(sounds.played, [Sfx.tap]);
  });

  test('scoring gets the rewarding sound, not the move sound', () {
    final sounds = RecordingSounds();
    final session = GameSession(sounds: sounds);
    addTearDown(session.dispose);

    session.addScore(100);
    expect(sounds.played, [Sfx.gain]);
  });

  test('scoring nothing makes no sound', () {
    // addScore(0) is a no-op the games call freely; it must not click.
    final sounds = RecordingSounds();
    final session = GameSession(sounds: sounds);
    addTearDown(session.dispose);

    session.addScore(0);
    expect(sounds.played, isEmpty);
  });

  test('winning and losing sound different', () {
    final won = RecordingSounds();
    final lost = RecordingSounds();

    GameSession(sounds: won)
      ..finish(GameOutcome.won)
      ..dispose();
    GameSession(sounds: lost)
      ..finish(GameOutcome.lost)
      ..dispose();

    expect(won.played, [Sfx.win]);
    expect(lost.played, [Sfx.lose]);
  });

  test('a game that ends twice only says so once', () {
    // finish is idempotent, and the sound has to sit inside that guard — a game
    // detecting its own end in two places must not play the chord twice.
    final sounds = RecordingSounds();
    final session = GameSession(sounds: sounds);
    addTearDown(session.dispose);

    session
      ..finish(GameOutcome.won)
      ..finish(GameOutcome.won);

    expect(sounds.played, [Sfx.win]);
  });

  test('a session with no sound service still works', () {
    // Every widget test in the repo builds one of these. A missing service must
    // never be a reason for a game to misbehave.
    final session = GameSession();
    addTearDown(session.dispose);

    session
      ..recordMove()
      ..addScore(10)
      ..finish(GameOutcome.won);

    expect(session.state.score, 10);
    expect(session.state.moves, 1);
  });
}
