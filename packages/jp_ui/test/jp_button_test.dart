import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_ui/jp_ui.dart';

/// Wraps a widget in the real app theme, so tests exercise the same styling the
/// app ships rather than Flutter defaults.
Widget host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? JpTheme.light() : JpTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('JpButton', () {
    testWidgets('renders its label and fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(JpButton(label: 'Play', onPressed: () => taps++)));

      expect(find.text('Play'), findsOneWidget);
      await tester.tap(find.byType(JpButton));
      expect(taps, 1);
    });

    testWidgets('a null onPressed disables it and swallows taps', (tester) async {
      await tester.pumpWidget(host(const JpButton(label: 'Play', onPressed: null)));

      await tester.tap(find.byType(JpButton));
      await tester.pump();

      // Nothing to assert on a counter — the point is that tapping a disabled
      // button must not throw and must not animate.
      expect(tester.takeException(), isNull);
    });

    /// Target scale the button is animating towards. Read from AnimatedScale
    /// rather than the rendered Transform: the target is the behaviour under
    /// test, whereas the rendered value depends on exactly how far the
    /// animation has progressed at the moment of the assertion.
    double targetScale(WidgetTester tester) {
      return tester
          .widget<AnimatedScale>(
            find.descendant(of: find.byType(JpButton), matching: find.byType(AnimatedScale)),
          )
          .scale;
    }

    testWidgets('compresses on pointer down and releases on pointer up', (tester) async {
      await tester.pumpWidget(host(JpButton(label: 'Play', onPressed: () {})));
      expect(targetScale(tester), 1.0);

      // Press and hold. Feedback must begin on pointer *down*, not on tap
      // completion, or a button whose handler does real work feels unresponsive.
      final gesture = await tester.startGesture(tester.getCenter(find.byType(JpButton)));
      await tester.pump();
      expect(targetScale(tester), lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(targetScale(tester), 1.0);
    });

    testWidgets('a cancelled gesture releases the press state', (tester) async {
      // Dragging off a button must not leave it stuck compressed.
      await tester.pumpWidget(host(JpButton(label: 'Play', onPressed: () {})));

      final gesture = await tester.startGesture(tester.getCenter(find.byType(JpButton)));
      await tester.pump();
      expect(targetScale(tester), lessThan(1.0));

      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(targetScale(tester), 1.0);
    });

    testWidgets('a disabled button does not react to a press', (tester) async {
      await tester.pumpWidget(host(const JpButton(label: 'Play', onPressed: null)));

      final gesture = await tester.startGesture(tester.getCenter(find.byType(JpButton)));
      await tester.pump();
      expect(targetScale(tester), 1.0, reason: 'A disabled button must not appear pressable.');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('exposes itself to accessibility as an enabled button', (tester) async {
      await tester.pumpWidget(host(JpButton(label: 'Play', onPressed: () {})));

      expect(
        tester.getSemantics(find.byType(JpButton).first),
        matchesSemantics(
          label: 'Play',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('reports as disabled to accessibility when it is', (tester) async {
      await tester.pumpWidget(host(const JpButton(label: 'Play', onPressed: null)));

      expect(
        tester.getSemantics(find.byType(JpButton).first),
        matchesSemantics(label: 'Play', isButton: true, isEnabled: false, hasEnabledState: true),
      );
    });

    testWidgets('expand makes it fill the available width', (tester) async {
      await tester.pumpWidget(host(
        const SizedBox(width: 300, child: JpButton(label: 'Play', onPressed: null, expand: true)),
      ));

      expect(tester.getSize(find.byType(JpButton)).width, 300);
    });

    testWidgets('each size has a touch target of at least 36dp', (tester) async {
      for (final size in JpButtonSize.values) {
        await tester.pumpWidget(host(JpButton(label: 'Play', onPressed: () {}, size: size)));
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byType(JpButton)).height,
          greaterThanOrEqualTo(36),
          reason: '$size is below a usable touch target',
        );
      }
    });

    testWidgets('renders in dark theme without error', (tester) async {
      await tester.pumpWidget(
        host(JpButton(label: 'Play', onPressed: () {}), brightness: Brightness.dark),
      );

      expect(find.text('Play'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every variant renders', (tester) async {
      for (final variant in JpButtonVariant.values) {
        await tester.pumpWidget(host(JpButton(label: 'Go', onPressed: () {}, variant: variant)));
        await tester.pumpAndSettle();
        expect(find.text('Go'), findsOneWidget, reason: '$variant failed to render');
      }
    });

    testWidgets('a long label truncates rather than overflowing', (tester) async {
      // Overflow is a real risk once strings are translated — German and Hindi
      // routinely run 30-50% longer than English.
      await tester.pumpWidget(host(
        const SizedBox(
          width: 120,
          child: JpButton(
            label: 'An extremely long call to action label',
            onPressed: null,
            expand: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(JpButton), findsOneWidget);
    });
  });

  group('JpTheme', () {
    test('light and dark both produce usable schemes', () {
      expect(JpTheme.light().colorScheme.brightness, Brightness.light);
      expect(JpTheme.dark().colorScheme.brightness, Brightness.dark);
    });

    test('a different seed produces a different primary', () {
      // This is what lets a sibling app get its own identity from one value.
      final a = JpTheme.light().colorScheme.primary;
      final b = JpTheme.light(seed: const Color(0xFFD4574C)).colorScheme.primary;
      expect(a, isNot(b));
    });

    test('ink splashes are suppressed app-wide', () {
      // JpButton animates scale instead; a ripple would fire on top of it and
      // read as Android-specific on iOS.
      expect(JpTheme.light().splashFactory, NoSplash.splashFactory);
    });
  });
}
