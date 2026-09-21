import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/bots/bots_screen.dart';
import 'package:hermes_app/src/bots/hermes_bots_repository.dart';
import 'package:hermes_app/src/bots/telegram_pairing_screen.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/kanban/kanban_workers_screen.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_catalog_screen.dart';
import 'package:hermes_app/src/mcp/mcp_servers_controller.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/profiles_screen.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_screen.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/fake_hermes_server.dart';
import 'catalog_auth.dart';
import 'host.dart';
import 'kanban_screen_use_cases.dart';
import 'mcp_screen_use_cases.dart';
import 'plugins_screen_use_cases.dart';
import 'schedules_screen_use_cases.dart';
import 'skills_bots_use_cases.dart';

/// Answers [method] [path] with a server error.
FakeHermesServer _failing(
  FakeHermesServer server,
  String method,
  String path, {
  int status = 500,
}) => server..on(method, path, {'detail': 'boom'}, status: status);

/// Never answers [method] [path], so the screen stays on its spinner.
FakeHermesServer _hanging(
  FakeHermesServer server,
  String method,
  String path,
) => server..onRequest(method, path, (_) => Completer<FakeResponse>().future);

WidgetbookUseCase _state(String name, Widget Function() build) =>
    WidgetbookUseCase(name: name, builder: (_) => build());

Widget _kanban(FakeHermesServer server) => withAppProviders(
  CatalogAuth(),
  KanbanScreen(
    repository: KanbanRepository(server.client()),
    connect: noKanbanEvents,
    files: NoKanbanFiles(),
  ),
);

