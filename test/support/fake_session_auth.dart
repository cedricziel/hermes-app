import 'dart:async';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/verified_session_owner.dart';

import 'memory_token_store.dart';

const testSessionOwner = VerifiedSessionOwner(
  server: 'https://queue.test',
  user: 'owner',
  organization: '',
  provider: 'oidc',
);

class FakeSessionAuth extends AuthController {
  FakeSessionAuth() : super(tokenStore: MemoryTokenStore());
  final departures = StreamController<void>.broadcast(sync: true);
  bool allowed = true;
  bool expired = false;
  var expiry = 0;
  var generation = 0;
  var currentState = HermesConnectionState.ready;
  VerifiedSessionOwner owner = testSessionOwner;
  @override
  String get baseUrl => testSessionOwner.server;
  @override
  HermesConnectionState get state => currentState;
  @override
  bool get protectedRequestsAllowed => allowed;
  @override
  VerifiedSessionOwner get verifiedOwner => owner;
  @override
  VerifiedSessionOwner? get expiredOwner => expired ? owner : null;
  @override
  int get ownerGeneration => generation;
  @override
  int get sessionExpiryGeneration => expiry;
  @override
  bool get sessionExpired => expired;
  @override
  Stream<void> get signedOut => departures.stream;
  void expire() {
    expiry++;
    expired = true;
    allowed = false;
    notifyListeners();
    currentState = HermesConnectionState.needsLogin;
    departures.add(null);
    notifyListeners();
  }

  void recover([VerifiedSessionOwner next = testSessionOwner]) {
    owner = next;
    currentState = HermesConnectionState.ready;
    allowed = true;
    expired = false;
    notifyListeners();
  }

  void depart() {
    generation++;
    allowed = false;
    expired = false;
    currentState = HermesConnectionState.needsLogin;
    notifyListeners();
    departures.add(null);
  }

  @override
  void dispose() {
    unawaited(departures.close());
    super.dispose();
  }
}
