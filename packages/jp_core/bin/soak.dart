import 'dart:io';

import 'package:jp_core/jp_core.dart';

/// Plays every game repeatedly and reports what happened.
///
/// The test suite runs a small soak on every commit. This is the same machinery
/// with the dial turned up, for when you actually want to hunt something:
///
///     dart run jp_core:soak
///     dart run jp_core:soak --games 5000
///     dart run jp_core:soak --games 20000 --seed 1000000
///
/// A different `--seed` explores a different part of the space, so a nightly run
/// with a rotating seed keeps finding new positions instead of re-testing the
/// same sixty games forever.
void main(List<String> arguments) {
  final games = _intFlag(arguments, '--games') ?? 500;
  final seed = _intFlag(arguments, '--seed') ?? 0;
  final maxMoves = _intFlag(arguments, '--max-moves') ?? 4000;

  stdout.writeln('Playing $games games per agent from seed $seed.\n');

  final started = DateTime.now();
  var totalMoves = 0;
  var failures = 0;

  for (final agent in allAgents()) {
    final agentStarted = DateTime.now();
    try {
      final report = soak(
        agent,
        games: games,
        startSeed: seed,
        maxMoves: maxMoves,
      );
      totalMoves += report.movesPlayed;

      final elapsed = DateTime.now().difference(agentStarted);
      stdout.writeln('  PASS  $report  [${elapsed.inMilliseconds}ms]');
    } on SoakFailure catch (failure) {
      failures++;
      stdout
        ..writeln('  FAIL  ${agent.name}')
        ..writeln(failure);
    }
  }

  final elapsed = DateTime.now().difference(started);
  stdout
    ..writeln()
    ..writeln(
      '$totalMoves moves in ${elapsed.inMilliseconds}ms, $failures failing agent(s).',
    );

  // Non-zero on failure, so this is usable as a CI step rather than something
  // somebody has to read.
  if (failures > 0) exit(1);
}

int? _intFlag(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1 || index + 1 >= arguments.length) return null;
  return int.tryParse(arguments[index + 1]);
}
