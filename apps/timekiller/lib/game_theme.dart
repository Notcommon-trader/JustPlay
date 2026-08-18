import 'package:flutter/material.dart';
import 'package:jp_ui/jp_ui.dart';

/// The theme a game wears, built from its own colour.
///
/// **The tile's colour survives into the game.** `ColorScheme.fromSeed` treats
/// its argument as a seed, not as an instruction: it derives a tonal palette and
/// the primary it lands on can be visibly different from the colour you handed
/// it. So a blue tile opened a blue-ish screen, a green tile a different green —
/// close enough to look like a mistake rather than a choice, which is exactly
/// how it was described.
///
/// Forcing `primary` back to the exact colour keeps the identity intact from the
/// grid, through the sheet, to the board. Everything else still comes from the
/// generated palette, so contrast pairings stay sound.
ThemeData gameTheme(Color colour, Brightness brightness) {
  final base = brightness == Brightness.dark
      ? JpTheme.dark(seed: colour)
      : JpTheme.light(seed: colour);

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: colour,
      // White reads on every colour in the catalogue: they are all mid-tone or
      // darker, chosen that way precisely so one foreground works for all ten.
      onPrimary: Colors.white,
    ),
  );
}

/// The game's colour as it should appear on a dark background.
///
/// Full saturation against near-black is where glare comes from, so dark mode
/// pulls each colour toward its surface. Hue is what distinguishes one game from
/// another, and hue survives the dimming.
Color gameColourFor(Color colour, ColorScheme scheme, Brightness brightness) {
  if (brightness != Brightness.dark) return colour;
  return Color.lerp(colour, scheme.surface, 0.30)!;
}
