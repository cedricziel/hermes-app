import 'dart:async';

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

  test(
    'selecting a recipient moves the chat without mutating profiles',
    () async {
      final moved = <String>[];
      profiles
        ..attach(moved.add)
        ..showing('default');

      expect(await profiles.switchTo('work'), isTrue);

      expect(profiles.current, 'work');
      expect(moved, ['work']);
      expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
    },
  );

  test('selecting the current recipient leaves the chat untouched', () async {
    final moved = <String>[];
    profiles
      ..attach(moved.add)
      ..showing('default');

    expect(await profiles.switchTo('default'), isTrue);

    expect(moved, isEmpty);
    expect(server.requests, isEmpty);
  });

  test('a failed availability read preserves the recipient', () async {
    server.on('GET', '/api/profiles', {'detail': 'no'}, status: 500);
    final moved = <String>[];
    profiles
      ..attach(moved.add)
      ..showing('default');

    expect(await profiles.switchTo('work'), isFalse);

    expect(profiles.current, 'default');
    expect(moved, isEmpty);
    expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
  });

  test('a removed recipient cannot become the chat owner', () async {
    server.on(
      'GET',
      '/api/profiles',
      profileListBody([profileRow(name: 'default')]),
    );
    final moved = <String>[];
    profiles
      ..attach(moved.add)
      ..showing('default');

    expect(await profiles.switchTo('work'), isFalse);

    expect(profiles.current, 'default');
    expect(moved, isEmpty);
  });

  test('a delayed selection cannot replace a newer recipient', () async {
    final delayed = Completer<FakeResponse>();
    server.onRequest('GET', '/api/profiles', (_) => delayed.future);
    final moved = <String>[];
    profiles
      ..attach(moved.add)
      ..showing('default');
    final previous = profiles.switchTo('work');
    await Future<void>.delayed(Duration.zero);
    server.on(
      'GET',
      '/api/profiles',
      profileListBody([
        profileRow(name: 'default'),
        profileRow(name: 'work'),
        profileRow(name: 'travel'),
      ]),
    );

    expect(await profiles.switchTo('travel'), isTrue);
    delayed.complete((
      status: 200,
      body: profileListBody([
        profileRow(name: 'default'),
        profileRow(name: 'work'),
      ]),
    ));
    await previous;

    expect(profiles.current, 'travel');
    expect(moved, ['travel']);
  });

  test(
    'a completed previous load cannot reject the latest recipient',
    () async {
      final delayed = Completer<FakeResponse>();
      server.onRequest('GET', '/api/profiles', (_) => delayed.future);
      final moved = <String>[];
      profiles
        ..attach(moved.add)
        ..showing('default');
      final selected = profiles.switchTo('work');

      profiles.showing('travel');
      expect(profiles.current, 'default');
      delayed.complete((
        status: 200,
        body: profileListBody([
          profileRow(name: 'default'),
          profileRow(name: 'work'),
          profileRow(name: 'travel'),
        ]),
      ));

      expect(await selected, isTrue);
      expect(profiles.current, 'work');
      expect(moved, ['work']);
    },
  );

  test(
    'failed validation restores the profile the chat finished loading',
    () async {
      final delayed = Completer<FakeResponse>();
      server.onRequest('GET', '/api/profiles', (_) => delayed.future);
      final moved = <String>[];
      profiles
        ..attach(moved.add)
        ..showing('default');
      final selected = profiles.switchTo('work');

      profiles.showing('travel');
      expect(profiles.current, 'default');
      delayed.complete((status: 500, body: {'detail': 'unavailable'}));

      expect(await selected, isFalse);
      expect(profiles.current, 'travel');
      expect(moved, isEmpty);
    },
  );

  test('creating lists the profiles again', () async {
    server.on('POST', '/api/profiles', {'ok': true, 'name': 'travel'});
    await profiles.create('travel');
    expect(server.requestsTo('GET', '/api/profiles'), hasLength(1));
  });
}
