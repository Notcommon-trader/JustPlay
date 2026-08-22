import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_ui/jp_ui.dart';

import '../game_theme.dart';
import 'stage_definitions.dart';

/// The Journey: one stage after another, without leaving this screen.
///
/// **Nothing here returns to a menu.** Finishing a stage replaces the board in
/// place and starts the next one; failing offers a retry under the same thumb.
/// Every return to the home grid is a decision, and every decision is a chance
/// to stop — which is the thing that actually ends a long session, well before
/// boredom does.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({
    required this.startAt,
    this.onStageReached,
    this.sounds,
    super.key,
  });

  /// Where to resume. 1 for a new run.
  final int startAt;

  /// Null in tests, which run silent. A missing sound service must never be a
  /// reason for a game not to work.
  final SoundService? sounds;

  /// Called as each stage begins, so progress can be saved.
  final void Function(int stageNumber, int stars)? onStageReached;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  late int _number = widget.startAt;
  late Stage _stage = Journey.stageAt(_number);

  GameSession? _session;

  /// Attempts at the current stage. Drives both a fresh board on retry and the
  /// quiet difficulty drop after three failures.
  int _attempt = 0;

  /// Set once a stage resolves, so a session that keeps ticking after the goal
  /// was met cannot resolve it twice.
  bool _resolved = false;
  bool _passed = false;
  int _stars = 0;

  @override
  void initState() {
    super.initState();
    _beginStage();
  }

  @override
  void dispose() {
    _disposeSession();
    super.dispose();
  }

  void _disposeSession() {
    _session?.removeListener(_onSessionChanged);
    _session?.dispose();
    _session = null;
  }

  void _beginStage() {
    _disposeSession();

    final definition = _definition;
    final session = GameSession(
      tracksTime: definition.capabilities.showsTimer,
      // Every move, merge and match in the run is audible through this.
      sounds: widget.sounds,
    )..addListener(_onSessionChanged);

    setState(() {
      _resolved = false;
      _passed = false;
      _stars = 0;
      _session = session;
    });

    session.start();
  }

  /// After three failed attempts the stage quietly gets easier.
  ///
  /// Announcing it would tell the player they are being helped, which turns a
  /// rescue into an insult. A wall ends the sitting, and nothing else about this
  /// design matters if the player is stuck.
  Stage get _effectiveStage => _attempt < 3
      ? _stage
      : Stage(
          number: _stage.number,
          game: _stage.game,
          goal: _stage.goal,
          difficulty: (_stage.difficulty - 1).clamp(0, 6),
          stretch: _stage.stretch,
        );

  GameDefinition get _definition =>
      definitionFor(_effectiveStage, attempt: _attempt);

  void _onSessionChanged() {
    final session = _session;
    if (session == null || _resolved) return;

    final state = session.state;

    // Checked on every change, not only on finish. A goal like "open 20 squares"
    // is met mid-game and the stage should end right there — waiting for the
    // whole board would turn a 90-second stage into a five-minute one.
    if (_stage.goal.isMet(state)) {
      _resolve(passed: true, stars: _stage.starsFor(state));
      return;
    }

    if (state.isFinished) {
      _resolve(passed: false, stars: 0);
    }
  }

  void _resolve({required bool passed, required int stars}) {
    _session?.pause();
    setState(() {
      _resolved = true;
      _passed = passed;
      _stars = stars;
    });

    final sounds = widget.sounds;
    if (sounds == null) return;

    sounds.play(passed ? Sfx.win : Sfx.lose);

    // Stars land one at a time, after the win chord rather than under it. A
    // reward arriving in pieces reads as more than the same reward arriving at
    // once — it is the cheapest trick in the genre and it works.
    for (var i = 0; i < stars; i++) {
      unawaited(
        Future<void>.delayed(
          Duration(milliseconds: 420 + i * 160),
          () {
            if (mounted) sounds.play(Sfx.star);
          },
        ),
      );
    }
  }

  void _next() {
    widget.onStageReached?.call(_number, _stars);
    setState(() {
      _number++;
      _stage = Journey.stageAt(_number);
      _attempt = 0;
    });
    _beginStage();
  }

  void _retry() {
    setState(() => _attempt++);
    _beginStage();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;
    final colour = Color(stageColourValue(_stage.game));
    final theme = gameTheme(colour, brightness);

    return Theme(
      data: theme,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Rebuilt on every session change, so the running total in the
              // header tracks the board rather than being set once and forgotten.
              ListenableBuilder(
                listenable: session,
                builder: (context, _) => _StageHeader(
                  stage: _stage,
                  colour: colour,
                  state: session.state,
                  onQuit: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: session,
                        builder: (context, _) => _definition.buildBoard(
                          context,
                          session,
                        ),
                      ),
                    ),
                    if (_resolved)
                      _StageResult(
                        passed: _passed,
                        stars: _stars,
                        // The next stage is named before the player has decided
                        // whether to stop. Their eye should land on what is
                        // coming, not on a way out.
                        next: Journey.stageAt(_number + 1),
                        attempt: _attempt,
                        onPrimary: _passed ? _next : _retry,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stage number, game and objective, in one line each.
class _StageHeader extends StatelessWidget {
  const _StageHeader({
    required this.stage,
    required this.colour,
    required this.state,
    required this.onQuit,
  });

  final Stage stage;
  final Color colour;
  final GameSessionState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colour,
      padding: const EdgeInsets.fromLTRB(
        JpSpace.sm,
        JpSpace.sm,
        JpSpace.lg,
        JpSpace.md,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onQuit,
            tooltip: 'Leave the run',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stage ${stage.number} · ${stageGameName(stage.game)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: JpTextSize.caption,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                // The objective, in the largest type on the header. A player who
                // does not know what they are being asked cannot be trying.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        stage.goal.describe,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: JpTextSize.title,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                    // The running total. A target announced once and never
                    // mentioned again leaves the player unable to tell whether
                    // they are nearly there or nowhere near — and being close is
                    // most of the reason to keep going.
                    Text(
                      stage.goal.progress(state),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: JpTextSize.label,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: JpSpace.xs),
                ClipRRect(
                  borderRadius: JpRadius.full,
                  child: LinearProgressIndicator(
                    value: stage.goal.fraction(state),
                    minHeight: 5,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What sits over the board between stages.
///
/// Deliberately small and low: it covers the board rather than replacing it, the
/// button falls under a thumb, and the next stage is already named on it.
class _StageResult extends StatelessWidget {
  const _StageResult({
    required this.passed,
    required this.stars,
    required this.next,
    required this.attempt,
    required this.onPrimary,
  });

  final bool passed;
  final int stars;
  final Stage next;
  final int attempt;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: scheme.scrim.withValues(alpha: 0.5),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(JpSpace.lg),
            padding: const EdgeInsets.all(JpSpace.xl),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: JpRadius.lg,
              boxShadow: JpElevation.high(scheme.shadow),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (passed) ...[
                  Row(
                    children: [
                      for (var i = 1; i <= 3; i++)
                        Icon(
                          i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: i <= stars
                              ? scheme.primary
                              : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                          size: 32,
                        ),
                    ],
                  ),
                  const SizedBox(height: JpSpace.sm),
                  Text('Stage clear', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: JpSpace.xs),
                  Text(
                    'Next: ${stageGameName(next.game)} · ${next.goal.describe}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ] else ...[
                  Text('Not this time', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: JpSpace.xs),
                  Text(
                    // No scolding, and no mention of the attempt count — a player
                    // who has failed three times knows.
                    'Fresh board, same goal.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: JpSpace.lg),
                JpButton(
                  label: passed ? 'Next stage' : 'Try again',
                  size: JpButtonSize.large,
                  expand: true,
                  onPressed: onPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
