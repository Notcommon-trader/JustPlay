import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_ui/jp_ui.dart';

/// A board that ends the game when tapped.
///
/// The shell is what is under test, so the board does the least a game can do
/// while still letting a test reach the finished state through the widget tree
/// rather than by reaching into private state.
class _BlankDefinition extends GameDefinition {
  const _BlankDefinition();

  @override
  String get id => 'blank';

  @override
  String get nameKey => 'blank';

  @override
  String get descriptionKey => 'blank';

  @override
  GameCapabilities get capabilities => const GameCapabilities();

  @override
  Widget buildBoard(BuildContext context, GameSession session) {
    return GestureDetector(
      onTap: () => session.finish(GameOutcome.won),
      child: const ColoredBox(
        color: Color(0xFFEEEEEE),
        child: SizedBox.expand(child: Center(child: Text('Board'))),
      ),
    );
  }
}

/// Pushes a game the way the app does, and reports whether it is still open.
Widget host({required VoidCallback onExit}) {
  return MaterialApp(
    theme: JpTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => GameShell(
                  definition: const _BlankDefinition(),
                  title: 'Blank',
                  // Pops, exactly as the app's openGame does. The extra callback
                  // is only so a test can observe that exit happened.
                  onExit: () {
                    Navigator.of(context).pop();
                    onExit();
                  },
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('the Android back button', () {
    testWidgets('asks before abandoning a game in progress', (tester) async {
      // The close button in the app bar confirms before quitting. A system back
      // gesture is the same intent and has to behave the same way — otherwise a
      // stray edge-swipe throws away a half-finished sudoku, which is exactly
      // the kind of thing that gets an app deleted.
      var exited = false;
      await tester.pumpWidget(host(onExit: () => exited = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(GameShell), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Quit this game?'), findsOneWidget,
          reason: 'system back should confirm, exactly as the close button does');
      expect(find.byType(GameShell), findsOneWidget,
          reason: 'the game must still be there behind the dialog');
      expect(exited, isFalse);
    });

    testWidgets('declining leaves the game open', (tester) async {
      await tester.pumpWidget(host(onExit: () {}));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep playing'));
      await tester.pumpAndSettle();

      expect(find.byType(GameShell), findsOneWidget);
      expect(find.text('Quit this game?'), findsNothing);
    });

    testWidgets('confirming leaves the game', (tester) async {
      await tester.pumpWidget(host(onExit: () {}));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quit'));
      await tester.pumpAndSettle();

      expect(find.byType(GameShell), findsNothing);
    });

    testWidgets('a finished game leaves immediately, with no prompt',
        (tester) async {
      // Nothing left to lose, so a confirmation would just be a tax on leaving.
      var exited = false;
      await tester.pumpWidget(host(onExit: () => exited = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tapping the board finishes the game, the way a real game reports its
      // own end.
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();
      expect(find.text('You win'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Quit this game?'), findsNothing);
      expect(exited, isTrue);
    });
  });
}
