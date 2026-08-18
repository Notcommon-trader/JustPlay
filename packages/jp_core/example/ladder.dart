// This is a command-line tool whose entire job is to print. The lint is right
// about library code and wrong about a script you run to read its output.
// ignore_for_file: avoid_print

import 'package:jp_core/jp_core.dart';

/// Prints the Journey ladder, so the pacing can be judged as a list before any
/// of it is built as a screen.
///
///   dart run example/ladder.dart [count]
///
/// The pacing is the product. Reading forty stages in a terminal costs a minute
/// and catches things no unit test will — three word searches in five stages, a
/// difficulty step that lands in the wrong place, a run of goals that all say
/// the same thing.
void main(List<String> args) {
  final count = args.isEmpty ? 40 : int.parse(args.first);

  var lastChapter = 0;
  for (final stage in Journey.ladder(count)) {
    if (stage.chapter != lastChapter) {
      lastChapter = stage.chapter;
      print('\n── Chapter $lastChapter ${'─' * 44}');
    }

    final unlocked = Journey.unlockedAt(stage.number);
    final stretch = stage.stretch == null ? '' : '   ★ ${stage.stretch!.describe}';

    print(
      '${stage.number.toString().padLeft(3)}  '
      '${stage.game.name.padRight(14)} '
      'd${stage.difficulty}  '
      '${stage.goal.describe.padRight(22)}'
      '${unlocked == null ? '' : '  NEW: ${unlocked.name}'}'
      '$stretch',
    );
  }
}
