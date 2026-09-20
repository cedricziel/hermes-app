import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/hub_skill_screen.dart';
import 'package:hermes_app/src/skills/skill_detail_screen.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';

import 'support/fake_hermes_server.dart';

/// The Discover tab, the hub skill page and the job sheet against a fake
/// dashboard, through the real generated client.
/// Advances time in small steps, for screens that never settle because a
/// progress indicator is animating.
Future<void> pumpFor(WidgetTester tester, int milliseconds) async {
  for (var spent = 0; spent < milliseconds; spent += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/skills', [
        skillRow(name: 'compose', category: 'devops', provenance: 'hub'),
        skillRow(name: 'apple-notes', category: 'apple'),
      ])
      ..on('GET', '/api/skills/content', {
        'name': 'compose',
        'content': '# Compose',
        'path': '/x',
      })
      ..on('GET', '/api/skills/hub/official', {
        'skills': [
          hubSkillRow(
            name: 'web-research',
            identifier: 'official/web/web-research',
            source: 'official',
            trustLevel: 'builtin',
            description: 'Search the web',
            tags: ['search'],
          ),
        ],
      })
      ..on('GET', '/api/skills/hub/sources', {
        'sources': [
          {'id': 'official', 'label': 'Official (Nous)'},
          {'id': 'github', 'label': 'GitHub'},
        ],
        'featured': [
          hubSkillRow(
            name: 'compose',
            identifier: 'github/compose',
            description: 'Compose stacks',
          ),
        ],
        'installed': {
          'github/compose': {'name': 'compose'},
        },
      })
      ..on('GET', '/api/skills/hub/search', {
        'results': [
          hubSkillRow(name: 'web-scraper', description: 'Scrape pages'),
        ],
        'timed_out': ['clawhub'],
        'installed': {},
      })
      ..on('GET', '/api/skills/hub/preview', {
        'name': 'web-scraper',
        'skill_md': '# Web scraper\n\nFetch pages.',
        'files': ['SKILL.md', 'scripts/fetch.sh'],
      })
      ..on('GET', '/api/skills/hub/scan', hubScanBody())
      ..on('POST', '/api/skills/hub/install', {
        'ok': true,
        'pid': 4242,
        'name': 'skills-install-web-scraper',
      })
      ..on(
        'GET',
        '/api/actions/skills-install-web-scraper/status',
        jobStatusBody(lines: ['Installing…', 'Done']),
      );
  });

  Future<void> pumpSkills(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SkillsScreen(
          repository: HermesSkillsRepository(server.client().raw),
          hubRepository: HermesSkillsHubRepository(server.client().raw),
          chatProfile: 'work',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDiscover(WidgetTester tester) async {
    await pumpSkills(tester);
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
  }

  Future<void> openWebScraper(WidgetTester tester) async {
    await openDiscover(tester);
    await tester.enterText(find.byType(TextField), 'scrape');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('web-scraper'));
    await tester.pumpAndSettle();
  }

  group('Discover tab', () {
    testWidgets('has the two tabs, and the hub is not asked until opened', (
      tester,
    ) async {
      await pumpSkills(tester);

      expect(find.text('Installed'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(server.requestsTo('GET', '/api/skills/hub/official'), isEmpty);

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      expect(
        server.requestsTo('GET', '/api/skills/hub/official'),
        hasLength(1),
      );
    });

    testWidgets('lists featured and official skills with trust badges', (
      tester,
    ) async {
      await openDiscover(tester);

      expect(find.text('FEATURED'), findsOneWidget);
      expect(find.text('OFFICIAL'), findsOneWidget);
      expect(find.text('web-research'), findsOneWidget);
      expect(find.text('Official'), findsWidgets);
      expect(find.text('Community'), findsWidgets);
      expect(find.text('#search'), findsOneWidget);
    });

    testWidgets('an installed skill is marked', (tester) async {
      await openDiscover(tester);

      final card = find.byKey(const ValueKey('hub-github/compose'));
      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.check_circle_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('searching shows results and a timed-out note', (tester) async {
      await openDiscover(tester);

      await tester.enterText(find.byType(TextField), 'scrape');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('web-scraper'), findsOneWidget);
      expect(find.text('FEATURED'), findsNothing);
      expect(find.text('1 source timed out'), findsOneWidget);
      expect(
        server
            .requestsTo('GET', '/api/skills/hub/search')
            .single
            .queryParameters['profile'],
        'work',
      );
    });

    testWidgets('a source chip narrows the featured list', (tester) async {
      await openDiscover(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Official (Nous)'));
      await tester.pumpAndSettle();

      expect(find.text('web-research'), findsOneWidget);
      expect(find.text('compose'), findsNothing);
    });

    testWidgets('a failing hub offers Retry', (tester) async {
      server.on('GET', '/api/skills/hub/official', {
        'detail': 'x',
      }, status: 502);
      await openDiscover(tester);
      expect(find.text('Could not load the hub'), findsOneWidget);

      server.on('GET', '/api/skills/hub/official', {'skills': []});
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load the hub'), findsNothing);
    });

    testWidgets('an older server is told so', (tester) async {
      server.on('GET', '/api/skills/hub/official', {
        'detail': 'Not Found',
      }, status: 404);
      await openDiscover(tester);

      expect(
        find.text('The connected Hermes does not support the skills hub.'),
        findsOneWidget,
      );
    });

    testWidgets('an installed result opens the installed skill', (
      tester,
    ) async {
      await openDiscover(tester);

      await tester.tap(find.text('compose').first);
      await tester.pumpAndSettle();

      expect(find.byType(SkillDetailScreen), findsOneWidget);
    });
  });

  group('hub skill page', () {
    testWidgets('shows the scan, the files and the SKILL.md', (tester) async {
      server.on(
        'GET',
        '/api/skills/hub/scan',
        hubScanBody(
          policy: 'ask',
          summary: 'A script runs remote code',
          reason: 'Needs confirmation',
          findings: [hubFindingRow()],
          counts: {'critical': 0, 'high': 1, 'medium': 0, 'low': 0},
        ),
      );
      await openWebScraper(tester);

      expect(find.text('Caution: confirmation required'), findsOneWidget);
      expect(find.text('A script runs remote code'), findsOneWidget);
      expect(find.text('1 high'), findsOneWidget);
      expect(
        find.textContaining('Downloads and runs a remote script'),
        findsOneWidget,
      );
      expect(find.text('scripts/fetch.sh:12'), findsOneWidget);
      expect(find.text('scripts/fetch.sh'), findsOneWidget);
      expect(find.textContaining('Fetch pages.'), findsOneWidget);
      expect(
        server.requestsTo('GET', '/api/skills/hub/scan').single.queryParameters,
        {'identifier': 'github/web-scraper', 'profile': 'work'},
      );
    });

    testWidgets('allow: Install starts a job that ends in Done', (
      tester,
    ) async {
      await openWebScraper(tester);
      expect(find.text('Passed'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await tester.pumpAndSettle();

      expect(find.text('Installing web-scraper'), findsOneWidget);
      expect(find.text('Done.'), findsOneWidget);
      expect(find.byKey(const ValueKey('job-log')), findsOneWidget);
      expect(
        jsonBody(server.requestsTo('POST', '/api/skills/hub/install').single),
        {'identifier': 'github/web-scraper', 'profile': 'work'},
      );
    });

    testWidgets('ask: nothing is installed until the user confirms', (
      tester,
    ) async {
      server.on(
        'GET',
        '/api/skills/hub/scan',
        hubScanBody(policy: 'ask', findings: [hubFindingRow()]),
      );
      await openWebScraper(tester);

      await tester.tap(find.text('Install anyway…'));
      await tester.pumpAndSettle();
      expect(find.text('Install web-scraper?'), findsOneWidget);
      expect(
        find.textContaining('Downloads and runs a remote script'),
        findsWidgets,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.requestsTo('POST', '/api/skills/hub/install'), isEmpty);

      await tester.tap(find.text('Install anyway…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install anyway'));
      await tester.pumpAndSettle();

      expect(
        server.requestsTo('POST', '/api/skills/hub/install'),
        hasLength(1),
      );
    });

    testWidgets('block: Install is off and the reason is shown', (
      tester,
    ) async {
      server.on(
        'GET',
        '/api/skills/hub/scan',
        hubScanBody(policy: 'block', reason: 'Credential stealer'),
      );
      await openWebScraper(tester);

      expect(find.text('Credential stealer'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Install'))
            .onPressed,
        isNull,
      );
      expect(server.requestsTo('POST', '/api/skills/hub/install'), isEmpty);
    });

    testWidgets('an unknown policy is treated as block', (tester) async {
      server.on('GET', '/api/skills/hub/scan', {
        ...hubScanBody(),
        'policy': 'maybe',
      });
      await openWebScraper(tester);

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Install'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a failing scan hides Install and offers Retry', (
      tester,
    ) async {
      server.on('GET', '/api/skills/hub/scan', {'detail': 'x'}, status: 502);
      await openWebScraper(tester);

      expect(find.text('Could not run the security scan.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Install'))
            .onPressed,
        isNull,
      );

      server.on('GET', '/api/skills/hub/scan', hubScanBody());
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Passed'), findsOneWidget);
    });

    testWidgets('a skill that is already installed says so', (tester) async {
      server.on('GET', '/api/skills/hub/search', {
        'results': [hubSkillRow(name: 'compose', identifier: 'github/compose')],
        'installed': {'github/compose': {}},
      });
      server.on('GET', '/api/skills', [
        skillRow(name: 'other', provenance: 'hub'),
      ]);
      await openDiscover(tester);
      await tester.enterText(find.byType(TextField), 'compose');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hub-github/compose')));
      await tester.pumpAndSettle();

      expect(find.byType(HubSkillScreen), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Installed'), findsOneWidget);
    });
  });

  group('jobs', () {
    testWidgets('closing the sheet keeps the job going and reports the end', (
      tester,
    ) async {
      server.on(
        'GET',
        '/api/actions/skills-install-web-scraper/status',
        jobStatusBody(running: true, exitCode: null, lines: ['Fetching…']),
      );
      await openWebScraper(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await pumpFor(tester, 800);

      expect(find.text('Run in background'), findsOneWidget);
      await tester.tap(find.text('Run in background'));
      await pumpFor(tester, 800);
      await tester.pageBack();
      await pumpFor(tester, 800);
      expect(find.byKey(const ValueKey('job-bar')), findsOneWidget);

      server.on(
        'GET',
        '/api/actions/skills-install-web-scraper/status',
        jobStatusBody(lines: ['Done']),
      );
      await pumpFor(tester, 2500);
      await pumpFor(tester, 800);

      expect(find.byKey(const ValueKey('job-bar')), findsNothing);
      expect(find.text('Done: Installing web-scraper'), findsOneWidget);
    });

    testWidgets('a failed job says so', (tester) async {
      server.on(
        'GET',
        '/api/actions/skills-install-web-scraper/status',
        jobStatusBody(exitCode: 1, lines: ['boom']),
      );
      await openWebScraper(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await tester.pumpAndSettle();

      expect(find.text('It failed.'), findsOneWidget);
      expect(find.text('boom'), findsOneWidget);
    });

    testWidgets('an unknown job never claims success', (tester) async {
      server.on('GET', '/api/actions/skills-install-web-scraper/status', {
        'detail': 'Unknown action',
      }, status: 404);
      await openWebScraper(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await tester.pumpAndSettle();

      expect(find.text('Done.'), findsNothing);
      expect(find.textContaining('could not be confirmed'), findsOneWidget);
    });
  });

  group('uninstall and update', () {
    testWidgets('a hub skill can be uninstalled after a confirmation', (
      tester,
    ) async {
      server
        ..on('POST', '/api/skills/hub/uninstall', {'pid': 1, 'name': 'u'})
        ..on('GET', '/api/actions/u/status', jobStatusBody(name: 'u', pid: 1));
      await pumpSkills(tester);
      await tester.tap(find.text('compose'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Uninstall'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Uninstall'));
      await tester.pumpAndSettle();

      expect(
        jsonBody(server.requestsTo('POST', '/api/skills/hub/uninstall').single),
        {'name': 'compose', 'profile': 'work'},
      );
    });

    testWidgets('a bundled skill has no Uninstall', (tester) async {
      await pumpSkills(tester);
      await tester.tap(find.text('apple-notes'));
      await tester.pumpAndSettle();

      expect(find.text('Uninstall'), findsNothing);
    });

    testWidgets('Check for updates starts an update job', (tester) async {
      server
        ..on('POST', '/api/skills/hub/update', {
          'pid': 2,
          'name': 'skills-update',
        })
        ..on(
          'GET',
          '/api/actions/skills-update/status',
          jobStatusBody(name: 'skills-update', pid: 2),
        );
      await pumpSkills(tester);

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('POST', '/api/skills/hub/update'), hasLength(1));
      expect(find.text('Updating hub skills'), findsOneWidget);
    });

    testWidgets('the update action is not shown without hub skills', (
      tester,
    ) async {
      server.on('GET', '/api/skills', [skillRow(name: 'apple-notes')]);
      await pumpSkills(tester);

      expect(find.text('Check for updates'), findsNothing);
    });
  });
}
