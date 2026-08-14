import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_ui/jp_ui.dart';

import 'catalogue.dart';
import 'main.dart';

/// The game list.
///
/// Built to stay legible from three games to thirty: a scrolling list of cards
/// rather than a fixed grid, so adding entries never requires a layout rethink.
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.entries, super.key});

  final List<CatalogueEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  JpSpace.lg,
                  JpSpace.xxl,
                  JpSpace.lg,
                  JpSpace.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('JustPlay', style: theme.textTheme.displayMedium),
                    const SizedBox(height: JpSpace.xs),
                    Text(
                      'A few minutes to spare?',
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
              sliver: SliverList.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: JpSpace.md),
                itemBuilder: (context, index) => _GameCard(
                  entry: entries[index],
                  // Watched, not read: finishing a game notifies the store, and
                  // the new best is on the card before the player is back here.
                  record: GameRecordScope.of(context)
                      .recordFor(entries[index].definition.id),
                  // Staggered entry. Each card is delayed a little more than the
                  // one above, so the list assembles itself instead of appearing
                  // all at once — the cheapest way to make a list feel crafted.
                  //
                  // Capped: past the first screenful the delay is buying nothing
                  // (nobody is looking at card 20 on launch) and would make a
                  // card scrolled into view sit blank for over a second.
                  delay: Duration(milliseconds: 60 * (index > 6 ? 0 : index)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  const _GameCard({
    required this.entry,
    required this.record,
    required this.delay,
  });

  final CatalogueEntry entry;
  final GameRecord record;
  final Duration delay;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _visible = false;
  bool _pressed = false;
  Timer? _entrance;

  @override
  void initState() {
    super.initState();

    if (widget.delay == Duration.zero) {
      _visible = true;
      return;
    }

    // A Timer held in state rather than a bare Future.delayed. The first version
    // used the latter and outlived its widget: scrolling the list disposed cards
    // whose callback was still queued, which a `mounted` check makes harmless in
    // the app but leaves as a pending timer that fails any test touching this
    // screen.
    _entrance = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _entrance?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: JpDuration.normal,
      curve: JpCurve.enter,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.12),
        duration: JpDuration.normal,
        curve: JpCurve.enter,
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: GestureDetector(
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () => openGame(context, widget.entry),
            child: AnimatedScale(
              scale: _pressed ? 0.98 : 1,
              duration: JpDuration.instant,
              curve: JpCurve.standard,
              child: Container(
                padding: const EdgeInsets.all(JpSpace.lg),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: JpRadius.md,
                  boxShadow: JpElevation.low(scheme.shadow),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: JpRadius.sm,
                      ),
                      child: Icon(
                        widget.entry.icon,
                        color: scheme.onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: JpSpace.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.entry.name, style: theme.textTheme.titleLarge),
                          const SizedBox(height: JpSpace.xxs),
                          Text(
                            widget.entry.tagline,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.record.hasBeenPlayed) ...[
                            const SizedBox(height: JpSpace.xs),
                            _RecordLine(
                              record: widget.record,
                              showsScore:
                                  widget.entry.definition.capabilities.showsScore,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: JpSpace.sm),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of history under a game's tagline.
///
/// Shows the single most relevant number rather than everything known: a card
/// listing plays, wins, best score, best time and last played is a spreadsheet,
/// and nobody reads it. Games that keep score show the score; the rest show
/// their fastest win, and a game played but never won falls back to how often it
/// has been played.
class _RecordLine extends StatelessWidget {
  const _RecordLine({required this.record, required this.showsScore});

  final GameRecord record;
  final bool showsScore;

  String get _label {
    if (showsScore && record.bestScore > 0) return 'Best ${record.bestScore}';

    final best = record.bestTime;
    if (best != null) return 'Best ${_duration(best)}';

    return record.plays == 1 ? 'Played once' : 'Played ${record.plays} times';
  }

  static String _duration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return minutes == 0 ? '${seconds}s' : '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.emoji_events_outlined,
          size: 14,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: JpSpace.xxs),
        Text(
          _label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
