import 'package:flutter/material.dart';

import '../theme/jp_theme.dart';

/// Test surface sizes used by golden tests across the repo.
///
/// Fixed rather than "whatever the test host defaults to", because a golden is
/// only meaningful if the surface it was captured at is reproducible. These
/// approximate a mid-range phone in logical pixels.
abstract final class GoldenSize {
  /// Default: a typical phone in portrait.
  static const Size phone = Size(390, 844);

  /// Short screen — the first place a fixed-height layout overflows.
  static const Size phoneShort = Size(360, 640);

  /// For capturing a single component rather than a whole screen.
  static const Size component = Size(400, 200);
}

/// Wraps a widget in the real app theme for golden capture.
///
/// Uses the shipped [JpTheme] rather than Flutter defaults, so a golden failing
/// means the *app's* appearance changed — a golden against default Material
/// would pass through a complete theme regression without noticing.
Widget goldenHost(
  Widget child, {
  Brightness brightness = Brightness.light,
  Color seed = JpTheme.defaultSeed,
  bool center = true,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.light
        ? JpTheme.light(seed: seed)
        : JpTheme.dark(seed: seed),
    home: center ? Scaffold(body: Center(child: child)) : child,
  );
}
