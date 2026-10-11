import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/account_key.dart';

void main() {
  test('is the same for the same server and user', () {
    expect(
      accountKeyFor('https://hermes.example', 'u1'),
      accountKeyFor('https://hermes.example', 'u1'),
    );
  });

  test('differs by server and by user', () {
    final key = accountKeyFor('https://hermes.example', 'u1');

    expect(accountKeyFor('https://other.example', 'u1'), isNot(key));
    expect(accountKeyFor('https://hermes.example', 'u2'), isNot(key));
  });

  test('holds neither the address nor the user', () {
    final key = accountKeyFor('https://hermes.example', 'u1');

    expect(key, isNot(contains('hermes')));
    expect(key, isNot(contains('u1')));
  });

  test('tells a server without a user from one with', () {
    expect(
      accountKeyFor('https://hermes.example', null),
      isNot(accountKeyFor('https://hermes.example', 'u1')),
    );
  });
}
