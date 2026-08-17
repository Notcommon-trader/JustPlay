import 'package:flutter/material.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_ui/jp_ui.dart';

import 'catalogue.dart';
import 'game_sheet.dart';

/// The game grid.
///
/// A two-column grid of coloured tiles, not a list of rows. Three reasons, all
/// from playing the previous version on a phone:
///
/// **Ten fit where twenty-one did not.** Variants moved inside their game, so
/// the whole catalogue is now two thumb-scrolls rather than five, and no game
/// goes unnoticed at the bottom.
///
/// **Colour is what makes it read as a game.** Every row used to be the same
/// grey card with the same indigo icon, which looked like a settings screen and
/// was described, accurately, as boring. Each game now owns a colour and carries
/// it into its own board.
///
/// **A tile is a target, a row is a line of text.** Big, obviously-tappable
/// blocks suit a game; dense rows suit a directory.
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.entries, super.key});

  final List<CatalogueEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final records = GameRecordScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  JpSpace.lg,
                  JpSpace.xl,
                  JpSpace.lg,
                  JpSpace.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('JustPlay', style: theme.textTheme.displaySmall),
                    const SizedBox(height: JpSpace.xxs),
                    Text(
                      'Ten games. A few minutes or a few hours.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                JpSpace.lg,
                0,
                JpSpace.lg,
                JpSpace.xxl,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: JpSpace.md,
                  crossAxisSpacing: JpSpace.md,
                  childAspectRatio: 0.92,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = entries[index];
                    return _GameTile(
                      entry: entry,
                      // Best across every level of the game, so a tile can say
                      // "you have played this" without picking a level first.
                      hasPlayed: entry.levels.any(
                        (level) => records.recordFor(level.definition.id).hasBeenPlayed,
                      ),
                      delay: Duration(milliseconds: 40 * index),
                    );
                  },
                  childCount: entries.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTile extends StatefulWidget {
  const _GameTile({
    required this.entry,
    required this.hasPlayed,
    required this.delay,
  });

  final CatalogueEntry entry;
  final bool hasPlayed;
  final Duration delay;

  @override
  State<_GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<_GameTile> {
  bool _visible = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    // A gradient rather than a flat fill. One colour reads as a category chip;
    // two reads as a surface with light falling on it, which is the difference
    // between a form control and something that looks made.
    final dark = Color.lerp(entry.colour, Colors.black, 0.28)!;

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: JpDuration.normal,
      curve: JpCurve.enter,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.1),
        duration: JpDuration.normal,
        curve: JpCurve.enter,
        child: Semantics(
          button: true,
          label: '${entry.name}. ${entry.tagline}',
          excludeSemantics: true,
          onTap: () => showGameSheet(context, entry),
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: GestureDetector(
              onTapCancel: () => setState(() => _pressed = false),
              onTap: () => showGameSheet(context, entry),
              child: AnimatedScale(
                scale: _pressed ? 0.96 : 1,
                duration: JpDuration.instant,
                curve: JpCurve.standard,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [entry.colour, dark],
                    ),
                    borderRadius: JpRadius.lg,
                    boxShadow: JpElevation.medium(dark),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(JpSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(entry.icon, color: Colors.white, size: 34),
                            const Spacer(),
                            // A quiet mark, not a badge with a number. It says
                            // "you have been here" and nothing more.
                            if (widget.hasPlayed)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white70,
                                size: 18,
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          entry.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: JpTextSize.title,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: JpSpace.xxs),
                        Text(
                          entry.tagline,
                          style: const TextStyle(
                            // White at 85% rather than a second colour: on a
                            // saturated tile any tinted grey reads as dirty.
                            color: Colors.white,
                            fontSize: JpTextSize.caption,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
