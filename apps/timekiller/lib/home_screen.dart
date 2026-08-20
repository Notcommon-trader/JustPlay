import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_ui/jp_ui.dart';

import 'catalogue.dart';
import 'games_screen.dart';
import 'sound_check.dart';
import 'journey/stage_definitions.dart';
import 'main.dart';

/// The front door: one thing to do.
///
/// The previous version showed a Journey card above a grid of ten games, which
/// made the two read as equal options and prompted the fair question of what the
/// Journey was even for. It was for removing the "what shall I play?" decision —
/// and it cannot do that while the decision is sitting underneath it.
///
/// So the run is the screen, and the catalogue is one deliberate tap away for
/// someone who wants a particular game. Free play is not hidden; it is just no
/// longer the thing you have to get past in order to start playing.
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.entries, super.key});

  final List<CatalogueEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final journey = JourneyScope.of(context);
    final stage = Journey.stageAt(journey.stage);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(JpSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: JpSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: Text('JustPlay', style: theme.textTheme.displaySmall),
                  ),
                  // Sound check. Present because four builds shipped mute and
                  // nothing in the app could say why — a failure to play is
                  // indistinguishable from the volume being down unless
                  // something reports it.
                  IconButton(
                    icon: const Icon(Icons.volume_up_outlined),
                    tooltip: 'Sound check',
                    onPressed: () =>
                        showSoundCheck(context, SoundScope.of(context)),
                  ),
                ],
              ),
              const SizedBox(height: JpSpace.xxs),
              Text(
                // Says what the app is, not what it contains. "Ten games" was a
                // stock list; this is a promise about how it plays.
                'Puzzles, one after another, for as long as you like.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),

              const Spacer(),
              _JourneyHero(journey: journey, stage: stage),
              const Spacer(),

              // Understated on purpose. It has to be findable, and it must not
              // compete with the thing above it.
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => GamesScreen(entries: entries),
                  ),
                ),
                icon: const Icon(Icons.grid_view_rounded),
                label: Text('Or pick one of ${entries.length} games'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The run, as the only real target on the screen.
class _JourneyHero extends StatelessWidget {
  const _JourneyHero({required this.journey, required this.stage});

  final JourneyProgress journey;
  final Stage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: journey.hasStarted
          ? 'Continue your run at stage ${journey.stage}'
          : 'Start a run',
      excludeSemantics: true,
      onTap: () => openJourney(context),
      child: GestureDetector(
        onTap: () => openJourney(context),
        child: Container(
          padding: const EdgeInsets.all(JpSpace.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.tertiary],
            ),
            borderRadius: JpRadius.lg,
            boxShadow: JpElevation.high(scheme.shadow),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                journey.hasStarted ? 'YOUR RUN' : 'START A RUN',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: JpTextSize.caption,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: JpSpace.sm),
              Text(
                'Stage ${journey.stage}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: JpTextSize.display,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: JpSpace.sm),

              // What a run *is*, for anyone who has never seen one. A number on
              // its own answers no question a new player is asking.
              Text(
                journey.hasStarted
                    ? 'Next up: ${stageGameName(stage.game)} · ${stage.goal.describe}'
                    : 'A different quick puzzle every stage. '
                        'Finish one and the next begins.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: JpTextSize.body,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: JpSpace.xl),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: JpSpace.xl,
                      vertical: JpSpace.md,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: JpRadius.full,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: scheme.primary, size: 24),
                        const SizedBox(width: JpSpace.xs),
                        Text(
                          journey.hasStarted ? 'Continue' : 'Play',
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: JpTextSize.body,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (journey.stars > 0)
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.white70, size: 20),
                        const SizedBox(width: JpSpace.xxs),
                        Text(
                          '${journey.stars}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: JpTextSize.body,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
