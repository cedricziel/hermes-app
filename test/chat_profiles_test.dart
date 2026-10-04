import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late ChatProfiles profiles;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work'),
        ]),
      );
    profiles = ChatProfiles(HermesProfilesRepository(server.client().raw));
  });

  test('lists the profiles', () async {
    await profiles.load();
    expect(profiles.profiles.map((p) => p.name), ['default', 'work']);
    expect(profiles.failed, isFalse);
  });

  test('a switch sets the active profile and moves the chat', () async {
    server.on('POST', '/api/profiles/active', {'ok': true});
    final moved = <String>[];
    profiles
      ..attach(moved.add)
      ..showing('default');

    expect(await profiles.switchTo('work'), isTrue);

    expect(jsonBody(server.requestsTo('POST', '/api/profiles/active').single), {
      'name': 'work',
    });
    expect(profiles.current, 'work');
    expect(moved, ['work']);
  });

  test('a refused switch leaves the chat where it is', () async {
    server.on('POST', '/api/profiles/active', {'detail': 'no'}, status: 500);
    final moved = <String>[];
    profiles
      ..attach(moved.add)
      ..showing('default');

    expect(await profiles.switchTo('work'), isFalse);
    expect(profiles.current, 'default');
    expect(moved, isEmpty);
  });

  test('creating lists the profiles again', () async {
    server.on('POST', '/api/profiles', {'ok': true, 'name': 'travel'});
    await profiles.create('travel');
    expect(server.requestsTo('GET', '/api/profiles'), hasLength(1));
  });
}
