import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_ui/jp_ui.dart';

/// Golden tests for the design system.
///
/// **What these catch that nothing else does:** a change that compiles, passes
/// every behavioural test, and silently makes the app look wrong. A spacing
/// token nudged, a colour role swapped, a corner radius reset to zero — all of
/// those pass a widget test asserting "the button renders" and all of them are
/// visible to a user.
///
/// **Reading the images:** text renders as solid blocks. Flutter's test
/// environment substitutes a placeholder font so goldens do not depend on which
/// fonts a machine happens to have installed. Layout, sizing, colour, spacing
/// and shape are all still captured faithfully — only glyph shapes are not.
///
/// **Platform sensitivity:** goldens are rendered by the host, so they can
/// differ subtly between operating systems. These were generated on Windows.
/// If CI runs on Linux, regenerate there and treat that as the source of truth,
/// or the first CI run will fail on antialiasing differences alone.
///
/// Regenerate after an intentional visual change:
///   flutter test --update-goldens
void main() {
  group('JpButton', () {
    testWidgets('all variants, light', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(goldenHost(const _ButtonSheet()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_ButtonSheet),
        matchesGoldenFile('goldens/buttons_light.png'),
      );
    });

    testWidgets('all variants, dark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        goldenHost(const _ButtonSheet(), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_ButtonSheet),
        matchesGoldenFile('goldens/buttons_dark.png'),
      );
    });

    testWidgets('sizes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 260));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(goldenHost(const _SizeSheet()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_SizeSheet),
        matchesGoldenFile('goldens/button_sizes.png'),
      );
    });
  });

  group('theming', () {
    testWidgets('a different brand seed changes the whole palette', (tester) async {
      // Proves the one-value rebrand actually works, visually. A sibling app in
      // the portfolio gets its identity this way, so a regression here would be
      // expensive and otherwise invisible.
      await tester.binding.setSurfaceSize(const Size(360, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        goldenHost(const _ButtonSheet(), seed: const Color(0xFFD4574C)),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_ButtonSheet),
        matchesGoldenFile('goldens/buttons_alternate_seed.png'),
      );
    });
  });
}

/// Every button variant in one frame, so a single golden covers the set.
class _ButtonSheet extends StatelessWidget {
  const _ButtonSheet();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(JpSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final variant in JpButtonVariant.values) ...[
              JpButton(
                label: variant.name,
                onPressed: () {},
                variant: variant,
                expand: true,
              ),
              const SizedBox(height: JpSpace.md),
            ],
            const JpButton(label: 'disabled', onPressed: null, expand: true),
          ],
        ),
      ),
    );
  }
}

class _SizeSheet extends StatelessWidget {
  const _SizeSheet();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(JpSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final size in JpButtonSize.values) ...[
              JpButton(
                label: size.name,
                onPressed: () {},
                size: size,
                icon: Icons.play_arrow,
              ),
              const SizedBox(height: JpSpace.md),
            ],
          ],
        ),
      ),
    );
  }
}
