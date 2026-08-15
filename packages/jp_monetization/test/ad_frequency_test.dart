import 'package:flutter_test/flutter_test.dart';
import 'package:jp_monetization/jp_monetization.dart';

/// A clock the test moves by hand, so the wall-clock rules can be exercised
/// without a real two-minute wait.
class TestClock {
  DateTime now = DateTime(2026, 8, 15, 12);

  void advance(Duration by) => now = now.add(by);
  DateTime call() => now;
}

/// Finishes [count] games on [gate].
void playGames(InterstitialGate gate, int count) {
  for (var i = 0; i < count; i++) {
    gate.recordGameFinished();
  }
}

void main() {
  group('the first ad', () {
    test('is withheld until the player has finished a few games', () {
      // The strongest uninstall signal in casual gaming is an ad after the very
      // first game: the player has not decided they like the app yet.
      final gate = InterstitialGate(
        policy: const AdFrequencyPolicy(gamesBeforeFirstAd: 3),
        clock: TestClock().call,
      );

      playGames(gate, 1);
      expect(gate.shouldShow(isPremium: false), isFalse);

      playGames(gate, 1);
      expect(gate.shouldShow(isPremium: false), isFalse);

      playGames(gate, 1);
      expect(gate.shouldShow(isPremium: false), isTrue);
    });
  });

  group('spacing between ads', () {
    test('requires a minimum number of games', () {
      final clock = TestClock();
      final gate = InterstitialGate(
        policy: const AdFrequencyPolicy(
          gamesBeforeFirstAd: 1,
          gamesBetweenAds: 3,
          minimumGap: Duration.zero,
        ),
        clock: clock.call,
      );

      playGames(gate, 1);
      expect(gate.shouldShow(isPremium: false), isTrue);
      gate.recordAdShown();

      playGames(gate, 2);
      expect(gate.shouldShow(isPremium: false), isFalse, reason: 'only two games since');

      playGames(gate, 1);
      expect(gate.shouldShow(isPremium: false), isTrue);
    });

    test('also requires wall-clock time to have passed', () {
      // Without this, a player on a run of thirty-second games gets an ad every
      // ninety seconds and the game-count rule looks reasonable throughout.
      final clock = TestClock();
      final gate = InterstitialGate(
        policy: const AdFrequencyPolicy(
          gamesBeforeFirstAd: 1,
          gamesBetweenAds: 1,
          minimumGap: Duration(minutes: 2),
        ),
        clock: clock.call,
      );

      playGames(gate, 1);
      gate.recordAdShown();

      playGames(gate, 5);
      clock.advance(const Duration(seconds: 30));
      expect(gate.shouldShow(isPremium: false), isFalse,
          reason: 'plenty of games, but only thirty seconds');

      clock.advance(const Duration(minutes: 2));
      expect(gate.shouldShow(isPremium: false), isTrue);
    });

    test('a failed ad does not start the cooldown', () {
      // recordAdShown is called when an ad was *shown*, not requested. If a
      // failed load started the cooldown, a run of failures would lock out
      // advertising for the rest of the session.
      final clock = TestClock();
      final gate = InterstitialGate(
        policy: const AdFrequencyPolicy(gamesBeforeFirstAd: 1, gamesBetweenAds: 3),
        clock: clock.call,
      );

      playGames(gate, 1);
      expect(gate.shouldShow(isPremium: false), isTrue);

      // Ad failed to load; nothing recorded.
      expect(gate.shouldShow(isPremium: false), isTrue);
      expect(gate.adsShownThisSession, 0);
    });
  });

  group('the session cap', () {
    test('stops ads however many games are played', () {
      final clock = TestClock();
      final gate = InterstitialGate(
        policy: const AdFrequencyPolicy(
          gamesBeforeFirstAd: 1,
          gamesBetweenAds: 1,
          minimumGap: Duration.zero,
          sessionCap: 2,
        ),
        clock: clock.call,
      );

      for (var i = 0; i < 2; i++) {
        playGames(gate, 1);
        expect(gate.shouldShow(isPremium: false), isTrue);
        gate.recordAdShown();
      }

      playGames(gate, 20);
      clock.advance(const Duration(hours: 1));
      expect(gate.shouldShow(isPremium: false), isFalse);
      expect(gate.adsShownThisSession, 2);
    });

    test('a new session restores the budget', () {
      final gate = InterstitialGate(
        policy: const AdFrequencyPolicy(
          gamesBeforeFirstAd: 1,
          gamesBetweenAds: 1,
          minimumGap: Duration.zero,
          sessionCap: 1,
        ),
        clock: TestClock().call,
      );

      playGames(gate, 1);
      gate.recordAdShown();
      expect(gate.shouldShow(isPremium: false), isFalse);

      gate.startSession();
      playGames(gate, 1);
      expect(gate.shouldShow(isPremium: false), isTrue);
    });
  });

  group('premium players', () {
    test('never see an interstitial, whatever the counters say', () {
      // The check lives in the gate rather than at each call site so a new
      // placement cannot forget it.
      final gate = InterstitialGate(
        policy: const AdFrequencyPolicy(
          gamesBeforeFirstAd: 1,
          gamesBetweenAds: 1,
          minimumGap: Duration.zero,
        ),
        clock: TestClock().call,
      );

      playGames(gate, 50);
      expect(gate.shouldShow(isPremium: true), isFalse);
      expect(gate.shouldShow(isPremium: false), isTrue,
          reason: 'the same state allows an ad for a free player');
    });
  });

  group('the none policy', () {
    test('shows nothing at all', () {
      final gate = InterstitialGate(
        policy: AdFrequencyPolicy.none,
        clock: TestClock().call,
      );

      playGames(gate, 1000);
      expect(gate.shouldShow(isPremium: false), isFalse);
    });
  });

  group('remote configuration', () {
    test('reads values from config', () {
      final policy = AdFrequencyPolicy.fromConfig({
        'gamesBeforeFirstAd': 5,
        'gamesBetweenAds': 4,
        'minimumGapSeconds': 90,
        'sessionCap': 8,
      });

      expect(policy.gamesBeforeFirstAd, 5);
      expect(policy.gamesBetweenAds, 4);
      expect(policy.minimumGap, const Duration(seconds: 90));
      expect(policy.sessionCap, 8);
    });

    test('a malformed value falls back rather than becoming aggressive', () {
      // A typo in a config console must never be able to carpet-bomb every
      // player with ads. Zero and negative fall back to the default, they do not
      // clamp to "no gap".
      const fallback = AdFrequencyPolicy();
      final policy = AdFrequencyPolicy.fromConfig({
        'gamesBeforeFirstAd': 0,
        'gamesBetweenAds': -5,
        'minimumGapSeconds': 'soon',
        'sessionCap': null,
      });

      expect(policy.gamesBeforeFirstAd, fallback.gamesBeforeFirstAd);
      expect(policy.gamesBetweenAds, fallback.gamesBetweenAds);
      expect(policy.minimumGap, fallback.minimumGap);
      expect(policy.sessionCap, fallback.sessionCap);
    });

    test('an empty config is the default policy', () {
      const fallback = AdFrequencyPolicy();
      final policy = AdFrequencyPolicy.fromConfig(const {});

      expect(policy.gamesBeforeFirstAd, fallback.gamesBeforeFirstAd);
      expect(policy.sessionCap, fallback.sessionCap);
    });

    test('a policy swapped in mid-session takes effect', () {
      final gate = InterstitialGate(
        policy: AdFrequencyPolicy.none,
        clock: TestClock().call,
      );

      playGames(gate, 5);
      expect(gate.shouldShow(isPremium: false), isFalse);

      gate.policy = const AdFrequencyPolicy(gamesBeforeFirstAd: 3);
      expect(gate.shouldShow(isPremium: false), isTrue);
    });
  });
}
