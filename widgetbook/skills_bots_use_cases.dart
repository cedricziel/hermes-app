import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/bots/bot_setup_screen.dart';
import 'package:hermes_app/src/bots/bots_screen.dart';
import 'package:hermes_app/src/bots/hermes_bots_repository.dart';
import 'package:hermes_app/src/bots/telegram_pairing_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/profiles_screen.dart';
import 'package:hermes_app/src/skills/discover_tab.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/hub_skill_screen.dart';
import 'package:hermes_app/src/skills/skill_detail_screen.dart';
import 'package:hermes_app/src/skills/skill_editor_screen.dart';
import 'package:hermes_app/src/skills/skill_job.dart';
import 'package:hermes_app/src/skills/skill_job_sheet.dart';
import 'package:hermes_app/src/skills/skills_controller.dart';
import 'package:hermes_app/src/skills/skills_hub_controller.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/fake_hermes_server.dart';
import 'frame.dart';
import 'host.dart';

/// Skills, the hub, bots and profiles of one invented dashboard.
FakeHermesServer skillsServer() => FakeHermesServer()
  ..on('GET', '/api/skills', [
    skillRow(
      name: 'apple-notes',
      description: 'Read Apple Notes',
      category: 'apple',
      usage: 14,
    ),
    skillRow(
      name: 'pr-review',
      description: 'Review a pull request',
      category: 'github',
      provenance: 'agent',
    ),
    skillRow(
      name: 'compose',
      description: 'Manage Compose stacks',
      category: 'devops',
      provenance: 'hub',
      enabled: false,
    ),
  ])
  ..on('GET', '/api/skills/content', {
    'name': 'pr-review',
    'content': '---\nname: pr-review\n---\n\n# Review PRs\n\nBe kind.',
    'path': '/skills/pr-review',
  })
  ..on(
    'GET',
    '/api/profiles',
    profileListBody([
      profileRow(name: 'default', isDefault: true, model: 'hermes-4'),
      profileRow(
        name: 'work',
        displayName: 'Work assistant',
        description: 'Day job',
        skillCount: 12,
        gatewayRunning: true,
      ),
    ]),
  )
  ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
  ..on('GET', '/api/skills/hub/official', {
    'skills': [
      hubSkillRow(
        name: 'web-research',
        identifier: 'official/web/web-research',
        source: 'official',
        trustLevel: 'builtin',
        description: 'Search the web and cite sources.',
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
        name: 'web-scraper',
        identifier: 'github/web-scraper',
        description: 'Scrape pages into markdown.',
        tags: ['web'],
      ),
      hubSkillRow(
        name: 'compose',
        identifier: 'github/compose',
        description: 'Manage Compose stacks.',
      ),
    ],
    'installed': {
      'github/compose': {'name': 'compose'},
    },
  })
  ..on('GET', '/api/skills/hub/search', {
    'results': [hubSkillRow(name: 'web-scraper', description: 'Scrape pages')],
    'timed_out': ['clawhub'],
    'installed': {},
  })
  ..on('GET', '/api/skills/hub/preview', {
    'name': 'web-scraper',
    'skill_md': '# Web scraper\n\nFetch pages and turn them into markdown.',
    'files': ['SKILL.md', 'scripts/fetch.sh'],
  })
  ..on(
    'GET',
    '/api/skills/hub/scan',
    hubScanBody(
      verdict: 'caution',
      summary: '1 finding',
      findings: [
        {
          'severity': 'medium',
          'category': 'network',
          'file': 'scripts/fetch.sh',
          'line': 4,
          'description': 'Downloads and runs a remote script',
        },
      ],
      counts: {'critical': 0, 'high': 0, 'medium': 1, 'low': 0},
    ),
  )
  ..on(
    'GET',
    '/api/messaging/platforms',
    platformListBody([
      platformRow(
        id: 'telegram',
        name: 'Telegram',
        description: 'Run Hermes from Telegram.',
        enabled: true,
        configured: true,
        state: 'connected',
      ),
      platformRow(
        id: 'discord',
        name: 'Discord',
        description: 'Chat with Hermes on a Discord server.',
        configured: true,
        state: 'disabled',
        envVars: [
          envVarRow(
            key: 'DISCORD_BOT_TOKEN',
            prompt: 'Discord bot token',
            required: true,
            isPassword: true,
            help: 'Create it in the developer portal',
          ),
          envVarRow(
            key: 'DISCORD_ALLOWED_USERS',
            prompt: 'Allowed Discord users',
            isSet: true,
            redactedValue: '1234...9999',
          ),
        ],
      ),
      platformRow(id: 'whatsapp', name: 'WhatsApp'),
      platformRow(
        id: 'slack',
        name: 'Slack',
        enabled: true,
        configured: true,
        state: 'error',
        errorMessage: 'Invalid bot token',
      ),
    ]),
  )
  ..on(
    'POST',
    '/api/messaging/telegram/onboarding/start',
    telegramPairingStartBody(),
  )
  ..on('GET', '/api/messaging/telegram/onboarding/p1', {'status': 'waiting'})
  ..on('DELETE', '/api/messaging/telegram/onboarding/p1', {'ok': true});

typedef _Skills = (SkillsController, SkillsHubController);

WidgetbookUseCase _skills(
  String name,
  Widget Function(SkillsController skills, SkillsHubController hub) build, {
  bool loadHub = false,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) => Hosted<_Skills>(
    create: () async {
      final server = skillsServer();
      final skills = SkillsController(
        repository: HermesSkillsRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
        chatProfile: 'default',
      );
      final hub = SkillsHubController(
        repository: HermesSkillsHubRepository(server.client().raw),
        skills: skills,
      );
      await skills.load();
      if (loadHub) await hub.load();
      return (skills, hub);
    },
    dispose: (pair) {
      pair.$2.dispose();
      pair.$1.dispose();
    },
    builder: (_, pair) => build(pair.$1, pair.$2),
  ),
);

