import 'package:flutter/material.dart';

import 'hermes_mcp_repository.dart';
import 'mcp_banner.dart';
import 'mcp_catalog_controller.dart';
import 'mcp_install_controller.dart';
import 'mcp_presentation.dart';
import 'mcp_servers_controller.dart';

/// What installing a catalog entry involves and the form to do it: what
/// Hermes will run, the credentials the entry declares and the Install
/// button. The same widget fills a bottom sheet on a narrow layout and the
/// right-hand pane on a wide one.
///
/// The credentials live in this widget's text fields only. They go into the
/// install request and are cleared when it finishes.
class McpInstallPanel extends StatefulWidget {
  const McpInstallPanel({
    super.key,
    required this.servers,
    required this.catalog,
    required this.entry,
    this.onInstalled,
    this.onGone,
  });

  final McpServersController servers;
  final McpCatalogController catalog;
  final HermesMcpCatalogEntry entry;

  /// The entry is installed and the servers list shows it.
  final VoidCallback? onInstalled;

  /// Hermes no longer has the entry and the catalog has been reloaded.
  final VoidCallback? onGone;

  @override
  State<McpInstallPanel> createState() => _McpInstallPanelState();
}

class _McpInstallPanelState extends State<McpInstallPanel> {
  late final McpInstallController _install;
  late final Map<String, TextEditingController> _fields;
  late final Listenable _changes;
  bool _enable = true;

  @override
  void initState() {
    super.initState();
    _install = McpInstallController(
      servers: widget.servers,
      catalog: widget.catalog,
      entry: widget.entry,
      onInstalled: widget.onInstalled,
      onGone: widget.onGone,
    );
    _fields = {
      for (final credential in widget.entry.requiredEnv)
        credential.name: TextEditingController(),
    };
    _changes = Listenable.merge([_install, ..._fields.values]);
  }

  @override
  void dispose() {
    _install.dispose();
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  bool get _filled => widget.entry.requiredEnv.every(
    (c) => !c.required || _fields[c.name]!.text.isNotEmpty,
  );

  Future<void> _submit() async {
    final env = {for (final f in _fields.entries) f.key: f.value.text};
    await _install.install(env, enable: _enable);
    if (!mounted) return;
    for (final field in _fields.values) {
      field.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    final profile = widget.servers.profile;
    return ListenableBuilder(
      listenable: _changes,
      builder: (context, _) {
        final state = _install.state;
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Text('Install ${entry.name}', style: theme.textTheme.titleLarge),
            if (entry.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(entry.description),
            ],
            if (entry.source.isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(entry.source, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            _RunBlock(entry: entry),
            if (entry.requiredEnv.isNotEmpty) ...[
              const SizedBox(height: 16),
              const _Label('CREDENTIALS'),
              for (final credential in entry.requiredEnv)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _fields[credential.name],
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: credential.name,
                      helperText: credential.required
                          ? credential.prompt
                          : '${credential.prompt} (optional)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Saved on your Hermes server. It is never shown again.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Turn on after installing'),
              value: _enable,
              onChanged: _install.busy
                  ? null
                  : (on) => setState(() => _enable = on),
            ),
            _Outcome(state: state),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('mcp-install-button'),
              onPressed: _install.busy || !_filled || !widget.entry.hasTarget
                  ? null
                  : _submit,
              child: state is McpInstalling
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(profile == null ? 'Install' : 'Install on "$profile"'),
            ),
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.6),
  );
}

/// The "What Hermes will run" block: everything the catalog's trust model
/// asks the user to look at before installing.
class _RunBlock extends StatelessWidget {
  const _RunBlock({required this.entry});

  final HermesMcpCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final args = entry.args.join(' ');
    final auth = mcpAuthKindLabel(entry.authKind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What Hermes will run',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                switch (entry.transport) {
                  McpTransport.remote => const _Fact('type', 'remote (http)'),
                  McpTransport.command => const _Fact(
                    'type',
                    'command (stdio)',
                  ),
                  McpTransport.unknown => const SizedBox.shrink(),
                },
                if (entry.url?.isNotEmpty ?? false) _Fact('url', entry.url!),
                if (entry.command?.isNotEmpty ?? false)
                  _Fact('command', entry.command!),
                if (args.isNotEmpty) _Fact('args', args),
                if (auth != null) _Fact('auth', auth),
                if (entry.buildsLocally) ...[
                  _Fact('repository', entry.installUrl!),
                  if (entry.installRef != null) _Fact('ref', entry.installRef!),
                  for (final (i, step) in entry.bootstrap.indexed)
                    _Fact(i == 0 ? 'steps' : '', step),
                ],
              ],
            ),
          ),
        ),
        if (entry.transport == McpTransport.unknown) ...[
          const SizedBox(height: 8),
          const McpBanner(
            tone: McpTone.warning,
            icon: Icons.warning_amber_outlined,
            title: 'Hermes did not say how this server connects.',
          ),
        ],
        if (entry.buildsLocally) ...[
          const SizedBox(height: 8),
          Text(
            'The build runs on your Hermes server, not on this device, and '
            'can take a while.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.state});

  final McpInstallState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      McpBuilding() => const Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Building on your server…'),
        ],
      ),
      McpInstallFailed(:final message, :final log) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McpBanner(
            tone: McpTone.error,
            icon: Icons.error_outline,
            title: message,
          ),
          if (log.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                log.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ],
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
