import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'hermes_mcp_repository.dart';
import 'mcp_banner.dart';
import 'mcp_presentation.dart';
import 'mcp_servers_controller.dart';
import 'mcp_sign_in_screen.dart';

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
  final confirmed = await showConfirmDialog(
    context,
    title: 'Remove ${server.name}?',
    message:
        '${server.name} is deleted from '
        '${profile == null ? 'the profile' : 'the $profile profile'}, '
        'not just switched off. This cannot be undone.',
    confirmLabel: 'Remove',
    destructive: true,
    filled: false,
  );
  if (!confirmed) return;
  if (await controller.remove(server) == McpOutcome.failed) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not remove ${server.name}')),
    );
  }
}

/// Starts signing in to [server] and follows it in the browser. When Hermes
/// reports the sign-in approved, the server is tested so its tools show.
Future<void> signInToMcpServer(
  BuildContext context,
  McpServersController controller,
  HermesMcpServer server,
) async {
  final navigator = Navigator.of(context);
  final start = await controller.startSignIn(server);
  if (start is! McpSignInStarted) return;
  if (!navigator.mounted) {
    controller.cancelSignIn(start.flow);
    return;
  }
  final approved = await navigator.push<bool>(
    MaterialPageRoute(
      builder: (_) => McpSignInScreen(
        controller: controller,
        server: server,
        flow: start.flow,
      ),
    ),
  );
  if (approved == true) await controller.test(server);
}

/// One server in full: how it connects, its switch, a connection test and its
/// tools, and removal. The same widget fills the page on a narrow layout and
/// the right-hand pane on a wide one, where [showName] heads it.
class McpServerDetail extends StatelessWidget {
  const McpServerDetail({
    super.key,
    required this.controller,
    required this.name,
    this.showName = true,
  });

  final McpServersController controller;
  final String name;

  /// Whether the server's name heads the detail; a page names it in its bar.
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final server = controller.serverNamed(name);
        if (server == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final muted = context.hermesColors.subtleText;
        final padding = GroupedMetrics.of(context).rowPadding;
        final facts = [
          ?mcpTransportLabel(server.transport),
          ?mcpAuthLabel(server),
        ].join(' · ');
        return GroupedListView(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showName)
                    Text(
                      server.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    facts,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  if (server.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SelectableText(
                      server.address,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GroupedSection(
              children: [
                GroupedSwitchRow(
                  title: 'Enabled',
                  subtitle: server.enabled
                      ? 'Used from the next chat'
                      : 'Not used from the next chat',
                  value: server.enabled,
                  onChanged: controller.isSwitching(server.name)
                      ? null
                      : (on) =>
                            switchMcpServer(context, controller, server, on),
                ),
              ],
            ),
            _Actions(controller: controller, server: server),
            if (controller.signInNoteOf(server.name) case final note?)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: McpBanner(
                  tone: McpTone.error,
                  icon: AppIcons.error,
                  title: note,
                ),
              ),
            _TestOutcome(controller: controller, server: server),
          ],
        );
      },
    );
  }
}

/// A spinner the size of a row's leading icon.
class _RowSpinner extends StatelessWidget {
  const _RowSpinner();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: GroupedMetrics.of(context).leadingSize,
    child: const Padding(
      padding: EdgeInsets.all(2),
      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
    ),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({required this.controller, required this.server});

  final McpServersController controller;
  final HermesMcpServer server;

