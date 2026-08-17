import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_ui/jp_ui.dart';
import 'package:timekiller/catalogue.dart';
import 'package:timekiller/how_to_demo.dart';

/// The demos are the app's instructions, so a broken one is a game nobody
/// learns to play. None of this is visible in a screenshot of a single frame,
/// which is exactly why it is asserted here.
void main() {
  final scheme = JpTheme.light().colorScheme;

  group('every game has a valid demo', () {
    for (final entry in appCatalogue) {
      test(entry.name, () {
        final script = entry.demo(scheme);
        final cellCount = script.columns * script.rows;

        expect(script.frames.length, greaterThanOrEqualTo(2),
            reason: 'a single frame is a picture, not a demonstration');

        for (final frame in script.frames) {
          for (final cell in frame.cells) {
            // An out-of-range index throws at build time, on the sheet, in
            // front of the player.
            expect(cell.index, inInclusiveRange(0, cellCount - 1),
                reason: '${entry.name}: cell ${cell.index} is off the board');
          }

          final pointer = frame.pointer;
          if (pointer != null) {
            expect(pointer.dx, inInclusiveRange(0, 1));
            expect(pointer.dy, inInclusiveRange(0, 1));
          }
        }
      });
    }
  });

  group('the demo player', () {
    testWidgets('advances through its frames and loops', (tester) async {
      final entry = appCatalogue.first;
      final script = entry.demo(scheme);

      await tester.pumpWidget(
        MaterialApp(
          theme: JpTheme.light(seed: entry.colour),
          home: Scaffold(
            body: HowToDemo(script: script, accent: entry.colour),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(script.caption!), findsOneWidget);

      // Walk a full cycle. A frame that throws while building takes the sheet
      // down with it, so simply getting round without an exception is the
      // assertion.
      for (final frame in script.frames) {
        await tester.pump(frame.duration);
      }
      await tester.pump(script.frames.first.duration);

      expect(tester.takeException(), isNull);
    });

    testWidgets('stops its timer when the sheet closes', (tester) async {
      // A loop that keeps firing after disposal calls setState on a dead State.
      // testWidgets fails on a pending timer, so this passing is the proof.
      final entry = appCatalogue.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HowToDemo(script: entry.demo(scheme), accent: entry.colour),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
    });
  });
}
