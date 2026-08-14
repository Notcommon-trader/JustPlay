import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// Key for the tap surface, so tests do not have to guess at coordinates.
const ValueKey<String> reactionSurfaceKey = ValueKey('reaction-surface');

/// What the player is currently looking at.
enum _Phase {
  /// Between rounds. Tap to arm the next one.
  idle,

  /// Armed and waiting for the target. Tapping now is a false start.
  waiting,

  /// Target showing. Tap as fast as possible.
  go,

  /// Feedback after a round, before returning to idle.
  result,
}

/// Reaction: tap the moment the screen turns green.
///
/// The only game in the catalogue with no board. It exists partly for variety —
/// five grids in a row is a monotonous app — and partly because it is the one
/// game where the clock is the content rather than a running total.
class ReactionView extends StatefulWidget {
  const ReactionView({
    required this.session,
    this.rounds = 5,
    this.seed,
    super.key,
  });

  final GameSession session;
  final int rounds;
  final int? seed;

  @override
  State<ReactionView> createState() => _ReactionViewState();
}

class _ReactionViewState extends State<ReactionView> {
  late ReactionRun _run = ReactionRun.fresh(totalRounds: widget.rounds);
  late Random _random = _newRandom();

  _Phase _phase = _Phase.idle;
  Timer? _armTimer;
  Timer? _resultTimer;

  /// Set when the target appears. Reaction time is measured from here rather
  /// than from a frame callback, so a dropped frame does not inflate the score.
  DateTime? _targetShownAt;

  int? _lastReactionMs;
  bool _lastWasFalseStart = false;

  /// The wait before the target appears. Randomised so the player cannot learn
  /// a rhythm and pre-empt it — a fixed delay turns this into a metronome test.
  static const Duration _minWait = Duration(milliseconds: 1200);
  static const int _extraWaitRangeMs = 2300;

  /// How long feedback stays up before the next round can be armed.
  static const Duration _resultLinger = Duration(milliseconds: 900);

  Random _newRandom() => widget.seed != null ? Random(widget.seed) : Random();

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    // Both timers can be in flight when the player quits mid-round.
    _armTimer?.cancel();
    _resultTimer?.cancel();
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (widget.session.state.status == GameStatus.ready) {
      _armTimer?.cancel();
      _resultTimer?.cancel();
      setState(() {
        _random = _newRandom();
        _run = ReactionRun.fresh(totalRounds: widget.rounds);
        _phase = _Phase.idle;
        _lastReactionMs = null;
        _lastWasFalseStart = false;
      });
      widget.session.start();
    }
  }

  void _onTap() {
    if (!widget.session.state.isPlaying) return;

    switch (_phase) {
      case _Phase.idle:
        _arm();
      case _Phase.waiting:
        _registerFalseStart();
      case _Phase.go:
        _registerHit();
      case _Phase.result:
        // Ignored. Tapping through feedback would skip the number the player is
        // trying to read.
        break;
    }
  }

  void _arm() {
    setState(() {
      _phase = _Phase.waiting;
      _lastReactionMs = null;
      _lastWasFalseStart = false;
    });

    final wait = _minWait + Duration(milliseconds: _random.nextInt(_extraWaitRangeMs));

    _armTimer?.cancel();
    _armTimer = Timer(wait, () {
      if (!mounted || !widget.session.state.isPlaying) return;
      setState(() {
        _phase = _Phase.go;
        _targetShownAt = DateTime.now();
      });
    });
  }

  void _registerFalseStart() {
    _armTimer?.cancel();

    final next = _run.recordFalseStart();
    setState(() {
      _run = next;
      _phase = _Phase.result;
      _lastWasFalseStart = true;
      _lastReactionMs = null;
    });

    widget.session.recordMove();
    _finishRound(next);
  }

  void _registerHit() {
    final shownAt = _targetShownAt;
    if (shownAt == null) return;

    final ms = DateTime.now().difference(shownAt).inMilliseconds;
    final next = _run.recordHit(ms);

    setState(() {
      _run = next;
      _phase = _Phase.result;
      _lastReactionMs = ms;
      _lastWasFalseStart = false;
    });

    widget.session
      ..recordMove()
      ..addScore(ReactionRun.pointsFor(ms));

    _finishRound(next);
  }

  void _finishRound(ReactionRun run) {
    if (run.isComplete) {
      widget.session.finish(GameOutcome.won);
      return;
    }

    _resultTimer?.cancel();
    _resultTimer = Timer(_resultLinger, () {
      if (!mounted || !widget.session.state.isPlaying) return;
      setState(() => _phase = _Phase.idle);
    });
  }

  ({Color background, Color foreground, String headline, String detail}) _appearance(
    ColorScheme scheme,
  ) {
    return switch (_phase) {
      _Phase.idle => (
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurface,
          headline: 'Tap to start',
          detail: 'Round ${_run.roundNumber} of ${_run.totalRounds}',
        ),
      _Phase.waiting => (
          // Red while waiting, green on go. Universal, and readable without
          // reading — the whole game is about not having to process words.
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          headline: 'Wait…',
          detail: 'Tap when it turns green',
        ),
      _Phase.go => (
          background: const Color(0xFF1B9E4B),
          foreground: Colors.white,
          headline: 'TAP',
          detail: '',
        ),
      _Phase.result => _lastWasFalseStart
          ? (
              background: scheme.errorContainer,
              foreground: scheme.onErrorContainer,
              headline: 'Too soon',
              detail: 'That round scored nothing',
            )
          : (
              background: scheme.secondaryContainer,
              foreground: scheme.onSecondaryContainer,
              headline: '${_lastReactionMs}ms',
              detail: '+${ReactionRun.pointsFor(_lastReactionMs ?? 0)} points',
            ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final look = _appearance(scheme);

    return Padding(
      padding: const EdgeInsets.all(JpSpace.lg),
      child: Column(
        children: [
          if (_run.bestMs != null)
            Padding(
              padding: const EdgeInsets.only(bottom: JpSpace.md),
              child: Text(
                'Best ${_run.bestMs}ms · Average ${_run.averageMs}ms',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          Expanded(
            child: GestureDetector(
              key: reactionSurfaceKey,
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,
              child: AnimatedContainer(
                duration: JpDuration.instant,
                curve: JpCurve.standard,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: look.background,
                  borderRadius: JpRadius.lg,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      look.headline,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: look.foreground,
                      ),
                    ),
                    if (look.detail.isNotEmpty) ...[
                      const SizedBox(height: JpSpace.sm),
                      Text(
                        look.detail,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: look.foreground.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
