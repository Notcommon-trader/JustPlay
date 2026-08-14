import 'package:flutter/widgets.dart';
import 'package:jp_ui/jp_ui.dart';

import 'word_search_view.dart';

/// Word search.
///
/// Score and time, no move counter: a "move" here would be one drag, and
/// counting drags would punish the player for looking — which is the entire
/// activity.
class WordSearchDefinition extends GameDefinition {
  const WordSearchDefinition({
    this.size = 10,
    this.wordCount = 8,
    this.packId,
    this.variantName = 'classic',
    this.seed,
  });

  /// A larger grid with more words. Not harder per word, but a long sitting.
  static const WordSearchDefinition large = WordSearchDefinition(
    size: 12,
    wordCount: 12,
    variantName: 'large',
  );

  final int size;
  final int wordCount;

  /// Null means a random subject each round.
  final String? packId;

  final String variantName;
  final int? seed;

  @override
  String get id => 'word_search_$variantName';

  @override
  String get nameKey => 'game.word_search.name';

  @override
  String get descriptionKey => 'game.word_search.description';

  @override
  GameCapabilities get capabilities => const GameCapabilities(
        showsScore: true,
        showsMoves: false,
        showsTimer: true,
      );

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return WordSearchView(
      session: session,
      size: size,
      wordCount: wordCount,
      packId: packId,
      seed: seed,
    );
  }
}
