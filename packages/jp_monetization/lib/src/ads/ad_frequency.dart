/// How often an interstitial may appear.
///
/// Every number here is a product decision that will be wrong at first and has
/// to be tuned against real retention data. That is exactly why it is a value
/// object: it is built from remote config at runtime, so tuning monetisation
/// never requires a release. See ARCHITECTURE.md §7.
class AdFrequencyPolicy {
  const AdFrequencyPolicy({
    this.gamesBeforeFirstAd = 3,
    this.gamesBetweenAds = 3,
    this.minimumGap = const Duration(minutes: 2),
    this.sessionCap = 6,
  });

  /// Advertising switched off entirely. What a premium player gets, and what
  /// ships until the network is wired.
  static const AdFrequencyPolicy none = AdFrequencyPolicy(
    gamesBeforeFirstAd: 1 << 30,
    gamesBetweenAds: 1 << 30,
    sessionCap: 0,
  );

  /// Games a new player finishes before seeing their first ad.
  ///
  /// Not zero. An ad after the very first game is the strongest uninstall signal
  /// in casual gaming: the player has not yet decided they like the app, and the
  /// first thing it does is interrupt them.
  final int gamesBeforeFirstAd;

  final int gamesBetweenAds;

  /// Wall-clock floor between ads, independent of game count. Without it, a
  /// player on a run of thirty-second games gets an ad every ninety seconds and
  /// the game-count rule looks reasonable the whole time.
  final Duration minimumGap;

  /// Hard ceiling per session, whatever the other rules allow.
  final int sessionCap;

  AdFrequencyPolicy copyWith({
    int? gamesBeforeFirstAd,
    int? gamesBetweenAds,
    Duration? minimumGap,
    int? sessionCap,
  }) {
    return AdFrequencyPolicy(
      gamesBeforeFirstAd: gamesBeforeFirstAd ?? this.gamesBeforeFirstAd,
      gamesBetweenAds: gamesBetweenAds ?? this.gamesBetweenAds,
      minimumGap: minimumGap ?? this.minimumGap,
      sessionCap: sessionCap ?? this.sessionCap,
    );
  }

  /// Builds a policy from remote-config values, ignoring anything malformed.
  ///
  /// A bad remote value must never produce a *more* aggressive policy than the
  /// default — a typo in a config console should not be able to carpet-bomb
  /// every player with ads. Negative and missing values fall back rather than
  /// clamping to zero.
  factory AdFrequencyPolicy.fromConfig(Map<String, Object?> config) {
    const fallback = AdFrequencyPolicy();

    int positive(String key, int fallbackValue) {
      final value = config[key];
      if (value is! num) return fallbackValue;
      final asInt = value.toInt();
      return asInt > 0 ? asInt : fallbackValue;
    }

    final gapSeconds = config['minimumGapSeconds'];
    return AdFrequencyPolicy(
      gamesBeforeFirstAd:
          positive('gamesBeforeFirstAd', fallback.gamesBeforeFirstAd),
      gamesBetweenAds: positive('gamesBetweenAds', fallback.gamesBetweenAds),
      minimumGap: gapSeconds is num && gapSeconds > 0
          ? Duration(seconds: gapSeconds.toInt())
          : fallback.minimumGap,
      sessionCap: positive('sessionCap', fallback.sessionCap),
    );
  }
}

/// Decides whether an interstitial may be shown, and remembers what happened.
///
/// Pure logic with an injected clock, so the rules are unit-testable without an
/// ad network, a timer, or a running app. Every one of these rules exists to
/// stop a specific way of annoying players out of the app, and a rule that is
/// only enforced inside an SDK callback is a rule nobody can test.
class InterstitialGate {
  InterstitialGate({
    this.policy = const AdFrequencyPolicy(),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// Mutable, so remote config arriving mid-session takes effect immediately
  /// rather than at the next launch — the whole point of tuning ad frequency
  /// remotely is not having to wait for anything.
  AdFrequencyPolicy policy;

  final DateTime Function() _now;

  int _gamesFinished = 0;
  int _adsShown = 0;
  int _gamesAtLastAd = 0;
  DateTime? _lastAdAt;

  int get gamesFinished => _gamesFinished;
  int get adsShownThisSession => _adsShown;

  /// Call when a game ends, before asking [shouldShow].
  void recordGameFinished() => _gamesFinished++;

  /// Whether an interstitial may be shown right now.
  ///
  /// [isPremium] short-circuits everything: a paying player never sees one, and
  /// putting that check here rather than at each call site means a new placement
  /// cannot forget it.
  bool shouldShow({required bool isPremium}) {
    if (isPremium) return false;
    if (_adsShown >= policy.sessionCap) return false;
    if (_gamesFinished < policy.gamesBeforeFirstAd) return false;

    if (_adsShown > 0) {
      if (_gamesFinished - _gamesAtLastAd < policy.gamesBetweenAds) return false;

      final last = _lastAdAt;
      if (last != null && _now().difference(last) < policy.minimumGap) {
        return false;
      }
    }

    return true;
  }

  /// Call after an ad was actually shown — not when it was requested. An ad that
  /// failed to load has not interrupted anybody, so it must not start the next
  /// cooldown, or a run of failures locks out advertising for the session.
  void recordAdShown() {
    _adsShown++;
    _gamesAtLastAd = _gamesFinished;
    _lastAdAt = _now();
  }

  /// Resets the per-session counters. A new session is a new budget; the
  /// wall-clock gap deliberately survives, because a player who closes and
  /// reopens the app has not waited any longer in real time.
  void startSession() {
    _gamesFinished = 0;
    _adsShown = 0;
    _gamesAtLastAd = 0;
  }
}
