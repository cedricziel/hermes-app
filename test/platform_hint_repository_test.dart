import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/platform_hint/platform_hint_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late PlatformHintRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = PlatformHintRepository(
      server.client().raw,
      text: 'current text',
      earlierTexts: const ['old text'],
    );
  });

  void config(String profile, Object? body, {int status = 200}) => server.on(
    'GET',
    '/api/config',
    body,
    status: status,
    query: {'profile': profile, 'include_defaults': 'false'},
  );

  group('state', () {
    test('a profile without the key needs the hint', () async {
      config('work', {'model': 'x'});

      expect(await repository.state('work'), PlatformHintState.missing);
    });

    test('a profile holding an earlier app text needs the update', () async {
      config('work', {
        'platform_hints': {
          'hermes_app': {'replace': 'old text'},
        },
      });

      expect(await repository.state('work'), PlatformHintState.outdated);
    });

    test('a profile holding the current text is done', () async {
      config('work', {
        'platform_hints': {
          'hermes_app': {'replace': 'current text'},
        },
      });

      expect(await repository.state('work'), PlatformHintState.current);
    });

    test('any other value belongs to someone else', () async {
      for (final value in [
        'append this',
        {'replace': 'my own words'},
        {'append': 'old text'},
        {'replace': 'old text', 'append': 'more'},
      ]) {
        config('work', {
          'platform_hints': {'hermes_app': value},
        });

        expect(
          await repository.state('work'),
          PlatformHintState.foreign,
          reason: '$value',
        );
      }
    });

    test('a config that cannot be read is null', () async {
      config('work', {'detail': 'nope'}, status: 500);

      expect(await repository.state('work'), isNull);
    });
  });

  test('write sends only the app hint key for that profile', () async {
    server.on('PUT', '/api/config', {'ok': true});

    await repository.write('work');

    final request = server.requestsTo('PUT', '/api/config').single;
    expect(request.queryParameters['profile'], 'work');
    expect(jsonBody(request), {
      'config': {
        'platform_hints': {
          'hermes_app': {'replace': 'current text'},
        },
      },
    });
  });
}
