import 'package:flutter/material.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/skills/discover_tab.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_controller.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';
import 'package:hermes_app/src/skills/widgets/installed_skills_list.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/fake_hermes_server.dart';
import 'skills_messaging_use_cases.dart';

const _platforms = {
  'iPhone': TargetPlatform.iOS,
  'Mac': TargetPlatform.macOS,
  'Material': TargetPlatform.android,
};

/// One use case per platform, named after the state and the platform.
List<WidgetbookUseCase> _onEach(
  String state,
  Widget Function(BuildContext context) builder,
) => [
  for (final MapEntry(key: name, value: platform) in _platforms.entries)
    WidgetbookUseCase(
      name: '$state ($name)',
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(platform: platform),
        child: Builder(builder: builder),
      ),
    ),
];

/// [screen] over a chat page, so it has a back button.
Widget _pushed(Widget screen) => Navigator(
  onGenerateInitialRoutes: (_, _) => [
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('Chat'))),
    ),
    MaterialPageRoute<void>(builder: (_) => screen),
  ],
);

Widget _screen({
  bool hub = true,
  FakeHermesServer Function() serve = skillsServer,
}) {
  final server = serve();
  return _pushed(
    SkillsScreen(
      repository: HermesSkillsRepository(server.client().raw),
      hubRepository: hub
          ? HermesSkillsHubRepository(server.client().raw)
          : null,
      profiles: HermesProfilesRepository(server.client().raw),
      chatProfile: 'default',
    ),
  );
}

FakeHermesServer _failing() =>
    skillsServer()..on('GET', '/api/skills', {'detail': 'x'}, status: 500);

FakeHermesServer _empty() =>
    skillsServer()..on('GET', '/api/skills', <Object?>[]);

const _groups = [
  SkillGroup('apple', [
    HermesSkill(
      name: 'apple-notes',
      description: 'Read and write Apple Notes',
      category: 'apple',
      usage: 14,
    ),
    HermesSkill(
      name: 'apple-reminders',
      description: 'Add reminders and read the lists',
      category: 'apple',
      enabled: false,
    ),
  ]),
  SkillGroup('devops', [
    HermesSkill(
      name: 'compose',
      description: 'Manage Compose stacks',
      category: 'devops',
      source: SkillSource.hub,
      usage: 3,
    ),
  ]),
  SkillGroup('github', [
    HermesSkill(
      name: 'pr-review',
      description: 'Review a pull request',
      category: 'github',
      source: SkillSource.agent,
    ),
  ]),
];

Widget _list({List<SkillGroup> groups = _groups, bool updating = false}) =>
    Scaffold(
      body: InstalledSkillsList(
        groups: groups,
        onOpen: (_) {},
        onToggle: (_, _) {},
        onClearFilters: () {},
        onCheckForUpdates: () {},
        updating: updating,
      ),
    );

WidgetbookNode skillsNode() => WidgetbookFolder(
  name: 'Skills',
  children: [
    WidgetbookComponent(
      name: 'SkillsScreen',
      useCases: [
        ..._onEach('Installed and discover', (_) => _screen()),
        ..._onEach('Without the hub', (_) => _screen(hub: false)),
        ..._onEach('No skills', (_) => _screen(serve: _empty)),
        ..._onEach('Failed', (_) => _screen(serve: _failing)),
      ],
    ),
    WidgetbookComponent(
      name: 'InstalledSkillsList',
      useCases: [
        ..._onEach('Categories', (_) => _list()),
        ..._onEach('Updating', (_) => _list(updating: true)),
        ..._onEach('Nothing matches', (_) => _list(groups: const [])),
      ],
    ),
    WidgetbookComponent(
      name: 'DiscoverTab',
      useCases: [
        for (final MapEntry(key: name, value: platform) in _platforms.entries)
          skillsUseCase(
            'Featured ($name)',
            (skills, hub) => Builder(
              builder: (context) => Theme(
                data: Theme.of(context).copyWith(platform: platform),
                child: Scaffold(
                  body: DiscoverTab(hub: hub, onOpen: (_) {}),
                ),
              ),
            ),
            loadHub: true,
          ),
      ],
    ),
  ],
);
