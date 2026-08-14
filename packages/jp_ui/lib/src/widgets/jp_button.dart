import 'package:flutter/material.dart';

import '../tokens/jp_tokens.dart';

enum JpButtonVariant {
  /// The one action a screen wants you to take. At most one per screen.
  primary,

  /// Supporting actions. Visible, clearly secondary.
  secondary,

  /// Low-emphasis actions — cancel, skip, dismiss.
  ghost,

  /// Irreversible actions. Reset progress, delete data.
  danger,
}

enum JpButtonSize { small, medium, large }

/// The app's button.
///
/// Scale-on-press rather than an ink ripple. A ripple spreads from the touch
/// point and reads as distinctly Android; a button that physically compresses
/// under the finger reads as native on both platforms, and is the single
/// cheapest thing that makes an app feel responsive rather than static.
///
/// The press animation is driven on pointer *down*, not on tap completion, so
/// feedback is immediate even if the tap handler does real work.
class JpButton extends StatefulWidget {
  const JpButton({
    required this.label,
    required this.onPressed,
    this.variant = JpButtonVariant.primary,
    this.size = JpButtonSize.medium,
    this.icon,
    this.expand = false,
    super.key,
  });

  final String label;

  /// Null disables the button. Matching Flutter's own convention here means
  /// callers never have to think about a separate `enabled` flag.
  final VoidCallback? onPressed;

  final JpButtonVariant variant;
  final JpButtonSize size;
  final IconData? icon;

  /// Fill the available width. Used for stacked call-to-action columns.
  final bool expand;

  bool get _enabled => onPressed != null;

  @override
  State<JpButton> createState() => _JpButtonState();
}

class _JpButtonState extends State<JpButton> {
  /// Whether a pointer is currently down on this button.
  ///
  /// An implicit [AnimatedScale] rather than a hand-driven AnimationController:
  /// this is a two-state transition, which is exactly what implicit animations
  /// exist for. It removes the controller, the ticker mixin, and the dispose
  /// call — three things to get wrong for no gain.
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (!widget._enabled || _pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = _styleFor(scheme, widget.variant, enabled: widget._enabled);
    final metrics = _metricsFor(widget.size);

    return Semantics(
      button: true,
      enabled: widget._enabled,
      label: widget.label,
      // Without this the child Text contributes its own label and the node ends
      // up as "Play\nPlay" — a screen reader announces it twice. This wrapper is
      // the single source of the accessible name.
      excludeSemantics: true,
      // Excluding child semantics also drops the GestureDetector's tap action,
      // which would leave the button unactivatable by a screen reader — visible
      // to TalkBack but impossible to press. The wrapper has to re-supply it.
      onTap: widget.onPressed,
      // Listener for the press animation, GestureDetector for the tap itself.
      //
      // GestureDetector.onTapDown is NOT immediate: the tap recognizer waits for
      // the gesture arena to resolve, up to kPressTimeout (100ms), before firing.
      // On a button whose whole job is to feel responsive that delay is the
      // difference between crisp and sluggish. Listener fires on the raw pointer
      // event with no arena involvement.
      //
      // The pair is deliberate. If this button sits in a scrollable and the user
      // is actually scrolling, the scroll wins the arena and GestureDetector
      // raises onTapCancel — which releases the compression. Listener alone would
      // leave it stuck down during a scroll.
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: GestureDetector(
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          // 4% compression. Enough to feel, small enough not to look bouncy.
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: JpDuration.instant,
            curve: JpCurve.standard,
            child: AnimatedContainer(
              duration: JpDuration.instant,
              curve: JpCurve.standard,
              width: widget.expand ? double.infinity : null,
              height: metrics.height,
              padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPadding),
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: JpRadius.full,
                border: style.border,
                // Shadow only on the primary action, and only while enabled — a
                // shadow on every button flattens the visual hierarchy it exists
                // to create.
                boxShadow: style.elevated ? JpElevation.low(scheme.shadow) : JpElevation.none,
              ),
              child: Row(
                mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: metrics.iconSize, color: style.foreground),
                    const SizedBox(width: JpSpace.sm),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: metrics.fontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        color: style.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ButtonStyle _styleFor(ColorScheme scheme, JpButtonVariant variant, {required bool enabled}) {
    if (!enabled) {
      return _ButtonStyle(
        background: scheme.onSurface.withValues(alpha: 0.08),
        foreground: scheme.onSurface.withValues(alpha: 0.38),
        elevated: false,
      );
    }

    return switch (variant) {
      JpButtonVariant.primary => _ButtonStyle(
          background: scheme.primary,
          foreground: scheme.onPrimary,
          elevated: true,
        ),
      JpButtonVariant.secondary => _ButtonStyle(
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
          elevated: false,
        ),
      JpButtonVariant.ghost => _ButtonStyle(
          background: Colors.transparent,
          foreground: scheme.onSurfaceVariant,
          elevated: false,
          border: Border.all(color: scheme.outlineVariant),
        ),
      JpButtonVariant.danger => _ButtonStyle(
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          elevated: false,
        ),
    };
  }

  _ButtonMetrics _metricsFor(JpButtonSize size) => switch (size) {
        JpButtonSize.small => const _ButtonMetrics(
            height: 36,
            horizontalPadding: JpSpace.lg,
            fontSize: JpTextSize.caption,
            iconSize: 16,
          ),
        JpButtonSize.medium => const _ButtonMetrics(
            height: 48,
            horizontalPadding: JpSpace.xl,
            fontSize: JpTextSize.label,
            iconSize: 20,
          ),
        // 56 is above the 48dp minimum touch target on purpose: primary actions
        // in a game are tapped fast and repeatedly, often one-handed.
        JpButtonSize.large => const _ButtonMetrics(
            height: 56,
            horizontalPadding: JpSpace.xxl,
            fontSize: JpTextSize.body,
            iconSize: 22,
          ),
      };
}

class _ButtonStyle {
  const _ButtonStyle({
    required this.background,
    required this.foreground,
    required this.elevated,
    this.border,
  });

  final Color background;
  final Color foreground;
  final bool elevated;
  final BoxBorder? border;
}

class _ButtonMetrics {
  const _ButtonMetrics({
    required this.height,
    required this.horizontalPadding,
    required this.fontSize,
    required this.iconSize,
  });

  final double height;
  final double horizontalPadding;
  final double fontSize;
  final double iconSize;
}
