import 'package:flutter/material.dart';

import 'hermes_mcp_repository.dart';
import 'mcp_presentation.dart';
import 'mcp_servers_controller.dart';

/// Turns [server] on or off and says so when it could not.
Future<void> switchMcpServer(
  BuildContext context,
  McpServersController controller,
  HermesMcpServer server,
  bool enabled,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final outcome = await controller.setEnabled(server, enabled);
  if (outcome == McpOutcome.failed) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Could not turn ${server.name} ${enabled ? 'on' : 'off'}',
        ),
      ),
    );
  }
}

/// Asks before deleting [server], then does it.
Future<void> removeMcpServer(
  BuildContext context,
  McpServersController controller,
  HermesMcpServer server,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final profile = controller.profile;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Remove ${server.name}?'),
      content: Text(
        '${server.name} is deleted from '
        '${profile == null ? 'the profile' : 'the $profile profile'}, '
        'not just switched off. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (await controller.remove(server) == McpOutcome.failed) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not remove ${server.name}')),
    );
  }
}

/// One server in full: how it connects, its switch, a connection test and its
/// tools, and removal. The same widget fills the page on a narrow layout and
/// the right-hand pane on a wide one.
class McpServerDetail extends StatelessWidget {
  const McpServerDetail({
    super.key,
    required this.controller,
    required this.name,
  });

  final McpServersController controller;
  final String name;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final server = controller.serverNamed(name);
        if (server == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(server.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              [
                ?mcpTransportLabel(server.transport),
                ?mcpAuthLabel(server),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (server.address.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                server.address,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                title: const Text('Enabled'),
                subtitle: Text(
                  server.enabled
                      ? 'Used from the next chat'
                      : 'Not used from the next chat',
                ),
                value: server.enabled,
                onChanged: controller.isSwitching(server.name)
                    ? null
                    : (on) => switchMcpServer(context, controller, server, on),
              ),
            ),
            const SizedBox(height: 12),
            _Actions(controller: controller, server: server),
            const SizedBox(height: 12),
            _TestOutcome(controller: controller, server: server),
          ],
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.controller, required this.server});

  final McpServersController controller;
  final HermesMcpServer server;

  @override
  Widget build(BuildContext context) {
    final running = controller.testOf(server.name) is McpTestRunning;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: running ? null : () => controller.test(server),
            icon: running
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('Test connection'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Remove',
          color: Theme.of(context).colorScheme.error,
          icon: const Icon(Icons.delete_outline),
          onPressed: () => removeMcpServer(context, controller, server),
        ),
      ],
    );
  }
}

class _TestOutcome extends StatelessWidget {
  const _TestOutcome({required this.controller, required this.server});

  final McpServersController controller;
  final HermesMcpServer server;

  @override
  Widget build(BuildContext context) {
    return switch (controller.testOf(server.name)) {
      null || McpTestRunning() => const SizedBox.shrink(),
      McpTestUnavailable() => _Banner(
        tone: _Tone.error,
        icon: Icons.error_outline,
        title: 'Could not test ${server.name}',
        action: TextButton(
          onPressed: () => controller.test(server),
          child: const Text('Retry'),
        ),
      ),
      McpTestFinished(:final result) when result.signInNeeded => const _Banner(
        tone: _Tone.warning,
        icon: Icons.lock_outline,
        title: 'Sign in needed',
        detail: 'Hermes has no OAuth token for this server yet, so it cannot list tools.',
      ),
      McpTestFinished(:final result) when !result.ok => _Banner(
        tone: _Tone.error,
        icon: Icons.error_outline,
        title: 'Could not connect',
        detail: result.error,
      ),
      McpTestFinished(:final result) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Banner(
            tone: _Tone.success,
            icon: Icons.check_circle_outline,
            title: 'Connected',
            detail:
                '${mcpPlural(result.tools.length, 'tool')} · '
                '${mcpPlural(result.prompts, 'prompt')} · '
                '${mcpPlural(result.resources, 'resource')}',
          ),
          if (result.tools.isNotEmpty) _ToolList(tools: result.tools),
        ],
      ),
    };
  }
}

enum _Tone { success, warning, error }

class _Banner extends StatelessWidget {
  const _Banner({
    required this.tone,
    required this.icon,
    required this.title,
    this.detail = '',
    this.action,
  });

  final _Tone tone;
  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      _Tone.success => Colors.green.shade600,
      _Tone.warning => Colors.amber.shade700,
      _Tone.error => scheme.error,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (detail.isNotEmpty) Text(detail),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _ToolList extends StatelessWidget {
  const _ToolList({required this.tools});

  final List<HermesMcpTool> tools;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'TOOLS · ${tools.length}',
          style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final tool in tools)
                ListTile(
                  dense: true,
                  title: Text(
                    tool.name,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: tool.description.isEmpty
                      ? null
                      : Text(tool.description),
                  trailing: tool.schemaChars == null
                      ? null
                      : Text(
                          mcpSchemaSize(tool.schemaChars!),
                          style: theme.textTheme.bodySmall,
                        ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The size next to a tool is what its schema costs the model in '
          'context. Hermes sends it with a test.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// A server's detail as a page of its own, for narrow layouts. It closes when
/// the server is no longer on the list.
class McpServerPage extends StatelessWidget {
  const McpServerPage({
    super.key,
    required this.controller,
    required this.name,
  });

  final McpServersController controller;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MCP servers')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.serverNamed(name) == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.of(context).maybePop();
            });
          }
          return McpServerDetail(controller: controller, name: name);
        },
      ),
    );
  }
}
