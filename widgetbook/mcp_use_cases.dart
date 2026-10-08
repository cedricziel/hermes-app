import 'package:flutter/material.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_banner.dart';
import 'package:hermes_app/src/mcp/mcp_chip.dart';
import 'package:hermes_app/src/mcp/mcp_command_review.dart';
import 'package:hermes_app/src/mcp/widgets/mcp_server_row.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

WidgetbookUseCase _banner(String name, McpBanner banner) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(banner));

const _grafana = HermesMcpServer(
  name: 'grafana',
  transport: McpTransport.remote,
  url: 'https://mcp.grafana.com/mcp',
  auth: 'oauth',
);

const _linear = HermesMcpServer(
  name: 'linear',
  transport: McpTransport.remote,
  url: 'https://mcp.linear.app/mcp',
  auth: 'oauth',
);

const _filesystem = HermesMcpServer(
  name: 'filesystem',
  transport: McpTransport.command,
  command: 'npx',
  args: ['-y', '@modelcontextprotocol/server-filesystem'],
  enabled: false,
);

const _docs = HermesMcpServer(
  name: 'docs',
  transport: McpTransport.remote,
  url: 'https://docs.example.test/mcp',
);

Widget _rows(BuildContext context) => GroupedListView(
  children: [
    GroupedSection(
      dividerIndent: GroupedMetrics.of(context).indentAfterTile,
      footer:
          'Changes apply from the next chat, not to one that is already '
          'running.',
      children: [
        McpServerRow(
          server: _grafana,
          tested: const HermesMcpTestResult(
            ok: true,
            tools: [
              HermesMcpTool(name: 'search_dashboards'),
              HermesMcpTool(name: 'query_prometheus'),
            ],
          ),
          selected: true,
          onTap: () {},
          onSwitch: (_) {},
        ),
        McpServerRow(
          server: _linear,
          tested: const HermesMcpTestResult(ok: false, signInNeeded: true),
          onTap: () {},
          onSwitch: (_) {},
        ),
        McpServerRow(server: _filesystem, onTap: () {}, onSwitch: (_) {}),
        McpServerRow(
          server: _docs,
          switching: true,
          onTap: () {},
          onSwitch: (_) {},
        ),
      ],
    ),
  ],
);

WidgetbookNode mcpNode() => WidgetbookFolder(
  name: 'MCP servers',
  children: [
    WidgetbookComponent(
      name: 'McpServerRow',
      useCases: onEachPlatform(
        'Tested, sign-in needed, off and switching',
        _rows,
      ),
    ),
    WidgetbookComponent(
      name: 'McpBanner',
      useCases: [
        _banner(
          'Success',
          const McpBanner(
            tone: McpTone.success,
            icon: AppIcons.checkCircle,
            title: 'Connected',
            detail: 'Found 12 tools.',
          ),
        ),
        _banner(
          'Warning with action',
          McpBanner(
            tone: McpTone.warning,
            icon: AppIcons.lock,
            title: 'Sign-in needed',
            detail: 'Approve access in your browser.',
            action: TextButton(onPressed: () {}, child: const Text('Sign in')),
          ),
        ),
        _banner(
          'Error',
          const McpBanner(
            tone: McpTone.error,
            icon: AppIcons.error,
            title: 'Could not reach the server',
            detail: 'Connection refused',
          ),
        ),
        _banner(
          'Title only',
          const McpBanner(
            tone: McpTone.success,
            icon: AppIcons.checkCircle,
            title: 'Saved',
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpCommandReview',
      useCases: [
        WidgetbookUseCase(
          name: 'One command',
          builder: (_) => fill(
            const McpCommandReview(
              commands: [npxServer],
              confirmLabel: 'Add server',
            ),
            width: 480,
          ),
        ),
        WidgetbookUseCase(
          name: 'Several, with environment names',
          builder: (_) => fill(
            const McpCommandReview(
              commands: [npxServer, envServer],
              confirmLabel: 'Save servers',
            ),
            width: 480,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpChip',
      useCases: [
        WidgetbookUseCase(
          name: 'Plain and warning',
          builder: (_) => frame(
            const Wrap(
              spacing: 6,
              children: [
                McpChip('http'),
                McpChip('OAuth'),
                McpChip('Needs sign-in', warning: true),
              ],
            ),
          ),
        ),
      ],
    ),
  ],
);