  @override
  Widget build(BuildContext context) {
    final test = controller.testOf(server.name);
    final running = test is McpTestRunning;
    final signInNeeded = test is McpTestFinished && test.result.signInNeeded;
    final starting = controller.isStartingSignIn(server.name);
    return GroupedSection(
      dividerIndent: GroupedMetrics.of(context).indentAfterLeading,
      children: [
        if (server.usesOAuth && !signInNeeded)
          GroupedRow(
            title: 'Sign in',
            leading: starting
                ? const _RowSpinner()
                : const AppIcon(AppIcons.signIn),
            chevron: false,
            onTap: starting
                ? null
                : () => signInToMcpServer(context, controller, server),
          ),
        GroupedRow(
          title: 'Test connection',
          leading: running
              ? const _RowSpinner()
              : const AppIcon(AppIcons.check),
          chevron: false,
          onTap: running ? null : () => controller.test(server),
        ),
        GroupedRow(
          key: const Key('mcp-remove'),
          title: 'Remove',
          leading: AppIcon(
            AppIcons.delete,
            color: Theme.of(context).colorScheme.error,
          ),
          destructive: true,
          chevron: false,
          onTap: () => removeMcpServer(context, controller, server),
        ),
      ],
    );
  }
}

/// "Sign in" on the "Sign in needed" banner.
class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.controller, required this.server});

  final McpServersController controller;
  final HermesMcpServer server;

  @override
  Widget build(BuildContext context) {
    final starting = controller.isStartingSignIn(server.name);
    return TextButton.icon(
      onPressed: starting
          ? null
          : () => signInToMcpServer(context, controller, server),
      icon: starting
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : const AppIcon(AppIcons.signIn, size: 18),
      label: const Text('Sign in'),
    );
  }
}

class _TestOutcome extends StatelessWidget {
  const _TestOutcome({required this.controller, required this.server});

  final McpServersController controller;
  final HermesMcpServer server;

  @override
  Widget build(BuildContext context) {
    final (banner, tools) = switch (controller.testOf(server.name)) {
      null || McpTestRunning() => (null, const <HermesMcpTool>[]),
      McpTestUnavailable() => (
        McpBanner(
          tone: McpTone.error,
          icon: AppIcons.error,
          title: 'Could not test ${server.name}',
          action: TextButton(
            onPressed: () => controller.test(server),
            child: const Text('Retry'),
          ),
        ),
        const <HermesMcpTool>[],
      ),
      McpTestFinished(:final result) when result.signInNeeded => (
        McpBanner(
          tone: McpTone.warning,
          icon: AppIcons.lock,
          title: 'Sign in needed',
          detail:
              'Hermes has no OAuth token for this server yet, so it cannot '
              'list tools.',
          action: _SignInButton(controller: controller, server: server),
        ),
        const <HermesMcpTool>[],
      ),
      McpTestFinished(:final result) when !result.ok => (
        McpBanner(
          tone: McpTone.error,
          icon: AppIcons.error,
          title: 'Could not connect',
          detail: result.error,
        ),
        const <HermesMcpTool>[],
      ),
      McpTestFinished(:final result) => (
        McpBanner(
          tone: McpTone.success,
          icon: AppIcons.checkCircle,
          title: 'Connected',
          detail:
              '${mcpPlural(result.tools.length, 'tool')} · '
              '${mcpPlural(result.prompts, 'prompt')} · '
              '${mcpPlural(result.resources, 'resource')}',
        ),
        result.tools,
      ),
    };
    if (banner == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(top: 16), child: banner),
        if (tools.isNotEmpty)
          GroupedSection(
            header: 'Tools · ${tools.length}',
            footer:
                'The size next to a tool is what its schema costs the model '
                'in context. Hermes sends it with a test.',
            children: [
              for (final tool in tools)
                GroupedRow(
                  title: tool.name,
                  subtitle: tool.description.isEmpty ? null : tool.description,
                  subtitleMaxLines: null,
                  value: switch (tool.schemaChars) {
                    final chars? => mcpSchemaSize(chars),
                    null => null,
                  },
                ),
            ],
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
    return SettingsScaffold(
      title: name,
      subtitle: controller.profile,
      previousTitle: 'MCP servers',
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.serverNamed(name) == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              final route = ModalRoute.of(context);
              if (route == null) return;
              final navigator = Navigator.of(context);
              route.isCurrent ? navigator.pop() : navigator.removeRoute(route);
            });
          }
          return McpServerDetail(
            controller: controller,
            name: name,
            showName: false,
          );
        },
      ),
    );
  }
}
