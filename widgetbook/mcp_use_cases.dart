import 'package:flutter/material.dart';
import 'package:hermes_app/src/mcp/mcp_banner.dart';
import 'package:hermes_app/src/mcp/mcp_chip.dart';
import 'package:hermes_app/src/mcp/mcp_command_review.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

WidgetbookUseCase _banner(String name, McpBanner banner) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(banner));

WidgetbookNode mcpNode() => WidgetbookFolder(
  name: 'MCP servers',
  children: [
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