SkillJob _job(String title, {bool? succeeds}) {
  final job = SkillJob(
    title: title,
    start: () async => const StartedJob(name: 'skills-install-web-scraper'),
    status: (_) async => JobStatus(
      running: succeeds == null,
      exitCode: succeeds == null ? null : (succeeds ? 0 : 1),
      lines: const ['Fetching web-scraper', 'Checking the files', 'Installing'],
    ),
    wait: (_) => Completer<void>().future,
  );
  unawaited(job.run());
  return job;
}

WidgetbookUseCase _sheet(String name, SkillJob Function() job) =>
    WidgetbookUseCase(
      name: name,
      builder: (_) => Hosted<SkillJob>(
        create: job,
        dispose: (job) => job.dispose(),
        builder: (_, job) => Scaffold(body: SkillJobSheet(job: job)),
      ),
    );

WidgetbookUseCase _bots(
  String name,
  Widget Function(HermesBotsRepository r) b,
) => WidgetbookUseCase(
  name: name,
  builder: (_) => Hosted<HermesBotsRepository>(
    create: () => HermesBotsRepository(skillsServer().client().raw),
    builder: (_, repository) => b(repository),
  ),
);

WidgetbookNode skillsBotsNode() => WidgetbookFolder(
  name: 'Skills, bots and profiles',
  children: [
    WidgetbookComponent(
      name: 'SkillsScreen',
      useCases: [
        WidgetbookUseCase(
          name: 'Installed and discover',
          builder: (_) {
            final server = skillsServer();
            return SkillsScreen(
              repository: HermesSkillsRepository(server.client().raw),
              hubRepository: HermesSkillsHubRepository(server.client().raw),
              profiles: HermesProfilesRepository(server.client().raw),
              chatProfile: 'default',
            );
          },
        ),
        WidgetbookUseCase(
          name: 'Without the hub',
          builder: (_) {
            final server = skillsServer();
            return SkillsScreen(
              repository: HermesSkillsRepository(server.client().raw),
              profiles: HermesProfilesRepository(server.client().raw),
              chatProfile: 'default',
            );
          },
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SkillDetailScreen',
      useCases: [
        _skills(
          'Agent skill',
          (skills, hub) => SkillDetailScreen(
            controller: skills,
            hub: hub,
            name: 'pr-review',
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SkillEditorScreen',
      useCases: [
        WidgetbookUseCase(
          name: 'Create',
          builder: (_) =>
              SkillEditorScreen.create(onSave: (_, _, _) async => null),
        ),
        WidgetbookUseCase(
          name: 'Edit',
          builder: (_) => SkillEditorScreen.edit(
            name: 'pr-review',
            initialText:
                '---\nname: pr-review\n---\n\n# Review PRs\n\nBe kind.',
            onSave: (_, _, _) async => null,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'DiscoverTab',
      useCases: [
        _skills(
          'Featured',
          (skills, hub) => Scaffold(
            body: DiscoverTab(hub: hub, onOpen: (_) {}),
          ),
          loadHub: true,
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'HubSkillScreen',
      useCases: [
        _skills(
          'Preview and scan',
          (skills, hub) => HubSkillScreen(
            hub: hub,
            skill: const HubSkill(
              name: 'web-scraper',
              identifier: 'github/web-scraper',
              description: 'Scrape pages into markdown.',
              source: 'github',
              tags: ['web'],
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SkillJobSheet',
      useCases: [
        _sheet('Running', () => _job('Installing web-scraper')),
        _sheet(
          'Succeeded',
          () => _job('Installing web-scraper', succeeds: true),
        ),
        _sheet('Failed', () => _job('Installing web-scraper', succeeds: false)),
      ],
    ),
    WidgetbookComponent(
      name: 'TrustBadge and SourceBadge',
      useCases: [
        WidgetbookUseCase(
          name: 'Trust levels',
          builder: (_) => frame(
            const Wrap(
              spacing: 8,
              children: [
                TrustBadge('builtin'),
                TrustBadge('trusted'),
                TrustBadge('community'),
              ],
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Sources',
          builder: (_) => frame(
            Wrap(
              spacing: 8,
              children: [for (final s in SkillSource.values) SourceBadge(s)],
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'BotsScreen',
      useCases: [
        _bots('Platforms', (repository) => BotsScreen(repository: repository)),
      ],
    ),
    WidgetbookComponent(
      name: 'BotSetupScreen',
      useCases: [
        _bots(
          'Discord',
          (repository) => FutureBuilder<List<HermesBot>>(
            future: repository.load(),
            builder: (_, snapshot) {
              final bots = snapshot.data;
              if (bots == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return BotSetupScreen(
                bot: bots.firstWhere((b) => b.id == 'discord'),
                repository: repository,
              );
            },
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'TelegramPairingScreen',
      useCases: [
        _bots(
          'Waiting for Telegram',
          (repository) => TelegramPairingScreen(
            repository: repository,
            pollInterval: const Duration(days: 1),
            launchLink: (_) async => true,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ProfilesScreen',
      useCases: [
        WidgetbookUseCase(
          name: 'Profiles',
          builder: (_) => ProfilesScreen(
            repository: HermesProfilesRepository(skillsServer().client().raw),
            chatProfile: 'default',
            onSwitched: (_) {},
          ),
        ),
      ],
    ),
  ],
);
