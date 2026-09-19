import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesProfilesRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesProfilesRepository(server.client().raw);
  });

  group('load', () {
    test('maps profile rows and reports the active profile', () async {
      server
        ..on(
          'GET',
          '/api/profiles',
          profileListBody([
            profileRow(name: 'default', isDefault: true),
            profileRow(
              name: 'work',
              model: 'hermes-4',
              provider: 'nous',
              description: 'Day job',
              skillCount: 12,
              gatewayRunning: true,
            ),
          ]),
        )
        ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'));

      final overview = await repository.load();

      expect(overview.active, 'work');
      expect(overview.profiles.map((p) => p.name), ['default', 'work']);
      final work = overview.profiles.last;
      expect(work.model, 'hermes-4');
      expect(work.provider, 'nous');
      expect(work.description, 'Day job');
      expect(work.skillCount, 12);
      expect(work.gatewayRunning, isTrue);
      expect(overview.profiles.first.isDefault, isTrue);
    });

    test('reports the profile the dashboard is scoped to', () async {
      server
        ..on('GET', '/api/profiles', profileListBody([]))
        ..on(
          'GET',
          '/api/profiles/active',
          activeProfileBody(active: 'work', current: 'default'),
        );

      final overview = await repository.load();

      expect(overview.current, 'default');
    });

    test('labels a profile with its display name when it has one', () async {
      server
        ..on(
          'GET',
          '/api/profiles',
          profileListBody([
            profileRow(name: 'work', displayName: 'Work assistant'),
            profileRow(name: 'play'),
          ]),
        )
        ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'));

      final overview = await repository.load();

      expect(overview.profiles.map((p) => p.label), ['Work assistant', 'play']);
    });

    test('surfaces a server error as a DioException', () async {
      server.on('GET', '/api/profiles', {'detail': 'boom'}, status: 500);

      expect(repository.load(), throwsA(isA<DioException>()));
    });
  });

  group('setActive', () {
    test('posts the chosen profile name', () async {
      server.on('POST', '/api/profiles/active', {'active': 'work'});

      await repository.setActive('work');

      final request = server.requestsTo('POST', '/api/profiles/active').single;
      expect(jsonBody(request), {'name': 'work'});
    });

    test('surfaces a rejected switch as a DioException', () async {
      server.on('POST', '/api/profiles/active', {
        'detail': 'No such profile',
      }, status: 404);

      expect(repository.setActive('nope'), throwsA(isA<DioException>()));
    });
  });
}
