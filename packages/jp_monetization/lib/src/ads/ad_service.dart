import 'dart:async';

/// Where an ad may appear.
///
/// An enum rather than a free-form string because the set is a product decision,
/// not a parameter. Adding a placement should require editing this file and
/// reading the rule below it.
enum AdPlacement {
  /// Full-screen, shown after a game ends. **Never mid-game.** A casual player
  /// interrupted mid-board does not come back.
  gameOver,

  /// Opt-in, in exchange for a hint. Rewarded ads convert far better than forced
  /// interstitials in this genre because the player chooses them.
  rewardedHint,

  /// Opt-in, to continue after losing.
  rewardedContinue,
}

/// What came of showing a rewarded ad.
enum RewardOutcome {
  /// Watched to the end. The reward is owed.
  earned,

  /// Dismissed early, or closed. No reward — and no complaint, because the
  /// player made the choice.
  dismissed,

  /// Nothing was available, or the load failed. **Grant the reward anyway.**
  /// A player who asked for a hint and got a network error should not be
  /// punished for our fill rate; the cost of being generous here is a fraction
  /// of the cost of feeling cheated.
  unavailable,
}

/// Shows ads. Implemented by a real network, or by nothing at all.
abstract class AdService {
  /// Prepares the SDK. Must not be called before consent resolves — see
  /// [ConsentService]. Safe to call twice.
  Future<void> initialise({required bool personalised});

  /// Whether an ad for [placement] is loaded and ready right now.
  bool isReady(AdPlacement placement);

  /// Starts loading, so the ad is ready when the moment arrives. Loading at the
  /// moment of use means a spinner between the player and their next game.
  Future<void> preload(AdPlacement placement);

  /// Shows a full-screen ad. Returns whether one was actually shown.
  Future<bool> showInterstitial();

  /// Shows a rewarded ad and reports what the player did.
  Future<RewardOutcome> showRewarded(AdPlacement placement);
}

/// No ads. Used for premium players, for builds before a network is wired, and
/// for every test that is not specifically about advertising.
///
/// [showRewarded] returns [RewardOutcome.unavailable] rather than `earned`, so a
/// caller that forgets to handle the unavailable case is caught by the no-op
/// implementation instead of in production.
class NoAdService implements AdService {
  @override
  Future<void> initialise({required bool personalised}) async {}

  @override
  bool isReady(AdPlacement placement) => false;

  @override
  Future<void> preload(AdPlacement placement) async {}

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<RewardOutcome> showRewarded(AdPlacement placement) async =>
      RewardOutcome.unavailable;
}

/// Records what it was asked to do. For tests that assert an ad was *not* shown,
/// which is most of them.
class RecordingAdService implements AdService {
  RecordingAdService({this.rewardOutcome = RewardOutcome.earned});

  final RewardOutcome rewardOutcome;

  final List<AdPlacement> preloaded = [];
  final List<AdPlacement> shown = [];
  bool initialised = false;
  bool? initialisedPersonalised;

  @override
  Future<void> initialise({required bool personalised}) async {
    initialised = true;
    initialisedPersonalised = personalised;
  }

  @override
  bool isReady(AdPlacement placement) => true;

  @override
  Future<void> preload(AdPlacement placement) async => preloaded.add(placement);

  @override
  Future<bool> showInterstitial() async {
    shown.add(AdPlacement.gameOver);
    return true;
  }

  @override
  Future<RewardOutcome> showRewarded(AdPlacement placement) async {
    shown.add(placement);
    return rewardOutcome;
  }
}
