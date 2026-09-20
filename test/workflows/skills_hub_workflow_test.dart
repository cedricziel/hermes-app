import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';

import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// The skills hub: the Discover tab, a hub skill's page and its security
/// scan, the install / uninstall / update job sheet, the editor for a new
/// skill, and what the tab says when the hub is not there.
void main() {
  late FakeHermesServer server;

  const installPath = '/api/skills/hub/install';
  const installStatus = '/api/actions/skills-install-web-scraper/status';

  Map<String, Object?> longSkill(String name, {String? identifier}) =>
      hubSkillRow(
        name: name,
        identifier: identifier,
        description:
            'Reads the page, follows the links that matter, strips the '
            'navigation and the ads, and hands the agent clean text it can '
            'quote from without re-fetching anything twice over',
        tags: ['search', 'web', 'scraping', 'research', 'a-fourth-tag'],
      );

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/skills', [
        skillRow(
          name: 'compose',
          description: 'Compose stacks',
          category: 'devops',
          provenance: 'hub',
          usage: 3,
        ),
        skillRow(
          name: 'a-hub-skill-with-a-really-long-name-that-wraps',
          description:
              'Installed from the hub; the description is long enough that '
              'the list has to cut it off at the end of the first line',
          category: 'devops',
          provenance: 'hub',
          enabled: false,
        ),
        skillRow(
          name: 'apple-notes',
          description: 'Read and write Apple Notes',
          category: 'apple',
          usage: 14,
        ),
        skillRow(
          name: 'pr-review',
          description: 'Review a pull request',
          category: 'github',
          provenance: 'agent',
        ),
      ])
      ..on('GET', '/api/skills/content', {
        'name': 'compose',
        'content':
            '---\nname: compose\ndescription: Compose stacks\n---\n\n'
            '# Compose\n\nRun and debug **Docker Compose** stacks.\n\n'
            '- up\n- down\n- logs\n',
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
          hubSkillRow(
            name: 'a-skill-with-a-really-long-name-that-has-to-wrap-somewhere',
            identifier: 'official/long',
            source: 'official',
            trustLevel: 'builtin',
          ),
          hubSkillRow(
            name: 'k8s-debug',
            identifier: 'official/k8s-debug',
            source: 'official',
            trustLevel: 'trusted',
            description: 'Debug a cluster',
          ),
        ],
      })
      ..on('GET', '/api/skills/hub/sources', {
        'sources': [
          {'id': 'official', 'label': 'Official (Nous)'},
          {'id': 'github', 'label': 'GitHub'},
          {'id': 'clawhub', 'label': 'ClawHub'},
          {'id': 'skills-sh', 'label': 'Community registry (skills.sh)'},
        ],
        'featured': [
          longSkill('web-scraper'),
          hubSkillRow(
            name: 'compose',
            identifier: 'github/compose',
            description: 'Compose stacks',
            trustLevel: 'trusted',
          ),
          longSkill('deep-research', identifier: 'github/deep-research'),
          hubSkillRow(name: 'no-description', identifier: 'github/bare'),
        ],
        'installed': {
          'github/compose': {'name': 'compose'},
        },
      })
      ..on('GET', '/api/skills/hub/search', {
        'results': [
          longSkill('web-scraper'),
          hubSkillRow(
            name: 'compose',
            identifier: 'github/compose',
            description: 'Compose stacks',
          ),
          hubSkillRow(
            name: 'page-fetcher',
            identifier: 'clawhub/page-fetcher',
            source: 'clawhub',
            description: 'Fetch pages',
          ),
        ],
        'timed_out': ['skills-sh', 'clawhub'],
        'installed': {
          'github/compose': {'name': 'compose'},
        },
      })
      ..on(
        'GET',
        '/api/skills/hub/search',
        {'results': [], 'timed_out': [], 'installed': {}},
        query: {'q': 'zzzz'},
      )
      ..on('GET', '/api/skills/hub/preview', {
        'name': 'web-scraper',
        'skill_md':
            '---\nname: web-scraper\n---\n\n# Web scraper\n\n'
            'Fetch pages and return clean text.\n\n'
            '## When to use it\n\nWhen the user gives a URL, or asks about a '
            'page that changes often.\n\n'
            '1. Fetch the page\n2. Strip the navigation\n3. Quote the text\n',
        'files': [
          'SKILL.md',
          'scripts/fetch.sh',
          'references/a-very-long-path/that/goes/on/and/on/for/a/while.md',
        ],
      })
      ..on('GET', '/api/skills/hub/scan', hubScanBody())
      ..on('POST', installPath, {
        'ok': true,
        'pid': 4242,
        'name': 'skills-install-web-scraper',
      })
      ..on(
        'GET',
        installStatus,
        jobStatusBody(lines: ['Fetching…', 'Installing…', 'Done']),
      )
      ..on('POST', '/api/skills/hub/update', {
        'pid': 2,
        'name': 'skills-update',
      })
      ..on(
        'GET',
        '/api/actions/skills-update/status',
        jobStatusBody(
          name: 'skills-update',
          pid: 2,
          lines: ['Checking 2 skills…', 'compose: up to date', 'Done'],
        ),
      )
      ..on('POST', '/api/skills/hub/uninstall', {'pid': 3, 'name': 'u'})
      ..on(
        'GET',
        '/api/actions/u/status',
        jobStatusBody(name: 'u', pid: 3, lines: ['Removing compose…', 'Done']),
      )
      ..on('POST', '/api/skills', {'success': true});
  });

  Future<void> pumpSkills(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
    bool hub = true,
  }) => pumpScreen(
    tester,
    shots,
    SkillsScreen(
      repository: HermesSkillsRepository(server.client().raw),
      hubRepository: hub
          ? HermesSkillsHubRepository(server.client().raw)
          : null,
      chatProfile: 'work',
    ),
    size: size,
    brightness: brightness,
  );

  /// Advances time in small steps, for screens that never settle because a
  /// progress indicator is animating.
  Future<void> frames(WidgetTester tester, int milliseconds) async {
    for (var spent = 0; spent < milliseconds; spent += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Pops the top route without waiting for things to settle.
  Future<void> back(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await frames(tester, 600);
  }

  Future<void> openDiscover(WidgetTester tester) async {
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  final variants = [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
    ('phone-dark', phoneSize, Brightness.dark),
  ];

  // ------------------------------------------------------------- discover
  for (final (name, size, brightness) in variants) {
    testWidgets('$name: discover', (tester) async {
      final shots = ScreenshotRecorder('skills-hub-discover-$name');
      await pumpSkills(tester, shots, size: size, brightness: brightness);
      await shots.capture(tester, 'installed');

      await openDiscover(tester);
      await shots.capture(tester, 'discover');

      final list = find.descendant(
        of: find.byType(TabBarView),
        matching: find.byType(ListView),
      );
      await tester.drag(list.last, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'discover-bottom');
      await tester.drag(list.last, const Offset(0, 3000));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Official (Nous)'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'source-official');

      await tester.tap(find.widgetWithText(ChoiceChip, 'ClawHub'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'source-empty');

      final long = find.widgetWithText(
        ChoiceChip,
        'Community registry (skills.sh)',
      );
      await tester.scrollUntilVisible(
        long,
        100,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.horizontal,
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(long);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'source-long-label');
      await tester.drag(
        find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.horizontal,
            )
            .last,
        const Offset(2000, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();

      await search(tester, 'scrape');
      await shots.capture(tester, 'search-results');

      await search(tester, 'zzzz');
      await shots.capture(tester, 'search-empty');

      server.on(
        'GET',
        '/api/skills/hub/search',
        {'detail': 'x'},
        status: 502,
        query: {'q': 'boom'},
      );
      await search(tester, 'boom');
      await shots.capture(tester, 'search-failed');
    });
  }

  // ------------------------------------------------------------ hub skill
  for (final (name, size, brightness) in variants) {
    testWidgets('$name: a hub skill and its scan', (tester) async {
      final shots = ScreenshotRecorder('skills-hub-skill-$name');
      await pumpSkills(tester, shots, size: size, brightness: brightness);
      await openDiscover(tester);
      await search(tester, 'scrape');

      Future<void> openScraper() async {
        await tester.tap(find.byKey(const ValueKey('hub-github/web-scraper')));
        await tester.pumpAndSettle();
      }

      await openScraper();
      await shots.capture(tester, 'scan-passed');
      await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'scan-passed-bottom');
      await back(tester);

      server.on(
        'GET',
        '/api/skills/hub/scan',
        hubScanBody(
          policy: 'ask',
          summary:
              'A script downloads and runs remote code, and another one '
              'reads credentials from the environment',
          reason: 'Needs your confirmation before it can be installed',
          findings: [
            hubFindingRow(),
            hubFindingRow(
              severity: 'critical',
              description:
                  'Reads the SSH private key and posts it to a remote host '
                  'over plain HTTP, which is exactly what an exfiltration '
                  'script does',
              file: 'scripts/a/very/deeply/nested/directory/exfiltrate.sh',
              line: 148,
            ),
            hubFindingRow(
              severity: 'medium',
              description: 'Writes outside the skill directory',
              file: 'scripts/setup.py',
              line: 3,
            ),
          ],
          counts: {'critical': 1, 'high': 1, 'medium': 1, 'low': 0},
        ),
      );
      await openScraper();
      await shots.capture(tester, 'scan-ask');
      await tester.tap(find.text('Install anyway…'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'scan-ask-confirm');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await back(tester);

      server.on(
        'GET',
        '/api/skills/hub/scan',
        hubScanBody(
          policy: 'block',
          summary: 'Malware signatures found',
          reason: 'Credential stealer',
          findings: [hubFindingRow(severity: 'critical')],
          counts: {'critical': 1, 'high': 0, 'medium': 0, 'low': 0},
        ),
      );
      await openScraper();
      await shots.capture(tester, 'scan-blocked');
      await back(tester);

      server.on('GET', '/api/skills/hub/scan', {'detail': 'x'}, status: 502);
      await openScraper();
      await shots.capture(tester, 'scan-failed');
      await back(tester);

      server
        ..on('GET', '/api/skills/hub/scan', hubScanBody())
        ..on('GET', '/api/skills/hub/preview', {'detail': 'x'}, status: 502);
      await openScraper();
      await shots.capture(tester, 'preview-failed');
      await back(tester);

      final gate = Completer<void>();
      server
        ..on('GET', '/api/skills/hub/preview', {
          'name': 'web-scraper',
          'skill_md': '# Web scraper',
          'files': ['SKILL.md'],
        })
        ..onRequest('GET', '/api/skills/hub/scan', (_) async {
          await gate.future;
          return (status: 200, body: hubScanBody());
        });
      await tester.tap(find.byKey(const ValueKey('hub-github/web-scraper')));
      await frames(tester, 800);
      await shots.capture(tester, 'scan-running');
      gate.complete();
      await tester.pumpAndSettle();
      await back(tester);

      // Already installed: the result opens the installed skill instead.
      await tester.tap(find.byKey(const ValueKey('hub-github/compose')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'installed-skill');
    });
  }

  // ----------------------------------------------------------------- jobs
  for (final (name, size, brightness) in variants) {
    testWidgets('$name: install and uninstall jobs', (tester) async {
      final shots = ScreenshotRecorder('skills-hub-jobs-$name');
      await pumpSkills(tester, shots, size: size, brightness: brightness);
      await openDiscover(tester);
      await search(tester, 'scrape');
      await tester.tap(find.byKey(const ValueKey('hub-github/web-scraper')));
      await tester.pumpAndSettle();

      server.on(
        'GET',
        installStatus,
        jobStatusBody(
          running: true,
          exitCode: null,
          lines: [
            for (var i = 1; i <= 9; i++)
              'Step $i of 9: copying files into the skill directory',
          ],
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await tester.pump();
      await shots.capture(tester, 'starting');
      await frames(tester, 800);
      await shots.capture(tester, 'running');

      server.on(
        'GET',
        installStatus,
        jobStatusBody(lines: ['Fetching…', 'Installing…', 'Done']),
      );
      await frames(tester, 2500);
      await shots.capture(tester, 'done');
      await tester.tap(find.text('Close'));
      await frames(tester, 800);

      server.on(
        'GET',
        installStatus,
        jobStatusBody(
          exitCode: 1,
          lines: [
            'Fetching…',
            'error: could not resolve host raw.githubusercontent.com while '
                'fetching scripts/fetch.sh from the repository',
          ],
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await frames(tester, 2500);
      await shots.capture(tester, 'failed');
      await tester.tap(find.text('Close'));
      await frames(tester, 800);

      server.on('POST', installPath, {
        'detail': 'Another install is already running for this profile',
      }, status: 409);
      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await frames(tester, 1000);
      await shots.capture(tester, 'start-refused');
      await tester.tap(find.text('Close'));
      await frames(tester, 800);

      server
        ..on('POST', installPath, {
          'ok': true,
          'pid': 4242,
          'name': 'skills-install-web-scraper',
        })
        ..on('GET', installStatus, {'detail': 'Unknown action'}, status: 404);
      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await frames(tester, 1500);
      await shots.capture(tester, 'unconfirmed');
      await tester.tap(find.text('Close'));
      await frames(tester, 800);

      server.on(
        'GET',
        installStatus,
        jobStatusBody(running: true, exitCode: null, lines: ['Fetching…']),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await frames(tester, 800);
      await tester.tap(find.text('Run in background'));
      await frames(tester, 800);
      await back(tester);
      await shots.capture(tester, 'in-background');

      server.on('GET', installStatus, jobStatusBody(lines: ['Done']));
      await frames(tester, 3000);
      await shots.capture(tester, 'background-done');
      await frames(tester, 5000);

      // Uninstall a hub skill, from its page on the Installed tab.
      await tester.tap(find.text('Installed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('compose'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'installed-skill');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Uninstall'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'uninstall-confirm');
      await tester.tap(find.widgetWithText(FilledButton, 'Uninstall'));
      await frames(tester, 3000);
      await shots.capture(tester, 'uninstalled');
      await tester.tap(find.text('Close'));
      await frames(tester, 800);
    });
  }

  for (final (name, size, brightness) in [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
  ]) {
    testWidgets('$name: check for updates', (tester) async {
      final shots = ScreenshotRecorder('skills-hub-updates-$name');
      await pumpSkills(tester, shots, size: size, brightness: brightness);

      final tile = find.text('Check for updates');
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'row');

      server.on(
        'GET',
        '/api/actions/skills-update/status',
        jobStatusBody(
          name: 'skills-update',
          pid: 2,
          running: true,
          exitCode: null,
          lines: ['Checking 2 skills…', 'compose: up to date'],
        ),
      );
      await tester.tap(tile);
      await frames(tester, 1000);
      await shots.capture(tester, 'running');

      server.on(
        'GET',
        '/api/actions/skills-update/status',
        jobStatusBody(
          name: 'skills-update',
          pid: 2,
          lines: ['Checking 2 skills…', 'compose: updated 1.2 -> 1.3', 'Done'],
        ),
      );
      await frames(tester, 2500);
      await shots.capture(tester, 'done');
      await tester.tap(find.text('Close'));
      await frames(tester, 800);

      server.on('POST', '/api/skills/hub/update', {
        'detail': 'The hub is unreachable',
      }, status: 502);
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await frames(tester, 1000);
      await shots.capture(tester, 'failed');
      await tester.tap(find.text('Close'));
      await frames(tester, 800);
    });
  }

  // ---------------------------------------------------------- new skill
  for (final (name, size, brightness) in variants) {
    testWidgets('$name: writing a new skill', (tester) async {
      final shots = ScreenshotRecorder('skills-hub-editor-$name');
      await pumpSkills(tester, shots, size: size, brightness: brightness);
      await tester.tap(find.text('New skill'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'template');

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'a-skill-name-that-is-far-too-long-for-the-half-width-field',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Category (optional)'),
        'devops',
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'name-only');

      await tester.tap(find.text('#'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'after-heading-button');

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'ship-a-release',
      );
      await tester.enterText(
        find.byType(TextField).last,
        '---\nname: ship-a-release\ndescription: Cut and publish a release\n'
        '---\n\n# Ship a release\n\nWhen the user asks to cut a release.\n\n'
        '- Bump the version\n- Tag it\n- Publish the notes\n',
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'filled');

      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'preview');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      server.on('POST', '/api/skills', {
        'detail': 'A skill named "ship-a-release" already exists',
      }, status: 409);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'save-refused');

      server.on('POST', '/api/skills', {'detail': 'x'}, status: 500);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'save-unreachable');

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'discard-confirm');
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      server.on('POST', '/api/skills', {'success': true});
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'created');
    });
  }

  // -------------------------------------------------------- unavailable
  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: when the hub is not there', (tester) async {
      final shots = ScreenshotRecorder('skills-hub-states-$name');
      server.on('GET', '/api/skills/hub/official', {
        'detail': 'Not Found',
      }, status: 404);
      await pumpSkills(tester, shots, size: size);
      await openDiscover(tester);
      await shots.capture(tester, 'unsupported');

      server.on('GET', '/api/skills/hub/official', {
        'detail': 'x',
      }, status: 502);
      await tester.tap(find.text('Installed'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await pumpSkills(tester, shots, size: size);
      await openDiscover(tester);
      await shots.capture(tester, 'failed');

      server
        ..on('GET', '/api/skills/hub/official', {'skills': []})
        ..on('GET', '/api/skills/hub/sources', {
          'sources': [],
          'featured': [],
          'installed': {},
        });
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'empty');
    });

    testWidgets('$name: skills without a hub, or without skills', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('skills-hub-noskills-$name');
      await pumpSkills(tester, shots, size: size, hub: false);
      await shots.capture(tester, 'no-hub');

      server.on('GET', '/api/skills', <Object?>[]);
      await tester.pumpWidget(const SizedBox());
      await pumpSkills(tester, shots, size: size);
      await shots.capture(tester, 'no-skills');

      server.on('GET', '/api/skills', {'detail': 'x'}, status: 500);
      await tester.pumpWidget(const SizedBox());
      await pumpSkills(tester, shots, size: size);
      await shots.capture(tester, 'load-failed');

      server.on('GET', '/api/skills', {'detail': 'Not Found'}, status: 404);
      await tester.pumpWidget(const SizedBox());
      await pumpSkills(tester, shots, size: size);
      await shots.capture(tester, 'unsupported');
    });
  }
}