WidgetbookNode statesNode() => WidgetbookFolder(
  name: 'Loading and errors',
  children: [
    WidgetbookComponent(
      name: 'KanbanScreen',
      useCases: [
        _state(
          'Boards fail to load',
          () => _kanban(
            _failing(
              _failing(kanbanServer(), 'GET', '/api/plugins/kanban/boards'),
              'GET',
              '/api/plugins/kanban/board',
            ),
          ),
        ),
        _state(
          'Loading',
          () => _kanban(
            _hanging(kanbanServer(), 'GET', '/api/plugins/kanban/board'),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'KanbanWorkersScreen',
      useCases: [
        _state(
          'Fails to load',
          () => KanbanWorkersScreen(
            repository: KanbanRepository(
              _failing(
                kanbanServer(),
                'GET',
                '/api/plugins/kanban/workers/active',
              ).client(),
            ),
          ),
        ),
        _state(
          'Loading',
          () => KanbanWorkersScreen(
            repository: KanbanRepository(
              _hanging(
                kanbanServer(),
                'GET',
                '/api/plugins/kanban/workers/active',
              ).client(),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'KanbanTaskPanel',
      useCases: [
        _state(
          'Task fails to load',
          () => Scaffold(
            body: KanbanTaskPanel(
              repository: KanbanRepository(
                _failing(
                  kanbanServer(),
                  'GET',
                  '/api/plugins/kanban/tasks/t_run',
                ).client(),
              ),
              taskId: 't_run',
              files: NoKanbanFiles(),
            ),
          ),
        ),
        _state(
          'Loading',
          () => Scaffold(
            body: KanbanTaskPanel(
              repository: KanbanRepository(
                _hanging(
                  kanbanServer(),
                  'GET',
                  '/api/plugins/kanban/tasks/t_run',
                ).client(),
              ),
              taskId: 't_run',
              files: NoKanbanFiles(),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'PluginsScreen',
      useCases: [
        _state(
          'Not available on this server',
          () => PluginsScreen(
            repository: HermesPluginManagerRepository(
              _failing(
                pluginsServer(),
                'GET',
                '/api/dashboard/plugins/hub',
                status: 404,
              ).client().raw,
            ),
          ),
        ),
        _state(
          'Loading',
          () => PluginsScreen(
            repository: HermesPluginManagerRepository(
              _hanging(
                pluginsServer(),
                'GET',
                '/api/dashboard/plugins/hub',
              ).client().raw,
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpServersScreen',
      useCases: [
        _state(
          'Fails to load',
          () => McpServersScreen(
            repository: HermesMcpRepository(
              _failing(mcpServer(), 'GET', '/api/mcp/servers').client().raw,
            ),
            profiles: HermesProfilesRepository(mcpServer().client().raw),
          ),
        ),
        _state(
          'Loading',
          () => McpServersScreen(
            repository: HermesMcpRepository(
              _hanging(mcpServer(), 'GET', '/api/mcp/servers').client().raw,
            ),
            profiles: HermesProfilesRepository(mcpServer().client().raw),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpCatalogScreen',
      useCases: [
        WidgetbookUseCase(
          name: 'Catalog fails to load',
          builder: (_) => Hosted<McpServersController>(
            create: () async {
              final server = _failing(mcpServer(), 'GET', '/api/mcp/catalog');
              final servers = McpServersController(
                repository: HermesMcpRepository(server.client().raw),
                profiles: HermesProfilesRepository(server.client().raw),
              );
              await servers.load();
              return servers;
            },
            dispose: (servers) => servers.dispose(),
            builder: (_, servers) => McpCatalogScreen(servers: servers),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SchedulesScreen',
      useCases: [
        for (final (name, server) in [
          (
            'Fails to load',
            () => _failing(schedulesServer(), 'GET', '/api/cron/jobs'),
          ),
          (
            'Loading',
            () => _hanging(schedulesServer(), 'GET', '/api/cron/jobs'),
          ),
        ])
          WidgetbookUseCase(
            name: name,
            builder: (_) => Hosted<SchedulesController>(
              create: () {
                final fake = server();
                return SchedulesController(
                  repository: HermesCronRepository(fake.client().raw),
                  profiles: HermesProfilesRepository(fake.client().raw),
                );
              },
              dispose: (controller) => controller.dispose(),
              builder: (_, controller) =>
                  SchedulesScreen(controller: controller, onOpenRun: (_, _) {}),
            ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'SkillsScreen',
      useCases: [
        _state('Fails to load', () {
          final server = _failing(skillsServer(), 'GET', '/api/skills');
          return SkillsScreen(
            repository: HermesSkillsRepository(server.client().raw),
            profiles: HermesProfilesRepository(server.client().raw),
            chatProfile: 'default',
          );
        }),
        _state('Loading', () {
          final server = _hanging(skillsServer(), 'GET', '/api/skills');
          return SkillsScreen(
            repository: HermesSkillsRepository(server.client().raw),
            profiles: HermesProfilesRepository(server.client().raw),
            chatProfile: 'default',
          );
        }),
      ],
    ),
    WidgetbookComponent(
      name: 'BotsScreen',
      useCases: [
        _state(
          'Fails to load',
          () => BotsScreen(
            repository: HermesBotsRepository(
              _failing(
                skillsServer(),
                'GET',
                '/api/messaging/platforms',
              ).client().raw,
            ),
          ),
        ),
        _state(
          'Loading',
          () => BotsScreen(
            repository: HermesBotsRepository(
              _hanging(
                skillsServer(),
                'GET',
                '/api/messaging/platforms',
              ).client().raw,
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'TelegramPairingScreen',
      useCases: [
        _state(
          'Pairing cannot start',
          () => TelegramPairingScreen(
            repository: HermesBotsRepository(
              _failing(
                skillsServer(),
                'POST',
                '/api/messaging/telegram/onboarding/start',
              ).client().raw,
            ),
            pollInterval: const Duration(days: 1),
            launchLink: (_) async => true,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ProfilesScreen',
      useCases: [
        _state(
          'Fails to load',
          () => ProfilesScreen(
            repository: HermesProfilesRepository(
              _failing(skillsServer(), 'GET', '/api/profiles').client().raw,
            ),
          ),
        ),
        _state(
          'Loading',
          () => ProfilesScreen(
            repository: HermesProfilesRepository(
              _hanging(skillsServer(), 'GET', '/api/profiles').client().raw,
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ChatScreen',
      useCases: [
        _state(
          'Threads fail to load',
          () => withAppProviders(
            CatalogAuth(gated: true),
            ChatScreen(
              repository: HermesChatRepository(
                _failing(kanbanServer(), 'GET', '/api/sessions').client().raw,
              ),
            ),
          ),
        ),
        _state(
          'Loading threads',
          () => withAppProviders(
            CatalogAuth(gated: true),
            ChatScreen(
              repository: HermesChatRepository(
                _hanging(kanbanServer(), 'GET', '/api/sessions').client().raw,
              ),
            ),
          ),
        ),
      ],
    ),
  ],
);
