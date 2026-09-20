import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesSkillsHubRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesSkillsHubRepository(server.client().raw);
  });

  group('overview', () {
    test('reads the official catalog and the featured skills', () async {
      server
        ..on('GET', '/api/skills/hub/official', {
          'skills': [
            hubSkillRow(
              name: 'web-research',
              identifier: 'official/web/web-research',
              source: 'official',
              trustLevel: 'builtin',
              category: 'web',
              tags: ['search'],
              installed: true,
            ),
            {'name': 'no-identifier'},
            {'identifier': 'x/y'},
          ],
        })
        ..on('GET', '/api/skills/hub/sources', {
          'sources': [
            {'id': 'official', 'label': 'Official (Nous)'},
            {'id': 'github', 'label': 'GitHub', 'rate_limited': false},
          ],
          'index_available': true,
          'featured': [hubSkillRow(name: 'k8s-debug')],
          'installed': {
            'github/k8s-debug': {'name': 'k8s-debug'},
          },
        });

      final overview = await repository.overview(profile: 'work');

      expect(overview.official.map((s) => s.name), ['web-research']);
      expect(overview.official.single.tags, ['search']);
      expect(overview.official.single.installed, isTrue);
      expect(overview.official.single.trustLevel, 'builtin');
      expect(overview.featured.single.installed, isTrue);
      expect(overview.sources.map((s) => s.id), ['official', 'github']);
      expect(overview.sources.first.label, 'Official (Nous)');
      expect(
        server
            .requestsTo('GET', '/api/skills/hub/official')
            .single
            .queryParameters,
        {'profile': 'work'},
      );
    });

    test('still shows the catalog when the sources cannot be read', () async {
      server
        ..on('GET', '/api/skills/hub/official', {
          'skills': [hubSkillRow(name: 'a')],
        })
        ..on('GET', '/api/skills/hub/sources', {'detail': 'x'}, status: 502);

      final overview = await repository.overview();

      expect(overview.official, hasLength(1));
      expect(overview.featured, isEmpty);
      expect(overview.sources, isEmpty);
    });

    test('a bare 404 means the server has no hub', () async {
      expect(repository.overview(), throwsA(isA<SkillsUnsupported>()));
    });

    test('a failing catalog stays an error', () async {
      server.on('GET', '/api/skills/hub/official', {
        'detail': 'x',
      }, status: 502);

      expect(repository.overview(), throwsA(isA<DioException>()));
    });
  });

  group('search', () {
    test(
      'sends the text, source and profile and marks installed ones',
      () async {
        server.on('GET', '/api/skills/hub/search', {
          'results': [
            hubSkillRow(name: 'web-scraper'),
            {'name': 'nameless'},
          ],
          'source_counts': {'github': 1},
          'timed_out': ['clawhub'],
          'installed': {
            'github/web-scraper': {'name': 'web-scraper'},
          },
        });

        final result = await repository.search(
          'scrape',
          source: 'github',
          profile: 'work',
        );

        expect(result.results.single.name, 'web-scraper');
        expect(result.results.single.installed, isTrue);
        expect(result.timedOut, ['clawhub']);
        expect(
          server
              .requestsTo('GET', '/api/skills/hub/search')
              .single
              .queryParameters,
          {'q': 'scrape', 'source': 'github', 'limit': 20, 'profile': 'work'},
        );
      },
    );

    test('searches every source by default', () async {
      server.on('GET', '/api/skills/hub/search', {'results': []});

      await repository.search('x');

      expect(
        server
            .requestsTo('GET', '/api/skills/hub/search')
            .single
            .queryParameters['source'],
        'all',
      );
    });
  });

  group('preview', () {
    test('reads the SKILL.md and the file list', () async {
      server.on('GET', '/api/skills/hub/preview', {
        'name': 'web-scraper',
        'skill_md': '# Scraper',
        'files': ['SKILL.md', 'scripts/fetch.sh'],
      });

      final preview = await repository.preview('github/web-scraper');

      expect(preview.skillMd, '# Scraper');
      expect(preview.files, ['SKILL.md', 'scripts/fetch.sh']);
    });

    test('a reply without a SKILL.md is a format error', () async {
      server.on('GET', '/api/skills/hub/preview', {'name': 'x'});

      expect(repository.preview('x'), throwsFormatException);
    });
  });

  group('scan', () {
    test('reads verdict, policy and findings', () async {
      server.on(
        'GET',
        '/api/skills/hub/scan',
        hubScanBody(
          policy: 'ask',
          verdict: 'caution',
          summary: 'One script runs remote code',
          findings: [hubFindingRow()],
          counts: {'critical': 0, 'high': 1, 'medium': 0, 'low': 0},
        ),
      );

      final scan = await repository.scan('github/web-scraper', profile: 'w');

      expect(scan.identifier, 'github/web-scraper');
      expect(scan.policy, InstallPolicy.ask);
      expect(scan.verdict, 'caution');
      expect(scan.severityCounts['high'], 1);
      expect(
        scan.findings.single.description,
        'Downloads and runs a remote script',
      );
      expect(scan.findings.single.file, 'scripts/fetch.sh');
      expect(scan.findings.single.line, 12);
    });

    for (final policy in [null, '', 'maybe']) {
      test('policy $policy counts as block', () async {
        server.on('GET', '/api/skills/hub/scan', {
          ...hubScanBody(),
          'policy': policy,
        });

        expect((await repository.scan('x')).policy, InstallPolicy.block);
      });
    }

    test(
      'a skill the hub cannot find is a rejection, not unsupported',
      () async {
        server.on('GET', '/api/skills/hub/scan', {
          'detail': 'Skill not found',
        }, status: 404);

        expect(repository.scan('x'), throwsA(isA<SkillsRejected>()));
      },
    );
  });

  group('jobs', () {
    test(
      'install names the job and sends the identifier and profile',
      () async {
        server.on('POST', '/api/skills/hub/install', {
          'ok': true,
          'pid': 7,
          'name': 'skills-install-web-scraper',
        });

        final job = await repository.install(
          'github/web-scraper',
          profile: 'w',
        );

        expect(job.name, 'skills-install-web-scraper');
        expect(job.pid, 7);
        final request = server
            .requestsTo('POST', '/api/skills/hub/install')
            .single;
        expect(jsonBody(request), {
          'identifier': 'github/web-scraper',
          'profile': 'w',
        });
        expect(request.queryParameters, {'profile': 'w'});
      },
    );

    test('uninstall and update start jobs too', () async {
      server
        ..on('POST', '/api/skills/hub/uninstall', {'name': 'u'})
        ..on('POST', '/api/skills/hub/update', {'name': 'skills-update'});

      expect((await repository.uninstall('web-scraper')).name, 'u');
      expect((await repository.update(profile: 'w')).name, 'skills-update');
    });

    test('a reply without a job name is a format error', () async {
      server.on('POST', '/api/skills/hub/update', {'ok': true});

      expect(repository.update(), throwsFormatException);
    });

    test('status reads running, exit code and the log tail', () async {
      server.on(
        'GET',
        '/api/actions/skills-update/status',
        jobStatusBody(running: true, exitCode: null, lines: ['a', 'b']),
      );

      final status = (await repository.status('skills-update'))!;

      expect(status.running, isTrue);
      expect(status.exitCode, isNull);
      expect(status.pid, 4242);
      expect(status.lines, ['a', 'b']);
    });

    test('status of an unknown job is null', () async {
      server.on('GET', '/api/actions/gone/status', {
        'detail': 'Unknown action: gone',
      }, status: 404);

      expect(await repository.status('gone'), isNull);
    });

    test('other status failures stay errors', () async {
      server.on('GET', '/api/actions/x/status', {'detail': 'x'}, status: 500);

      expect(repository.status('x'), throwsA(isA<DioException>()));
    });
  });
}
