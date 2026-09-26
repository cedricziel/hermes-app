import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/models/model_provider_option.dart';
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
              description: 'Day job',
              skillCount: 12,
            ),
          ]),
        )
        ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'));

      final overview = await repository.load();

      expect(overview.active, 'work');
      expect(overview.profiles.map((p) => p.name), ['default', 'work']);
      final work = overview.profiles.last;
      expect(work.model, 'hermes-4');
      expect(work.description, 'Day job');
      expect(work.skillCount, 12);
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

    test('reads the active profile without listing them', () async {
      server.on(
        'GET',
        '/api/profiles/active',
        activeProfileBody(active: 'work', current: 'default'),
      );

      final active = await repository.loadActive();

      expect(active.active, 'work');
      expect(active.current, 'default');
      expect(server.requestsTo('GET', '/api/profiles'), isEmpty);
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

  group('setModel', () {
    test('puts the provider and model under the encoded name', () async {
      server.on('PUT', '/api/profiles/my%20work/model', {
        'ok': true,
        'provider': 'openrouter',
        'model': 'gpt-5',
      });

      await repository.setModel(
        'my work',
        const ModelChoice('openrouter', 'gpt-5', effort: 'high'),
      );

      final request = server
          .requestsTo('PUT', '/api/profiles/my%20work/model')
          .single;
      expect(jsonBody(request), {'provider': 'openrouter', 'model': 'gpt-5'});
    });

    test('surfaces a refused model as a DioException', () async {
      server.on('PUT', '/api/profiles/work/model', {
        'detail': 'provider not configured',
      }, status: 400);

      expect(
        repository.setModel('work', const ModelChoice('x', 'y')),
        throwsA(isA<DioException>()),
      );
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
