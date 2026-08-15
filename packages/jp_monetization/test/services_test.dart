import 'package:flutter_test/flutter_test.dart';
import 'package:jp_monetization/jp_monetization.dart';

void main() {
  group('consent', () {
    test('a build with nothing to consent to reports notRequired, not granted', () {
      // The distinction matters: `granted` would claim a permission nobody gave,
      // and any later code reading "granted" as licence to collect would be
      // acting on a lie this class told it.
      final consent = NoConsentRequired();
      addTearDown(consent.dispose);

      expect(consent.status, ConsentStatus.notRequired);
      expect(consent.status, isNot(ConsentStatus.granted));
    });

    test('permits neither personalised ads nor analytics', () {
      final consent = NoConsentRequired();
      addTearDown(consent.dispose);

      expect(consent.allowsPersonalisedAds, isFalse);
      expect(consent.allowsAnalytics, isFalse);
    });

    test('asking repeatedly is safe and changes nothing', () async {
      final consent = NoConsentRequired();
      addTearDown(consent.dispose);

      expect(await consent.requestIfNeeded(), ConsentStatus.notRequired);
      expect(await consent.requestIfNeeded(), ConsentStatus.notRequired);
      expect(await consent.reopen(), ConsentStatus.notRequired);
    });
  });

  group('entitlements', () {
    test('the default service grants nothing', () {
      // A stub that returned premium "for testing" is how a build ships with its
      // paywalls quietly disabled.
      final service = FreeEntitlementService();
      addTearDown(service.dispose);

      expect(service.entitlement, Entitlement.free);
      expect(service.isPremium, isFalse);
    });

    test('refresh and restore do not invent a purchase', () async {
      final service = FreeEntitlementService();
      addTearDown(service.dispose);

      expect(await service.refresh(), Entitlement.free);
      expect(await service.restore(), Entitlement.free);
    });

    test('the fake service can be driven to premium and back', () {
      final service = FakeEntitlementService();
      addTearDown(service.dispose);

      expect(service.isPremium, isFalse);
      service.entitlement = Entitlement.premium;
      expect(service.isPremium, isTrue);
    });

    test('a change is announced, so a live session can drop its ads', () async {
      // A subscription can lapse or restore mid-session. Anything reading this
      // once at startup eventually shows ads to a paying customer.
      final service = FakeEntitlementService();
      addTearDown(service.dispose);

      final seen = <Entitlement>[];
      final subscription = service.changes.listen(seen.add);
      addTearDown(subscription.cancel);

      service.entitlement = Entitlement.premium;
      service.entitlement = Entitlement.free;
      await Future<void>.delayed(Duration.zero);

      expect(seen, [Entitlement.premium, Entitlement.free]);
    });

    test('setting the same entitlement announces nothing', () async {
      final service = FakeEntitlementService();
      addTearDown(service.dispose);

      final seen = <Entitlement>[];
      final subscription = service.changes.listen(seen.add);
      addTearDown(subscription.cancel);

      service.entitlement = Entitlement.free;
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
    });
  });

  group('ads', () {
    test('the no-op service shows nothing and is never ready', () async {
      final ads = NoAdService();

      expect(ads.isReady(AdPlacement.gameOver), isFalse);
      expect(await ads.showInterstitial(), isFalse);
    });

    test('an unavailable rewarded ad is reported, not silently earned',
        () async {
      // The caller decides to be generous — see RewardOutcome.unavailable. The
      // service returning `earned` for an ad that never played would hide a
      // broken network behind a working-looking reward.
      final ads = NoAdService();

      expect(
        await ads.showRewarded(AdPlacement.rewardedHint),
        RewardOutcome.unavailable,
      );
    });

    test('initialisation records whether personalisation was permitted', () async {
      // Consent decides this, and getting it wrong is a policy violation rather
      // than a bug — so it is worth asserting the flag actually travels.
      final ads = RecordingAdService();

      await ads.initialise(personalised: false);
      expect(ads.initialised, isTrue);
      expect(ads.initialisedPersonalised, isFalse);
    });

    test('the recording service tracks what was preloaded and shown', () async {
      final ads = RecordingAdService();

      await ads.preload(AdPlacement.gameOver);
      await ads.showInterstitial();
      await ads.showRewarded(AdPlacement.rewardedHint);

      expect(ads.preloaded, [AdPlacement.gameOver]);
      expect(ads.shown, [AdPlacement.gameOver, AdPlacement.rewardedHint]);
    });
  });
}
