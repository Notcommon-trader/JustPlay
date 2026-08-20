import 'package:flutter/material.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_ui/jp_ui.dart';

import 'catalogue.dart';
import 'game_sheet.dart';
import 'game_tile.dart';

/// The full catalogue, one screen back from the front door.
///
/// Free play used to sit directly under the Journey card, which made the two
/// look like equal options and left the "what shall I play?" decision on screen
/// — the exact decision the Journey exists to remove. Moving the grid behind a
/// deliberate tap keeps it available for someone who wants a specific game
/// without offering it to someone who just wants to play.
class GamesScreen extends StatelessWidget {
  const GamesScreen({required this.entries, super.key});

  final List<CatalogueEntry> entries;

  @override
  Widget build(BuildContext context) {
    final records = GameRecordScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('All games')),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            JpSpace.lg,
            JpSpace.lg,
            JpSpace.lg,
            JpSpace.xxl,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: JpSpace.md,
            crossAxisSpacing: JpSpace.md,
            childAspectRatio: 0.92,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return GameTile(
              entry: entry,
              hasPlayed: entry.levels.any(
                (level) => records.recordFor(level.definition.id).hasBeenPlayed,
              ),
              delay: Duration(milliseconds: 40 * index),
              onTap: () => showGameSheet(context, entry),
            );
          },
        ),
      ),
    );
  }
}
