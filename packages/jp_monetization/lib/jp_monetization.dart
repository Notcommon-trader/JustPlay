/// Consent, entitlements and advertising.
///
/// Every vendor here is replaceable and none is present yet. The package holds
/// ports plus the rules that sit above them — when an ad may be shown, what a
/// failed reward means, whether a player has paid — because those are product
/// decisions that must be testable without an SDK, an account, or a network.
///
/// Order matters and is enforced by the ports, not by convention:
/// consent resolves, then ads initialise, then anything may be shown.
library;

export 'src/ads/ad_frequency.dart';
export 'src/ads/ad_service.dart';
export 'src/consent/consent_service.dart';
export 'src/entitlements/entitlement_service.dart';
