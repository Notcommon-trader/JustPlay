import 'package:flutter/material.dart';
import 'package:jp_core/jp_core.dart';

import '../tokens/jp_tokens.dart';
import '../widgets/jp_button.dart';
import 'game_definition.dart';
import 'game_session.dart';

/// Wraps a [GameDefinition] with everything common to every game.
///
/// This is the piece that makes the second app cheap: the header, the stat
/// readouts, pause, restart and the game-over sheet are written once here rather
/// than twenty times across the catalogue.
class GameShell extends StatefulWidget {
  const GameShell({
    required this.definition,
    required this.title,
    this.bestScore = 0,
    this.onExit,
    this.onFinished,
    super.key,
  });

  final GameDefinition definition;

  /// Resolved display name. The shell takes a resolved string rather than a
  /// localization key so it stays independent of any particular l10n package.
  final String title;

  final int bestScore;
  final VoidCallback? onExit;

  /// Called once per finished session, with its final state.
  ///
  /// The shell reports the result rather than saving it: persistence is the
  /// app's business, and a shell that wrote to storage would drag a storage
  /// dependency into every widget test of every game.
  final void Function(GameSessionState state)? onFinished;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> with WidgetsBindingObserver {
  late final GameSession _session = GameSession(
    bestScore: widget.bestScore,
    tracksTime: widget.definition.capabilities.showsTimer,
  );

  /// True while the quit-confirmation dialog is open.
  ///
  /// Confirming exit pauses the session so the clock stops, but the pause
  /// overlay must not appear behind the dialog — the player would be looking at
  /// "Paused / Resume / Quit" through a "Quit this game?" prompt, with two Quit
  /// buttons on screen at once.
  bool _isConfirmingExit = false;

  /// Guards against reporting the same finish twice.
  ///
  /// The session notifies on every tick and every score change, so without this
  /// a finished game would file its result once per rebuild — and the play count
  /// would climb while the player read the game-over sheet.
  bool _hasReportedFinish = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.addListener(_onSessionChanged);
    _session.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!_session.state.isFinished) {
      // Restarting re-arms the report, so a second round is recorded too.
      _hasReportedFinish = false;
      return;
    }
    if (_hasReportedFinish) return;

    _hasReportedFinish = true;
    widget.onFinished?.call(_session.state);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-pause when the app leaves the foreground. Without this a player who
    // takes a call returns to a timer that ran the whole time — and on a timed
    // game, to a lost round they never played.
    if (state != AppLifecycleState.resumed && _session.state.isPlaying) {
      _session.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = widget.definition.capabilities;

    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final state = _session.state;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _confirmExit,
              tooltip: 'Exit',
            ),
            actions: [
              if (capabilities.canRestart)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _session.restart,
                  tooltip: 'Restart',
                ),
              if (capabilities.canPause)
                IconButton(
                  icon: Icon(state.isPaused ? Icons.play_arrow : Icons.pause),
                  onPressed: state.isFinished
                      ? null
                      : (state.isPaused ? _session.resume : _session.pause),
                  tooltip: state.isPaused ? 'Resume' : 'Pause',
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _StatBar(state: state, capabilities: capabilities),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: widget.definition.buildBoard(context, _session),
                      ),
                      // Overlays sit above the board rather than replacing it, so
                      // the player can still see the position they are returning
                      // to — and so a game-over sheet does not tear down and
                      // rebuild the board underneath it.
                      if (state.isPaused && !_isConfirmingExit)
                        _Overlay(
                          title: 'Paused',
                          primaryLabel: 'Resume',
                          onPrimary: _session.resume,
                          secondaryLabel: 'Quit',
                          onSecondary: _confirmExit,
                        ),
                      if (state.isFinished)
                        _Overlay(
                          title: _outcomeTitle(state),
                          message: _outcomeMessage(state),
                          primaryLabel: 'Play again',
                          onPrimary: _session.restart,
                          secondaryLabel: 'Done',
                          onSecondary: _confirmExit,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _outcomeTitle(GameSessionState state) {
    return switch (state.outcome) {
      GameOutcome.won => 'You win',
      GameOutcome.lost => 'Out of moves',
      GameOutcome.draw => 'Draw',
      GameOutcome.none => 'Game over',
    };
  }

  String? _outcomeMessage(GameSessionState state) {
    if (state.isNewBest) return 'New best: ${state.score}';
    if (widget.definition.capabilities.showsScore) {
      return 'Score ${state.score} · Best ${state.bestScore}';
    }
    return null;
  }

  void _confirmExit() {
    // A finished game has nothing to lose, so leaving is immediate. Mid-game,
    // walking away by accident costs real progress and is worth one tap to
    // confirm.
    if (_session.state.isFinished) {
      widget.onExit?.call();
      return;
    }

    _session.pause();
    setState(() => _isConfirmingExit = true);

    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quit this game?'),
        content: const Text('Your progress in this round will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quit'),
          ),
        ],
      ),
    ).then((quit) {
      if (!mounted) return;
      setState(() => _isConfirmingExit = false);

      if (quit ?? false) {
        widget.onExit?.call();
      }
      // Declining leaves the session paused rather than auto-resuming. The
      // player looked away to answer a dialog; dropping them back into a live
      // clock mid-thought is the same mistake as resuming a restored session.
    });
  }
}

/// Score, moves and time. Only what the game declares it uses.
class _StatBar extends StatelessWidget {
  const _StatBar({required this.state, required this.capabilities});

  final GameSessionState state;
  final GameCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final stats = <Widget>[
      if (capabilities.showsScore) _Stat(label: 'Score', value: '${state.score}'),
      if (capabilities.showsScore) _Stat(label: 'Best', value: '${state.bestScore}'),
      if (capabilities.showsMoves) _Stat(label: 'Moves', value: '${state.moves}'),
      if (capabilities.showsTimer) _Stat(label: 'Time', value: _format(state.elapsed)),
    ];

    if (stats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: JpSpace.lg, vertical: JpSpace.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: stats,
      ),
    );
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
        const SizedBox(height: JpSpace.xxs),
        // Animated so a score jump reads as a change rather than a silent swap.
        AnimatedSwitcher(
          duration: JpDuration.quick,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Text(
            value,
            key: ValueKey(value),
            style: theme.textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}

/// Dimmed overlay used for both pause and game over.
class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.title,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.message,
  });

  final String title;
  final String? message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: ColoredBox(
        color: theme.colorScheme.scrim.withValues(alpha: 0.55),
        child: Center(
          child: Padding(
            padding: JpSpace.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                if (message != null) ...[
                  const SizedBox(height: JpSpace.sm),
                  Text(message!, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                ],
                const SizedBox(height: JpSpace.xl),
                JpButton(
                  label: primaryLabel,
                  onPressed: onPrimary,
                  size: JpButtonSize.large,
                  expand: true,
                ),
                const SizedBox(height: JpSpace.md),
                JpButton(
                  label: secondaryLabel,
                  onPressed: onSecondary,
                  variant: JpButtonVariant.ghost,
                  expand: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
