import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart' show AppEventLogger;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skill_job.dart';
import 'package:hermes_app/src/skills/skills_controller.dart';
import 'package:hermes_app/src/skills/skills_hub_controller.dart';

import 'support/fake_hermes_server.dart';

/// Waits, without a fixed delay, until [done] holds.
Future<void> until(bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late FakeHermesServer server;
  late List<(String, Map<String, Object>)> events;
  late SkillsController skills;

  HubScan scanOf(InstallPolicy policy, {String id = 'github/web-scraper'}) =>
      HubScan(identifier: id, policy: policy);

  const scraper = HubSkill(
    name: 'web-scraper',
    identifier: 'github/web-scraper',
    source: 'github',
  );

  SkillsHubController hub({
    Duration debounce = const Duration(milliseconds: 20),
    AppEventLogger? logger,
  }) => SkillsHubController(
    repository: HermesSkillsHubRepository(server.client().raw),
    skills: skills,
    debounce: debounce,
    events:
        logger ??
        (name, [attributes = const {}]) => events.add((name, attributes)),
    newJob: (title, start, status) => SkillJob(
      title: title,
      start: start,
      status: status,
      wait: (_) async {},
    ),
  );

  setUp(() async {
    events = [];
    server = FakeHermesServer()
      ..on('GET', '/api/skills', [skillRow(name: 'local')])
      ..on('GET', '/api/skills/hub/official', {
        'skills': [
          hubSkillRow(
            name: 'web-research',
            identifier: 'official/web/web-research',
            source: 'official',
          ),
          hubSkillRow(name: 'k8s-debug', identifier: 'github/k8s-debug'),
        ],
      })
      ..on('GET', '/api/skills/hub/sources', {
        'sources': [
          {'id': 'official', 'label': 'Official (Nous)'},
          {'id': 'github', 'label': 'GitHub'},
        ],
        'featured': [
          hubSkillRow(name: 'k8s-debug', identifier: 'github/k8s-debug'),
        ],
        'installed': {},
      })
      ..on('GET', '/api/skills/hub/search', {
        'results': [hubSkillRow(name: 'web-scraper')],
        'timed_out': ['clawhub'],
        'installed': {},
      });
    skills = SkillsController(
      repository: HermesSkillsRepository(server.client().raw),
      chatProfile: 'work',
    );
    await skills.load();
  });

  group('discover', () {
    test(
      'shows featured skills, then the rest of the official catalog',
      () async {
        final c = hub();
        await c.load();

        expect(c.status, HubStatus.ready);
        expect(c.featured.map((s) => s.name), ['k8s-debug']);
        expect(c.official.map((s) => s.name), ['web-research']);
        expect(c.sources.map((s) => s.id), ['official', 'github']);
      },
    );

    test('a source chip narrows the list without another request', () async {
      final c = hub();
      await c.load();
      c.setSource('official');

      expect(c.featured, isEmpty);
      expect(c.official.map((s) => s.name), ['web-research']);
      expect(
        server.requestsTo('GET', '/api/skills/hub/official'),
        hasLength(1),
      );
    });

    test('a failing catalog is reported and Retry can recover', () async {
      server.on('GET', '/api/skills/hub/official', {
        'detail': 'x',
      }, status: 502);
      final c = hub();
      await c.load();
      expect(c.status, HubStatus.failed);

      server.on('GET', '/api/skills/hub/official', {'skills': []});
      await c.load();
      expect(c.status, HubStatus.ready);
    });

    test('a server without the hub is told so', () async {
      server = FakeHermesServer();
      final c = SkillsHubController(
        repository: HermesSkillsHubRepository(server.client().raw),
        skills: skills,
      );
      await c.load();

      expect(c.status, HubStatus.unsupported);
    });
  });

  group('search', () {
    test('waits for a pause and searches once, for the profile', () async {
      final c = hub();
      await c.load();

      c.setQuery('s');
      c.setQuery('sc');
      c.setQuery('scrape');
      await until(() => c.results.isNotEmpty);

      final requests = server.requestsTo('GET', '/api/skills/hub/search');
      expect(requests, hasLength(1));
      expect(requests.single.queryParameters['q'], 'scrape');
      expect(requests.single.queryParameters['profile'], 'work');
      expect(c.results.map((s) => s.name), ['web-scraper']);
      expect(c.timedOut, ['clawhub']);
      expect(c.featured, isEmpty);
    });

    test('a slow reply for old text does not replace a newer one', () async {
      final slow = Completer<FakeResponse>();
      server.onRequest(
        'GET',
        '/api/skills/hub/search',
        (_) => slow.future,
        query: {'q': 'old'},
      );
      server.on(
        'GET',
        '/api/skills/hub/search',
        {
          'results': [hubSkillRow(name: 'new-one')],
        },
        query: {'q': 'new'},
      );
      final c = hub(debounce: Duration.zero);
      await c.load();

      c.setQuery('old');
      await until(
        () => server.requestsTo('GET', '/api/skills/hub/search').isNotEmpty,
      );
      c.setQuery('new');
      await until(
        () => server.requestsTo('GET', '/api/skills/hub/search').length == 2,
      );
      slow.complete((
        status: 200,
        body: {
          'results': [hubSkillRow(name: 'stale')],
        },
      ));
      await until(() => c.results.isNotEmpty && !c.searching);

      expect(c.results.map((s) => s.name), ['new-one']);
    });

    test('clearing the text goes back to the featured list', () async {
      final c = hub();
      await c.load();
      c.setQuery('scrape');
      await until(() => c.results.isNotEmpty);

      c.setQuery('');

      expect(c.isSearch, isFalse);
      expect(c.results, isEmpty);
      expect(c.featured, isNotEmpty);
    });

    test('a failing search is reported and can be retried', () async {
      server.on('GET', '/api/skills/hub/search', {'detail': 'x'}, status: 502);
      final c = hub(debounce: Duration.zero);
      await c.load();
      c.setQuery('x');
      await until(() => c.searchFailed);
      expect(c.searchFailed, isTrue);

      server.on('GET', '/api/skills/hub/search', {'results': []});
      await c.retrySearch();
      expect(c.searchFailed, isFalse);
    });

    test('a source chip searches that source', () async {
      final c = hub(debounce: Duration.zero);
      await c.load();
      c.setQuery('x');
      await until(() => !c.searching);

      c.setSource('github');
      await until(
        () => server.requestsTo('GET', '/api/skills/hub/search').length == 2,
      );

      expect(
        server
            .requestsTo('GET', '/api/skills/hub/search')
            .last
            .queryParameters['source'],
        'github',
      );
    });
  });

  group('the install gate', () {
    test('permits only a scan of that skill that allows it', () {
      bool ok(
        HubScan? scan, {
        bool confirmed = false,
        String id = 'github/web-scraper',
      }) => SkillsHubController.permits(scan, id, confirmed: confirmed);

      expect(ok(null), isFalse);
      expect(ok(scanOf(InstallPolicy.allow)), isTrue);
      expect(ok(scanOf(InstallPolicy.allow, id: 'github/other')), isFalse);
      expect(ok(scanOf(InstallPolicy.ask)), isFalse);
      expect(ok(scanOf(InstallPolicy.ask), confirmed: true), isTrue);
      expect(ok(scanOf(InstallPolicy.block), confirmed: true), isFalse);
    });

    test('a refused install sends nothing', () async {
      final c = hub();
      await c.load();

      expect(c.install(scraper, null), isNull);
      expect(c.install(scraper, scanOf(InstallPolicy.ask)), isNull);
      expect(
        c.install(scraper, scanOf(InstallPolicy.block), confirmed: true),
        isNull,
      );
      expect(server.requestsTo('POST', '/api/skills/hub/install'), isEmpty);
    });
  });

  group('jobs', () {
    void jobRoutes({int exitCode = 0}) {
      server
        ..on('POST', '/api/skills/hub/install', {
          'ok': true,
          'pid': 4242,
          'name': 'skills-install-web-scraper',
        })
        ..on(
          'GET',
          '/api/actions/skills-install-web-scraper/status',
          jobStatusBody(exitCode: exitCode, lines: ['done']),
        );
    }

    test('the job outcome is logged without an identifier or name', () async {
      jobRoutes();
      final c = hub();
      await c.load();

      c.install(scraper, scanOf(InstallPolicy.allow));
      await until(
        () => server.requestsTo('GET', '/api/skills/hub/official').length == 2,
      );

      expect(events.single.$1, 'skills.job');
      expect(events.single.$2, {
        'op': 'install',
        'source': 'github',
        'trust_level': 'community',
        'policy': 'allow',
        'result': 'ok',
      });
      expect(server.requestsTo('GET', '/api/skills'), hasLength(2));
      expect(
        server.requestsTo('GET', '/api/skills/hub/official'),
        hasLength(2),
      );
    });

    test('a failed job is logged as failed and still refreshes', () async {
      jobRoutes(exitCode: 1);
      final c = hub();
      await c.load();

      c.install(scraper, scanOf(InstallPolicy.allow));
      await until(() => server.requestsTo('GET', '/api/skills').length == 2);

      expect(c.job!.state, JobState.failed);
      expect(events.single.$2['result'], 'failed');
      expect(server.requestsTo('GET', '/api/skills'), hasLength(2));
    });

    test('one job at a time', () async {
      final gate = Completer<FakeResponse>();
      server
        ..on('POST', '/api/skills/hub/install', {'pid': 1, 'name': 'j'})
        ..onRequest('GET', '/api/actions/j/status', (_) => gate.future);
      final c = hub();
      await c.load();

      c.install(scraper, scanOf(InstallPolicy.allow));
      await until(
        () => server.requestsTo('GET', '/api/actions/j/status').isNotEmpty,
      );

      expect(c.busy, isTrue);
      expect(c.install(scraper, scanOf(InstallPolicy.allow)), isNull);
      expect(c.uninstall('web-scraper'), isNull);
      expect(c.update(), isNull);
      gate.complete((status: 200, body: jobStatusBody(name: 'j', pid: 1)));
      await until(() => !c.busy);
      expect(c.busy, isFalse);
    });

    test('uninstall and update start jobs for the profile', () async {
      server
        ..on('POST', '/api/skills/hub/uninstall', {'pid': 1, 'name': 'u'})
        ..on('POST', '/api/skills/hub/update', {'pid': 2, 'name': 'up'})
        ..on('GET', '/api/actions/u/status', jobStatusBody(name: 'u', pid: 1))
        ..on(
          'GET',
          '/api/actions/up/status',
          jobStatusBody(name: 'up', pid: 2),
        );
      final c = hub();
      await c.load();

      c.uninstall('web-scraper');
      await until(() => events.length == 1);
      c.update();
      await until(() => events.length == 2);

      expect(
        jsonBody(server.requestsTo('POST', '/api/skills/hub/uninstall').single),
        {'name': 'web-scraper', 'profile': 'work'},
      );
      expect(server.requestsTo('POST', '/api/skills/hub/update'), hasLength(1));
      expect(events.map((e) => e.$2['op']), ['uninstall', 'update']);
    });

    test('a failing event logger does not break the job', () async {
      jobRoutes();
      final c = hub(
        logger: (_, [ignored = const {}]) => throw StateError('down'),
      );
      await c.load();

      c.install(scraper, scanOf(InstallPolicy.allow));
      await until(
        () => !c.busy && server.requestsTo('GET', '/api/skills').length == 2,
      );

      expect(c.job!.state, JobState.succeeded);
    });
  });
}
