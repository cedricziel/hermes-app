import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/session_activity.dart';
import 'package:hermes_app/src/auth/verified_session_owner.dart';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _owner = VerifiedSessionOwner(
  server: 'https://test.invalid',
  user: 'u1',
  organization: '',
  provider: 'oidc',
);
const _other = VerifiedSessionOwner(
  server: 'https://test.invalid',
  user: 'u2',
  organization: '',
  provider: 'oidc',
);

class _Auth extends AuthController {
  HermesConnectionState currentState = HermesConnectionState.ready;
  bool allowed = true;
  VerifiedSessionOwner? owner = _owner;
  VerifiedSessionOwner? expired;
  int generation = 0;
  int expiry = 0;
  @override
  HermesConnectionState get state => currentState;
  @override
  bool get protectedRequestsAllowed => allowed;
  @override
  VerifiedSessionOwner? get verifiedOwner => owner;
  @override
  VerifiedSessionOwner? get expiredOwner => expired;
  @override
  int get ownerGeneration => generation;
  @override
  int get sessionExpiryGeneration => expiry;
  void update() => notifyListeners();
  void expire() {
    allowed = false;
    expired = owner;
    expiry++;
    update();
    currentState = HermesConnectionState.needsLogin;
    update();
  }

  void recover() {
    allowed = true;
    currentState = HermesConnectionState.ready;
    update();
  }
}

void main() {
  late _Auth auth;
  late SessionActivity activity;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    auth = _Auth();
    activity = SessionActivity(auth);
  });
  tearDown(() {
    activity.dispose();
    auth.dispose();
  });

  test('ready owner starts active and expiry closes immediately', () {
    expect(activity.value, isTrue);
    auth.expire();
    expect(activity.value, isFalse);
    expect(activity.retired, isFalse);
  });
  test('same owner resumes only after ready authorized proof', () {
    auth.expire();
    auth.currentState = HermesConnectionState.signingIn;
    auth.update();
    expect(activity.value, isFalse);
    auth.recover();
    expect(activity.value, isTrue);
    auth.expire();
    expect(activity.retired, isFalse);
    auth.recover();
    expect(activity.value, isTrue);
  });
  test('failed recovery phases remain suspended until verified ready', () {
    auth.expire();
    auth.currentState = HermesConnectionState.signingIn;
    auth.update();
    auth.currentState = HermesConnectionState.connectionError;
    auth.update();
    auth.currentState = HermesConnectionState.needsLogin;
    auth.update();
    expect(activity.value, isFalse);
    expect(activity.retired, isFalse);
    auth.recover();
    expect(activity.value, isTrue);
  });

  test('different owner retires permanently', () {
    auth.expire();
    auth.owner = _other;
    auth.recover();
    expect(activity.retired, isTrue);
    auth.owner = _owner;
    auth.recover();
    expect(activity.value, isFalse);
  });
  test('fresh expiry from another owner retires during recovery', () {
    auth.expire();
    auth.expired = _other;
    auth.expiry++;
    auth.update();
    expect(activity.retired, isTrue);
    auth.recover();
    expect(activity.value, isFalse);
  });

  test('missing verified owner cannot retain activity', () {
    auth.expire();
    auth.owner = null;
    auth.recover();
    expect(activity.retired, isTrue);
  });
  test('departure closes immediately despite state remaining ready', () {
    auth.allowed = false;
    auth.generation++;
    auth.update();
    expect(activity.retired, isTrue);
    expect(activity.value, isFalse);
    auth.recover();
    expect(activity.value, isFalse);
  });
  test('historical expiry cannot retain a later unrelated closure', () {
    auth.expire();
    auth.recover();
    auth.allowed = false;
    auth.currentState = HermesConnectionState.connecting;
    auth.update();
    expect(activity.retired, isTrue);
  });
  test('authorized connection check pauses without retiring', () {
    auth.currentState = HermesConnectionState.connecting;
    auth.update();
    expect(activity.value, isFalse);
    expect(activity.retired, isFalse);
    auth.recover();
    expect(activity.value, isTrue);
  });
  test('disposal closes activity and removes auth listener', () {
    var changes = 0;
    activity.addListener(() => changes++);
    activity.dispose();
    expect(activity.value, isFalse);
    expect(changes, 1);
    final disposedChanges = changes;
    auth.expire();
    expect(changes, disposedChanges);
    activity = SessionActivity(auth);
    expect(activity.value, isFalse);
  });
}
