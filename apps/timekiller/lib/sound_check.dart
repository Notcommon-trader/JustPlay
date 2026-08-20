import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_ui/jp_ui.dart';

/// Shows what the audio system is actually doing.
///
/// **This exists because silence is undebuggable from the outside.** Four builds
/// shipped mute; every one of them passed its tests, because a failure to play
/// looks exactly like working correctly with the volume down. Nothing in the app
/// could tell those apart, so each fix was a guess.
///
/// It reports three separate things, which is the point — they fail
/// independently and only one of them is "sound is off":
///
/// 1. whether the file is in the bundle at the key the player will ask for,
/// 2. whether the audio service initialised,
/// 3. what the platform said when actually asked to play.
Future<void> showSoundCheck(BuildContext context, SoundService sounds) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SoundCheck(sounds: sounds),
  );
}

class _SoundCheck extends StatefulWidget {
  const _SoundCheck({required this.sounds});

  final SoundService sounds;

  @override
  State<_SoundCheck> createState() => _SoundCheckState();
}

class _SoundCheckState extends State<_SoundCheck> {
  final Map<Sfx, String> _results = {};
  final Map<Sfx, bool> _bundled = {};
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkBundle();
  }

  /// Asks the bundle for exactly the key the player resolves to.
  Future<void> _checkBundle() async {
    for (final sfx in Sfx.values) {
      try {
        final data = await rootBundle.load(ToneSounds.assetKey(sfx));
        _bundled[sfx] = data.lengthInBytes > 0;
      } on Object {
        _bundled[sfx] = false;
      }
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _test(Sfx sfx) async {
    setState(() => _results[sfx] = 'playing…');
    final error = await widget.sounds.playAndReport(sfx);

    if (!mounted) return;
    setState(() => _results[sfx] = error == null ? 'played, no error' : '$error');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sounds = widget.sounds;

    return SafeArea(
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
            Text('Sound check', style: theme.textTheme.headlineSmall),
            const SizedBox(height: JpSpace.sm),
            Text(
              'Tap a sound. If nothing is audible, the line underneath says why.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: JpSpace.lg),

            _Line(
              label: 'Service ready',
              value: '${sounds.isReady}',
              bad: !sounds.isReady,
            ),
            _Line(
              label: 'Last error',
              value: sounds.lastError?.toString() ?? 'none',
              bad: sounds.lastError != null,
            ),
            _Line(
              label: 'Bundle',
              value: _checking
                  ? 'checking…'
                  : _bundled.values.every((ok) => ok)
                      ? 'all ${Sfx.values.length} present'
                      : 'MISSING: ${_bundled.entries.where((e) => !e.value).map((e) => e.key.name).join(', ')}',
              bad: !_checking && _bundled.values.any((ok) => !ok),
            ),
            _Line(
              label: 'Asset key',
              value: ToneSounds.assetKey(Sfx.win),
              bad: false,
            ),

            const SizedBox(height: JpSpace.lg),
            const Divider(),
            const SizedBox(height: JpSpace.sm),

            for (final sfx in Sfx.values) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(sfx.name, style: theme.textTheme.titleMedium),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _test(sfx),
                    child: const Text('Play'),
                  ),
                ],
              ),
              if (_results[sfx] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: JpSpace.sm),
                  child: SelectableText(
                    _results[sfx]!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _results[sfx]!.startsWith('played')
                          ? scheme.onSurfaceVariant
                          : scheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: JpSpace.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, required this.bad});

  final String label;
  final String value;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: JpSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            // Selectable, so a failure can be copied out rather than retyped
            // from a photograph of a phone.
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: bad ? theme.colorScheme.error : null,
                fontWeight: bad ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
