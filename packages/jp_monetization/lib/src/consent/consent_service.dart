import 'dart:async';

import 'package:flutter/foundation.dart';

/// What the player has agreed to.
///
/// Deliberately not a bool. "Has the player consented" is three states, not two,
/// and collapsing them is how an app ends up showing a consent dialog on every
/// launch, or worse, treating "not asked yet" as "yes".
enum ConsentStatus {
  /// Never asked. Nothing that needs consent may initialise.
  unknown,

  /// Asked and declined. Ads may still run, but only non-personalised ones.
  declined,

  /// Asked and granted.
  granted,

  /// Consent does not apply in this jurisdiction, so nothing was asked.
  notRequired,
}

/// Gates everything that touches a player's data.
///
/// **Nothing that needs consent initialises before this resolves.** That is the
/// whole reason this is a port with an explicit `unknown` state rather than a
/// flag read at startup: an ad SDK that initialises first and asks later has
/// already sent an identifier, and no dialog after the fact undoes that.
///
/// This is *not* a certified CMP. Google requires a certified Consent Management
/// Platform for serving personalised ads in the EEA and UK — the User Messaging
/// Platform SDK is the usual answer. This interface is the seam that CMP plugs
/// into; it is not a substitute for one, and shipping ads to Europe without one
/// is a policy violation.
abstract class ConsentService {
  ConsentStatus get status;

  /// Fires on every change, so services can start or stop as consent moves.
  Stream<ConsentStatus> get changes;

  /// Whether personalised advertising is permitted right now.
  bool get allowsPersonalisedAds;

  /// Whether analytics may collect anything.
  bool get allowsAnalytics;

  /// Asks, if asking is required. Safe to call on every launch: an implementation
  /// that has already resolved returns without showing anything.
  Future<ConsentStatus> requestIfNeeded();

  /// Reopens the choice. A privacy regime that lets a player consent must let
  /// them withdraw just as easily, and store policy requires the control to be
  /// reachable from the app.
  Future<ConsentStatus> reopen();
}

/// Consent for builds with nothing to consent to.
///
/// Reports [ConsentStatus.notRequired] because that is the truth for an app with
/// no ads, no analytics and purely local storage — not `granted`, which would
/// claim permission nobody gave.
class NoConsentRequired implements ConsentService {
  final StreamController<ConsentStatus> _controller =
      StreamController<ConsentStatus>.broadcast();

  @override
  ConsentStatus get status => ConsentStatus.notRequired;

  @override
  Stream<ConsentStatus> get changes => _controller.stream;

  @override
  bool get allowsPersonalisedAds => false;

  @override
  bool get allowsAnalytics => false;

  @override
  Future<ConsentStatus> requestIfNeeded() async => status;

  @override
  Future<ConsentStatus> reopen() async => status;

  @visibleForTesting
  void dispose() => _controller.close();
}
