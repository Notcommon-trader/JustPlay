import 'package:flutter/material.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_ui/jp_ui.dart';

import 'catalogue.dart';
import 'how_to_demo.dart';
import 'main.dart';

/// Opens the sheet for [entry]: what the game is, how it is played, and at which
/// level.
///
/// A step between the grid and the board, which the previous build did not have.
/// Tapping a game went straight into a board with no explanation, so a player
/// who did not already know nonograms met a grid of numbers and left. Four lines
/// of rules is the difference between a game someone tries and one they skip.
Future<void> showGameSheet(BuildContext context, CatalogueEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // The sheet wears the game's colour, so the identity established on the tile
    // carries through to the board rather than resetting at every screen.
    builder: (context) => _GameSheet(entry: entry),
  );
}

class _GameSheet extends StatefulWidget {
  const _GameSheet({required this.entry});

  final CatalogueEntry entry;

  @override
  State<_GameSheet> createState() => _GameSheetState();
}

class _GameSheetState extends State<_GameSheet> {
  late GameLevel _level = widget.entry.defaultLevel;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final brightness = Theme.of(context).brightness;
    final theme = brightness == Brightness.dark
        ? JpTheme.dark(seed: entry.colour)
        : JpTheme.light(seed: entry.colour);
    final scheme = theme.colorScheme;

    final records = GameRecordScope.of(context);
    final record = records.recordFor(_level.definition.id);
    final capabilities = _level.definition.capabilities;

    return Theme(
      data: theme,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            JpSpace.lg,
            0,
            JpSpace.lg,
            JpSpace.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: entry.colour,
                      borderRadius: JpRadius.md,
                    ),
                    child: Icon(entry.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: JpSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entry.name, style: theme.textTheme.headlineSmall),
                        Text(
                          entry.tagline,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: JpSpace.xl),

              _SectionLabel('How to play', scheme: scheme),
              const SizedBox(height: JpSpace.sm),

              // The animation first, and the words after. Written instructions
              // get skipped — people look at a picture and try it — so the
              // gesture is shown before it is described.
              HowToDemo(script: entry.demo(scheme), accent: entry.colour),
              const SizedBox(height: JpSpace.lg),

              for (final step in entry.howToPlay)
                Padding(
                  padding: const EdgeInsets.only(bottom: JpSpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: JpRadius.sm,
                        ),
                        child: Icon(
                          step.icon,
                          size: 18,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: JpSpace.md),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: JpSpace.xs),
                          child: Text(
                            step.text,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (entry.levels.length > 1) ...[
                const SizedBox(height: JpSpace.sm),
                _SectionLabel('Level', scheme: scheme),
                const SizedBox(height: JpSpace.sm),
                Wrap(
                  spacing: JpSpace.sm,
                  runSpacing: JpSpace.sm,
                  children: [
                    for (final level in entry.levels)
                      ChoiceChip(
                        label: Text(level.label),
                        selected: level == _level,
                        onSelected: (_) => setState(() => _level = level),
                        // The game's own colour when chosen. Material's default
                        // selected chip is `secondaryContainer`, which in this
                        // palette is a desaturated slate — it reads as disabled
                        // rather than selected, which is the opposite of what a
                        // chosen difficulty should look like.
                        selectedColor: entry.colour,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: level == _level
                              ? Colors.white
                              : scheme.onSurfaceVariant,
                          fontWeight:
                              level == _level ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                if (_level.detail != null) ...[
                  const SizedBox(height: JpSpace.sm),
                  Text(
                    _level.detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],

              // Only shown once there is something to show. "Best: 0" on a game
              // nobody has played is noise pretending to be information.
              if (record.hasBeenPlayed) ...[
                const SizedBox(height: JpSpace.lg),
                _SectionLabel('Your record', scheme: scheme),
                const SizedBox(height: JpSpace.sm),
                Row(
                  children: [
                    if (capabilities.showsScore)
                      _Stat(label: 'Best', value: '${record.bestScore}'),
                    if (record.bestTime != null)
                      _Stat(label: 'Fastest', value: _time(record.bestTime!)),
                    if (record.bestMoves != null)
                      _Stat(label: 'Fewest moves', value: '${record.bestMoves}'),
                    _Stat(label: 'Played', value: '${record.plays}'),
                  ],
                ),
              ],

              const SizedBox(height: JpSpace.xl),
              JpButton(
                label: 'Play',
                size: JpButtonSize.large,
                expand: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  openGame(context, entry, _level);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _time(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.scheme});

  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: JpTextSize.caption,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
