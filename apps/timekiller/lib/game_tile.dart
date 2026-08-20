import 'package:flutter/material.dart';
import 'package:jp_ui/jp_ui.dart';

import 'catalogue.dart';
class GameTile extends StatefulWidget {
  const GameTile({
    required this.entry,
    required this.hasPlayed,
    required this.delay,
    required this.onTap,
    super.key,
  });

  final CatalogueEntry entry;
  final bool hasPlayed;
  final Duration delay;

  /// What the tile opens. Passed in rather than assumed, so the same tile can
  /// front a catalogue sheet here and something else elsewhere.
  final VoidCallback onTap;

  @override
  State<GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<GameTile> {
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

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A gradient rather than a flat fill. One colour reads as a category chip;
    // two reads as a surface with light falling on it, which is the difference
    // between a form control and something that looks made.
    //
    // **Dimmed in dark mode.** The first version used the raw colour in both
    // brightnesses, which put ten full-saturation blocks against a near-black
    // page â€” the exact combination that glares at night. Pulling the tile toward
    // the surface keeps each game's hue identifiable while taking the burn out
    // of it; the identity survives the dimming because hue, not intensity, is
    // what tells Minesweeper from Solitaire.
    final base = isDark
        ? Color.lerp(entry.colour, scheme.surface, 0.30)!
        : entry.colour;
    final dark = Color.lerp(base, Colors.black, isDark ? 0.34 : 0.28)!;

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
          onTap: () => widget.onTap(),
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: GestureDetector(
              onTapCancel: () => setState(() => _pressed = false),
              onTap: () => widget.onTap(),
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
                          style: TextStyle(
                            // 85%, not full white. Pure white on a saturated
                            // ground is the harshest pairing on a screen, and
                            // secondary text does not need to shout. A tinted
                            // grey would read as dirty here, so the softening is
                            // in the alpha rather than the hue.
                            color: Colors.white.withValues(alpha: 0.85),
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