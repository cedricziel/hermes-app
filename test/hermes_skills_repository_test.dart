import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesSkillsRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesSkillsRepository(server.client().raw);
  });

  group('list', () {
    test('maps rows and sends the profile', () async {
      server.on('GET', '/api/skills', [
        skillRow(
          name: 'apple-notes',
          description: 'Notes',
          category: 'apple',
          usage: 14,
        ),
        skillRow(name: 'pr', provenance: 'agent', enabled: false),
        skillRow(name: 'compose', provenance: 'hub'),
      ]);

      final skills = await repository.list(profile: 'work');

      expect(skills.map((s) => s.name), ['apple-notes', 'pr', 'compose']);
      expect(skills[0].category, 'apple');
      expect(skills[0].usage, 14);
      expect(skills[0].source, SkillSource.bundled);
      expect(skills[1].source, SkillSource.agent);
      expect(skills[1].enabled, isFalse);
      expect(skills[1].editable, isTrue);
      expect(skills[2].source, SkillSource.hub);
      expect(skills[2].editable, isFalse);
      expect(server.requestsTo('GET', '/api/skills').single.queryParameters, {
        'profile': 'work',
      });
    });

    test(
      'treats a missing category as none and unknown provenance as bundled',
      () async {
        server.on('GET', '/api/skills', [
          skillRow(name: 'a', category: null, provenance: 'future'),
        ]);

        final skill = (await repository.list()).single;

        expect(skill.category, '');
        expect(skill.source, SkillSource.bundled);
      },
    );

    test('skips rows without a name', () async {
      server.on('GET', '/api/skills', [
        {'description': 'nameless'},
        {'name': ''},
        {'name': 7},
        skillRow(name: 'ok'),
      ]);

      expect((await repository.list()).map((s) => s.name), ['ok']);
    });

    test('an envelope that is not a list gives no skills', () async {
      server.on('GET', '/api/skills', {'skills': []});

      expect(await repository.list(), isEmpty);
    });

    test('a 404 means the server has no skills', () async {
      expect(repository.list(), throwsA(isA<SkillsUnsupported>()));
    });

    test('other failures stay errors', () async {
      server.on('GET', '/api/skills', {'detail': 'boom'}, status: 500);

      expect(repository.list(), throwsA(isA<DioException>()));
    });
  });

  group('content', () {
    test('reads the SKILL.md of a skill', () async {
      server.on('GET', '/api/skills/content', {
        'name': 'pr',
        'content': '# PR',
        'path': '/x',
      });

      expect(await repository.content('pr', profile: 'work'), '# PR');
      expect(
        server.requestsTo('GET', '/api/skills/content').single.queryParameters,
        {'name': 'pr', 'profile': 'work'},
      );
    });

    test('a reply without content is a format error', () async {
      server.on('GET', '/api/skills/content', {'name': 'pr'});

      expect(repository.content('pr'), throwsFormatException);
    });
  });

  test('setEnabled sends name, state and profile', () async {
    server.on('PUT', '/api/skills/toggle', {'ok': true});

    await repository.setEnabled('pr', false, profile: 'work');

    expect(jsonBody(server.requestsTo('PUT', '/api/skills/toggle').single), {
      'name': 'pr',
      'enabled': false,
      'profile': 'work',
    });
  });

  group('save', () {
    test('sends the whole text', () async {
      server.on('PUT', '/api/skills/content', {'success': true});

      await repository.save('pr', '# New', profile: 'work');

      expect(jsonBody(server.requestsTo('PUT', '/api/skills/content').single), {
        'name': 'pr',
        'content': '# New',
        'profile': 'work',
      });
    });

    test('a refusal carries the dashboard\'s reason', () async {
      server.on('PUT', '/api/skills/content', {
        'detail': 'Blocked',
      }, status: 400);

      expect(
        repository.save('pr', 'x'),
        throwsA(
          isA<SkillsRejected>().having((e) => e.message, 'message', 'Blocked'),
        ),
      );
    });

    test('a server error stays an error', () async {
      server.on('PUT', '/api/skills/content', {'detail': 'boom'}, status: 500);

      expect(repository.save('pr', 'x'), throwsA(isA<DioException>()));
    });
  });

  group('create', () {
    test('sends name, text, category and profile', () async {
      server.on('POST', '/api/skills', {'success': true});

      await repository.create('pr', '# PR', category: 'github', profile: 'w');

      expect(jsonBody(server.requestsTo('POST', '/api/skills').single), {
        'name': 'pr',
        'content': '# PR',
        'category': 'github',
        'profile': 'w',
      });
    });

    test('leaves an empty category out', () async {
      server.on('POST', '/api/skills', {'success': true});

      await repository.create('pr', '# PR', category: '');

      expect(jsonBody(server.requestsTo('POST', '/api/skills').single), {
        'name': 'pr',
        'content': '# PR',
      });
    });

    test('a refused name carries the reason', () async {
      server.on('POST', '/api/skills', {'detail': 'exists'}, status: 400);

      expect(repository.create('pr', 'x'), throwsA(isA<SkillsRejected>()));
    });
  });
}
