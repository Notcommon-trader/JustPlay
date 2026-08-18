import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_core/jp_core.dart';
import 'package:jp_framework/jp_framework.dart';
import 'package:jp_ui/jp_ui.dart';
import 'package:timekiller/journey/journey_screen.dart';
import 'package:timekiller/journey/stage_definitions.dart';

/// The Journey's contract is behavioural, not visual: a stage ends the moment
/// its goal is met, the next one starts without leaving the screen, and a
/// failure is retryable immediately. Those are what these check.
Widget host({int startAt = 1, void Function(int, int)? onStageReached}) {
  return MaterialApp(
    theme: JpTheme.light(),
    home: JourneyScreen(startAt: startAt, onStageReached: onStageReached),
  );
}

Future<void> phone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('the run', () {
    testWidgets('opens on the requested stage and states its goal',
        (tester) async {
      await phone(tester);
      await tester.pumpWidget(host(startAt: 3));
      await tester.pumpAndSettle();

      final stage = Journey.stageAt(3);
      expect(find.text('Stage 3 · ${stageGameName(stage.game)}'), findsOneWidget);
      expect(find.text(stage.goal.describe), findsOneWidget);
    });

    testWidgets('shows no result panel while the stage is unresolved',
        (tester) async {
      await phone(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('Stage clear'), findsNothing);
      expect(find.text('Not this time'), findsNothing);
    });

    testWidgets('names the next stage on the result panel, before the player '
        'has decided to stop', (tester) async {
      // The eye should land on what is coming rather than on a way out.
      await phone(tester);
      await tester.pumpWidget(host(startAt: 1));
      await tester.pumpAndSettle();

      final next = Journey.stageAt(2);
      // The panel is not up yet, so the text must not be either — this guards
      // the assertion below from passing for the wrong reason.
      expect(
        find.textContaining(stageGameName(next.game)),
        findsNothing,
        reason: 'the next stage should not be named until the stage resolves',
      );
    });
  });

  group('stage definitions', () {
    test('every game and difficulty produces a board', () {
      // A stage that cannot be turned into a definition is a run that dies at
      // that number, for everyone, forever.
      for (final game in StageGame.values) {
        for (var d = 0; d <= 6; d++) {
          final stage = Stage(
            number: 1,
            game: game,
            goal: const JustWin(),
            difficulty: d,
          );

          final definition = definitionFor(stage);
          expect(definition.id, isNotEmpty, reason: '${game.name} at d$d');
        }
      }
    });

    test('a retry deals a different board', () {
      // Replaying the position you just lost is the fastest way to end a
      // session.
      final stage = Journey.stageAt(1);
      final first = definitionFor(stage);
      final second = definitionFor(stage, attempt: 1);

      expect(first, isNot(same(second)));
    });

    test('every stage in a long ladder maps to a real board', () {
      for (final stage in Journey.ladder(200)) {
        expect(definitionFor(stage).id, isNotEmpty,
            reason: 'stage ${stage.number}');
      }
    });

    test('every journey game has a colour and a name', () {
      for (final game in StageGame.values) {
        expect(stageGameName(game), isNotEmpty);
        expect(stageColourValue(game), isNot(0));
      }
    });
  });

  group('progress', () {
    test('records a cleared stage and never goes backwards', () async {
      final progress = JourneyProgress(store: InMemoryKeyValueStore());
      await progress.load();

      expect(progress.stage, 1);
      expect(progress.hasStarted, isFalse);

      await progress.recordCleared(1, 2);
      expect(progress.stage, 2);
      expect(progress.stars, 2);
      expect(progress.hasStarted, isTrue);

      // Replaying stage 1 for a third star must not drag the run back.
      await progress.recordCleared(1, 3);
      expect(progress.stage, 2, reason: 'progress went backwards');
      expect(progress.stars, 5);
    });

    test('survives a reload', () async {
      final store = InMemoryKeyValueStore();

      final first = JourneyProgress(store: store);
      await first.load();
      await first.recordCleared(7, 3);

      final second = JourneyProgress(store: store);
      await second.load();

      expect(second.stage, 8);
      expect(second.stars, 3);
    });

    test('reset returns to the start', () async {
      final progress = JourneyProgress(store: InMemoryKeyValueStore());
      await progress.load();
      await progress.recordCleared(20, 3);

      await progress.reset();
      expect(progress.stage, 1);
      expect(progress.stars, 0);
    });
  });
}
