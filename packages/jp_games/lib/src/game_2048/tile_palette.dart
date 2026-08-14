import 'package:flutter/material.dart';

/// Colours for 2048 tiles.
///
/// Derived from the active [ColorScheme] rather than hardcoded, so the game
/// inherits light/dark and any per-app brand seed for free. The classic 2048
/// palette is warm beige on cream, which would look like a foreign object next
/// to the rest of the app.
///
/// The progression is deliberate: low tiles sit close to the surface colour and
/// stay quiet, while high tiles saturate toward the accent. A player should be
/// able to spot their biggest tile without reading a single number.
abstract final class TilePalette {
  static Color background(ColorScheme scheme, int value) {
    if (value == 0) {
      // Empty cell: a recess in the board, not a tile.
      return scheme.onSurface.withValues(alpha: 0.06);
    }

    // Tiles double, so the exponent is the natural scale. 2 -> 1, 4 -> 2 …
    // 2048 -> 11. Clamped so a lucky run past 2048 keeps the top colour rather
    // than wrapping around to a low one.
    final step = (value.bitLength - 1).clamp(1, 11);
    final t = (step - 1) / 10;

    // Starts at secondaryContainer, not surfaceContainerHighest.
    //
    // The earlier version began the ramp at a near-surface grey, which is almost
    // exactly the empty-cell colour — a "2" was visually indistinguishable from
    // an empty square, which is fatal in a game about reading the board at a
    // glance. Caught by test/golden/goldens/game_2048_light.png.
    return Color.lerp(
      scheme.secondaryContainer,
      scheme.primary,
      Curves.easeIn.transform(t),
    )!;
  }

  static Color foreground(ColorScheme scheme, int value) {
    final step = (value.bitLength - 1).clamp(1, 11);
    // Low tiles sit on secondaryContainer and need its paired on-colour; high
    // tiles are saturated primary and need onPrimary. The crossover is where the
    // lerp above passes roughly half way — picking the wrong side here is how
    // text ends up dark-on-dark at the exact moment a player is chasing a big
    // number.
    return step <= 5 ? scheme.onSecondaryContainer : scheme.onPrimary;
  }

  /// Numbers get smaller as they get longer, so "1024" fits the same cell as
  /// "2" without the layout shifting.
  static double fontSizeFor(int value, double cellSize) {
    final digits = value.toString().length;
    final scale = switch (digits) {
      1 => 0.44,
      2 => 0.40,
      3 => 0.34,
      4 => 0.27,
      _ => 0.22,
    };
    return cellSize * scale;
  }
}
