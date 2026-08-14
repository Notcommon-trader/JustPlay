import 'package:flutter/widgets.dart';

/// Design tokens.
///
/// Every spacing, radius, duration and curve in the app comes from here. A
/// literal `EdgeInsets.all(13)` anywhere in the codebase is a bug, not a style
/// preference — inconsistent spacing is the single most reliable way an app
/// reads as amateur, and it creeps in one hardcoded number at a time.
///
/// These are `abstract final` so they can never be instantiated or extended;
/// they are namespaces, not objects.

/// Spacing on a strict 4pt scale.
///
/// Four points rather than eight because casual game UI needs tighter steps than
/// a typical productivity app — an 8pt-only scale forces awkward compromises on
/// small board cells.
abstract final class JpSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard screen edge inset. Every full-width screen uses this, so content
  /// aligns across the whole app without anyone measuring.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);
}

/// Corner radii.
///
/// Nothing in this app has square corners. Hard 90-degree edges are the single
/// clearest visual marker of "programmer UI" — the previous Unity build was
/// entirely square rectangles and read exactly that way.
abstract final class JpRadius {
  static const Radius _xs = Radius.circular(6);
  static const Radius _sm = Radius.circular(10);
  static const Radius _md = Radius.circular(16);
  static const Radius _lg = Radius.circular(24);
  static const Radius _full = Radius.circular(999);

  static const BorderRadius xs = BorderRadius.all(_xs);
  static const BorderRadius sm = BorderRadius.all(_sm);

  /// Default for cards, tiles and buttons.
  static const BorderRadius md = BorderRadius.all(_md);

  /// Sheets, dialogs, and anything that reads as a surface rather than a control.
  static const BorderRadius lg = BorderRadius.all(_lg);

  /// Pills — chips, badges, and the primary call-to-action.
  static const BorderRadius full = BorderRadius.all(_full);

  /// Top-only rounding for bottom sheets.
  static const BorderRadius sheet = BorderRadius.vertical(top: _lg);
}

/// Motion.
///
/// Every state change in this app animates. Motion is the cheapest and largest
/// contributor to perceived quality in Flutter, and the thing whose absence made
/// the previous build feel dead — screens there snapped between states with no
/// transition at all.
///
/// Durations are deliberately short. Casual games are played in bursts, and
/// anything above ~300ms starts to feel like waiting rather than polish.
abstract final class JpDuration {
  /// Press feedback, ripples, colour changes.
  static const Duration instant = Duration(milliseconds: 90);

  /// Tile moves, small reveals — the default.
  static const Duration quick = Duration(milliseconds: 160);

  /// Screen transitions, sheet entry.
  static const Duration normal = Duration(milliseconds: 240);

  /// Celebrations and game-over reveals, where a beat of drama is wanted.
  static const Duration slow = Duration(milliseconds: 400);
}

abstract final class JpCurve {
  /// Default for anything entering the screen. Decelerating entry reads as an
  /// object arriving and settling, rather than sliding to a mechanical stop.
  static const Curve enter = Curves.easeOutCubic;

  /// Leaving the screen. Faster out than in — users care less about exits, and a
  /// slow exit feels like the app is lagging.
  static const Curve exit = Curves.easeInCubic;

  /// Standard two-way transition.
  static const Curve standard = Curves.easeInOutCubic;

  /// Overshoot, for a merged tile or a score bump. Used sparingly: on everything
  /// it reads as gimmicky, on the one moment that matters it reads as juice.
  static const Curve pop = Curves.easeOutBack;
}

/// Type ramp.
///
/// A fixed set of sizes. Ad-hoc font sizes at call sites are what produced the
/// previous build's 48/40/36/30/28/26/24 spread, where nothing related to
/// anything else.
abstract final class JpTextSize {
  static const double display = 48;
  static const double headline = 32;
  static const double title = 22;
  static const double body = 16;
  static const double label = 14;
  static const double caption = 12;
}

/// Elevation, expressed as shadows rather than Material's numeric levels so the
/// same values work on custom-painted surfaces like board tiles.
abstract final class JpElevation {
  static const List<BoxShadow> none = [];

  /// Resting cards and tiles.
  static List<BoxShadow> low(Color shadow) => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Raised controls and pressed-into-focus surfaces.
  static List<BoxShadow> medium(Color shadow) => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  /// Sheets and dialogs floating over content.
  static List<BoxShadow> high(Color shadow) => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.18),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];
}
