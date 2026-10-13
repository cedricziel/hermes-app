import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/verified_session_owner.dart';
import 'package:hermes_app/src/navigation/desktop_history_owner.dart';

void main() {
  const owner = VerifiedSessionOwner(
    server: 'server',
    user: 'user',
    organization: 'org',
    provider: 'password',
  );
  const other = VerifiedSessionOwner(
    server: 'server',
    user: 'other',
    organization: 'org',
    provider: 'password',
  );
  late DesktopHistoryOwner policy;
  setUp(() {
    policy = DesktopHistoryOwner();
    policy.update(
      ready: true,
      userGeneration: 0,
      server: 'server',
      owner: owner,
      expired: false,
      expiredOwner: null,
    );
  });
  test('same verified expiry retains history', () {
    expect(
      policy.update(
        ready: false,
        userGeneration: 0,
        server: 'server',
        owner: null,
        expired: true,
        expiredOwner: owner,
      ),
      isFalse,
    );
    expect(
      policy.update(
        ready: true,
        userGeneration: 0,
        server: 'server',
        owner: owner,
        expired: true,
        expiredOwner: owner,
      ),
      isFalse,
    );
  });
  test('unproven expiry clears history', () {
    expect(
      policy.update(
        ready: false,
        userGeneration: 0,
        server: 'server',
        owner: null,
        expired: true,
        expiredOwner: null,
      ),
      isTrue,
    );
  });
  test('explicit departure clears even after expiry', () {
    expect(
      policy.update(
        ready: false,
        userGeneration: 1,
        server: 'server',
        owner: null,
        expired: true,
        expiredOwner: owner,
      ),
      isTrue,
    );
  });
  test('different verified owner clears history', () {
    expect(
      policy.update(
        ready: true,
        userGeneration: 0,
        server: 'server',
        owner: other,
        expired: true,
        expiredOwner: owner,
      ),
      isTrue,
    );
  });
  test('server change clears history', () {
    expect(
      policy.update(
        ready: true,
        userGeneration: 0,
        server: 'other',
        owner: owner,
        expired: false,
        expiredOwner: null,
      ),
      isTrue,
    );
  });
}
