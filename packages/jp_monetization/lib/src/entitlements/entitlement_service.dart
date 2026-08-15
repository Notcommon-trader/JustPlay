import 'dart:async';

/// What a player has bought.
enum Entitlement {
  /// No purchase. Ads on, hints limited.
  free,

  /// Ads removed, by subscription or one-off purchase. The app deliberately does
  /// not distinguish the two: every feature gate asks "is this player premium",
  /// and a gate that also had to know *how* they paid would be wrong the day the
  /// pricing changes.
  premium,
}

/// Whether the player has paid, and a stream of changes.
///
/// A subscription can lapse mid-session, a purchase can restore on another
/// device, and a grace period can end while the app is open. Anything that reads
/// this as a one-time value at startup will eventually show ads to a paying
/// customer, which is the single worst monetisation bug there is.
abstract class EntitlementService {
  Entitlement get entitlement;

  bool get isPremium => entitlement == Entitlement.premium;

  Stream<Entitlement> get changes;

  /// Brings local state in line with the store. Called at launch and on resume.
  Future<Entitlement> refresh();

  /// Restores purchases made on another device or a previous install.
  ///
  /// Required by both stores, and the first thing a paying customer looks for
  /// after reinstalling.
  Future<Entitlement> restore();
}

/// Everyone is free. The implementation used until a billing SDK lands.
///
/// Not a stub that returns premium "for testing": a service that silently grants
/// entitlements is how a build ships with paywalls disabled.
class FreeEntitlementService implements EntitlementService {
  final StreamController<Entitlement> _controller =
      StreamController<Entitlement>.broadcast();

  @override
  Entitlement get entitlement => Entitlement.free;

  @override
  bool get isPremium => false;

  @override
  Stream<Entitlement> get changes => _controller.stream;

  @override
  Future<Entitlement> refresh() async => entitlement;

  @override
  Future<Entitlement> restore() async => entitlement;

  void dispose() => _controller.close();
}

/// Entitlements held in memory, for tests and for local development.
///
/// Lets a widget test drive the premium path without a store, which is the only
/// way that path gets exercised before billing exists.
class FakeEntitlementService implements EntitlementService {
  FakeEntitlementService([this._entitlement = Entitlement.free]);

  Entitlement _entitlement;
  final StreamController<Entitlement> _controller =
      StreamController<Entitlement>.broadcast();

  @override
  Entitlement get entitlement => _entitlement;

  @override
  bool get isPremium => _entitlement == Entitlement.premium;

  @override
  Stream<Entitlement> get changes => _controller.stream;

  set entitlement(Entitlement next) {
    if (next == _entitlement) return;
    _entitlement = next;
    _controller.add(next);
  }

  @override
  Future<Entitlement> refresh() async => _entitlement;

  @override
  Future<Entitlement> restore() async => _entitlement;

  void dispose() => _controller.close();
}
