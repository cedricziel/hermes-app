import 'package:flutter/material.dart';
import 'package:hermes_app/src/mcp/mcp_banner.dart';
import 'package:hermes_app/src/mcp/mcp_chip.dart';
import 'package:widgetbook/widgetbook.dart';

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
            icon: Icons.check_circle_outline,
            title: 'Connected',
            detail: 'Found 12 tools.',
          ),
        ),
        _banner(
          'Warning with action',
          McpBanner(
            tone: McpTone.warning,
            icon: Icons.lock_outline,
            title: 'Sign-in needed',
            detail: 'Approve access in your browser.',
            action: TextButton(onPressed: () {}, child: const Text('Sign in')),
          ),
        ),
        _banner(
          'Error',
          const McpBanner(
            tone: McpTone.error,
            icon: Icons.error_outline,
            title: 'Could not reach the server',
            detail: 'Connection refused',
          ),
        ),
        _banner(
          'Title only',
          const McpBanner(
            tone: McpTone.success,
            icon: Icons.check_circle_outline,
            title: 'Saved',
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
