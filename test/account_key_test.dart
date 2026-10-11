import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/account_key.dart';
import 'package:hermes_app/src/models/hermes_session.dart';

HermesSession _session(String userId, {String access = 'a', int minted = 1}) =>
    HermesSession(
      accessToken: access,
      refreshToken: 'r',
      expiresAt: 1,
      provider: 'basic',
      userId: userId,
      mintedAt: minted,
    );

void main() {
  test('is the same for the same server and user', () {
    expect(
      accountKeyFor('https://hermes.example', _session('u1')),
      accountKeyFor('https://hermes.example', _session('u1')),
    );
  });

  test('does not change when the tokens are refreshed', () {
    expect(
      accountKeyFor('https://hermes.example', _session('u1')),
      accountKeyFor(
        'https://hermes.example',
        _session('u1', access: 'b', minted: 2),
      ),
    );
  });

  test('differs by server and by user', () {
    final key = accountKeyFor('https://hermes.example', _session('u1'));

    expect(accountKeyFor('https://other.example', _session('u1')), isNot(key));
    expect(accountKeyFor('https://hermes.example', _session('u2')), isNot(key));
  });

  test('holds neither the address nor the user', () {
    final key = accountKeyFor('https://hermes.example', _session('u1'));

    expect(key, isNot(contains('hermes')));
    expect(key, isNot(contains('u1')));
  });

  test('tells a server without sign-in from one with', () {
    expect(
      accountKeyFor('https://hermes.example', null),
      isNot(accountKeyFor('https://hermes.example', _session('u1'))),
    );
  });
}
