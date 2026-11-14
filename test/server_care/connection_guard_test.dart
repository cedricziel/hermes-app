import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/server_care/connection_guard.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Auth extends AuthController {
  _Auth({HermesConnectionState state = HermesConnectionState.ready})
    : _state = state; // ignore: prefer_initializing_formals

  HermesConnectionState _state;
  int _owner = 0;
  bool _allowed = true;

  @override
  HermesConnectionState get state => _state;
  @override
  bool get protectedRequestsAllowed => _allowed;
  @override
  int get ownerGeneration => _owner;

  void leave() {
    _state = HermesConnectionState.needsLogin;
    notifyListeners();
  }

  void otherOwner() {
    _owner++;
    notifyListeners();
  }

  void close() {
    _allowed = false;
    notifyListeners();
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('the session ending is reported once', () {
    final auth = _Auth();
    addTearDown(auth.dispose);
    var ended = 0;
    final guard = ConnectionGuard(auth, () => ended++);
    addTearDown(guard.dispose);
    expect(guard.ended, isFalse);
    auth.leave();
    auth.leave();
    expect(ended, 1);
    expect(guard.ended, isTrue);
  });

  test('another owner or closed protected requests end it', () {
    final owner = _Auth();
    addTearDown(owner.dispose);
    var a = 0;
    ConnectionGuard(owner, () => a++);
    owner.otherOwner();
    expect(a, 1);

    final closed = _Auth();
    addTearDown(closed.dispose);
    var b = 0;
    ConnectionGuard(closed, () => b++);
    closed.close();
    expect(b, 1);
  });

  test('an auth that was not ready only ends by a change of owner', () {
    final auth = _Auth(state: HermesConnectionState.needsLogin);
    addTearDown(auth.dispose);
    var ended = 0;
    ConnectionGuard(auth, () => ended++);
    auth.close();
    expect(ended, 0);
    auth.otherOwner();
    expect(ended, 1);
  });

  test('without an auth controller nothing ends', () {
    var ended = 0;
    final guard = ConnectionGuard(null, () => ended++)..dispose();
    expect(ended, 0);
    expect(guard.ended, isFalse);
  });

  test('a disposed guard says nothing', () {
    final auth = _Auth();
    addTearDown(auth.dispose);
    var ended = 0;
    ConnectionGuard(auth, () => ended++).dispose();
    auth.leave();
    expect(ended, 0);
  });
}
