import 'package:flutter/material.dart';

import '../tokens/jp_tokens.dart';

/// Builds the app's light and dark themes.
///
/// Material 3 is the base, but deliberately **restyled** rather than shipped as
/// default. Stock M3 is recognisable on sight and reads as "a Flutter app that
/// didn't get designed" — the whole point of a design system is that the app
/// looks like itself.
///
/// A single [seed] drives the colour scheme, so a sibling app in the portfolio
/// gets its own identity by changing one value. At two apps a month that matters
/// more than any individual colour choice.
abstract final class JpTheme {
  /// Default brand seed. Deep indigo — reads as calm and modern, and generates a
  /// usable scheme in both brightnesses, which not every hue does.
  static const Color defaultSeed = Color(0xFF4C5BD4);

  static ThemeData light({Color seed = defaultSeed}) => _build(seed, Brightness.light);

  static ThemeData dark({Color seed = defaultSeed}) => _build(seed, Brightness.dark);

  static ThemeData _build(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      // Material 3's default (`tonalSpot`) desaturates the seed heavily — a
      // vivid indigo comes back as a muted slate blue, which is most of why
      // stock M3 apps look washed out. `vibrant` keeps the brand colour
      // recognisable while still generating a full, accessible tonal palette.
      //
      // This is visible in test/golden/goldens/buttons_light.png: the primary
      // button was grey-blue before this line existed.
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );
    final text = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,

      // Splash suppressed app-wide: JpButton animates scale on press instead.
      // Ink ripples spread from the touch point and read as Android-specific,
      // which is wrong for a cross-platform game that should feel native on iOS
      // too. Scale-on-press reads as physical on both.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,

      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(borderRadius: JpRadius.md),
        margin: EdgeInsets.zero,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(borderRadius: JpRadius.sheet),
        showDragHandle: true,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(borderRadius: JpRadius.lg),
      ),

      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayShape: SliderComponentShape.noOverlay,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: JpSpace.lg,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: JpRadius.sm),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _JpPageTransitionBuilder(),
          TargetPlatform.iOS: _JpPageTransitionBuilder(),
          TargetPlatform.windows: _JpPageTransitionBuilder(),
          TargetPlatform.macOS: _JpPageTransitionBuilder(),
          TargetPlatform.linux: _JpPageTransitionBuilder(),
        },
      ),
    );
  }

  /// Type ramp mapped onto Material's slots.
  ///
  /// Tight negative letter spacing on the large sizes: default tracking on big
  /// text looks loose and dated, and tightening it is most of what separates a
  /// designed heading from a default one.
  static TextTheme _textTheme(ColorScheme scheme) {
    final onSurface = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;

    return TextTheme(
      displayMedium: TextStyle(
        fontSize: JpTextSize.display,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.1,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: JpTextSize.headline,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.15,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: JpTextSize.title,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.25,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: JpTextSize.body,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: JpTextSize.label,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontSize: JpTextSize.label,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: JpTextSize.caption,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: muted,
      ),
    );
  }
}

/// Shared-axis style transition: the incoming page slides a short distance and
/// fades in, rather than travelling the full screen width.
///
/// Full-width slides read as heavy and make an app feel slow; a short offset
/// with a fade reads as modern and keeps navigation feeling instant.
class _JpPageTransitionBuilder extends PageTransitionsBuilder {
  const _JpPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: JpCurve.enter,
      reverseCurve: JpCurve.exit,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
