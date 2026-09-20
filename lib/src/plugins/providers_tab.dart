import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'plugin_tag.dart';
import 'plugins_controller.dart' show PluginsFailure;
import 'provider_settings.dart';
import 'providers_controller.dart';

/// Where the agent keeps its memory and how it compresses long chats. It
/// loads when it is first shown, and keeps what the user picked but has not
/// saved while other tabs are open.
class ProvidersTab extends StatefulWidget {
  const ProvidersTab({super.key, required this.controller});

  final ProvidersController controller;

  @override
  State<ProvidersTab> createState() => _ProvidersTabState();
}

class _ProvidersTabState extends State<ProvidersTab>
    with AutomaticKeepAliveClientMixin {
  ProvidersController get _controller => widget.controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  Future<void> _refresh() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _controller.refresh()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not refresh provider settings')),
      );
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await _controller.save();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.ok
                ? 'Saved. Applies to new chats.'
                : result.message ?? 'Could not save provider settings',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        switch (_controller.failure) {
          case PluginsFailure.unsupported:
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'The provider settings are not available on this server',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          case PluginsFailure.failed:
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load provider settings'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _controller.load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          case null:
            break;
        }
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  key: const Key('providers-list'),
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    _MemorySection(controller: _controller),
                    _ContextSection(controller: _controller),
                  ],
                ),
              ),
            ),
            _SaveBar(controller: _controller, onSave: _save),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.caption);

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({required this.controller});

  final ProvidersController controller;

  @override
  Widget build(BuildContext context) {
    final inUse = controller.settings.memoryProvider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'Memory provider',
          'Where the agent keeps long-term memory',
        ),
        RadioGroup<String>(
          groupValue: controller.memoryChoice,
          onChanged: (value) {
            if (value != null && !controller.saving) {
              controller.chooseMemory(value);
            }
          },
          child: Column(
            children: [
              const RadioListTile<String>(
                key: Key('memory-builtin'),
                value: '',
                title: Text('Built-in'),
                subtitle: Text('No external memory'),
              ),
              for (final option in controller.settings.memoryOptions) ...[
                RadioListTile<String>(
                  key: Key('memory-${option.name}'),
                  value: option.name,
                  enabled: option.ready || option.name == inUse,
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          option.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(option.status),
                    ],
                  ),
                  subtitle: option.description.isEmpty
                      ? null
                      : Text(
                          option.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                if (!option.ready) _Needs(option: option),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final ProviderStatus status;

  @override
  Widget build(BuildContext context) => PluginTag(switch (status) {
    ProviderStatus.ready => 'Ready',
    ProviderStatus.needsSetup => 'Needs setup',
    ProviderStatus.unavailable => 'Unavailable',
  }, filled: status == ProviderStatus.ready);
}

/// What a provider that is not ready needs. It is done on the server: the app
/// shows the names and commands and runs none of them.
class _Needs extends StatelessWidget {
  const _Needs({required this.option});

  final MemoryProviderOption option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(left: 40, right: 16),
      child: ExpansionTile(
        key: Key('needs-${option.name}'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text('What it needs', style: theme.textTheme.bodyMedium),
        children: [
          if (!option.namesRequirements)
            const Text('The server did not say what it needs.')
          else ...[
            if (option.requiredEnv.isNotEmpty) ...[
              Text('Environment variables', style: theme.textTheme.labelLarge),
              for (final name in option.requiredEnv) Text(name, style: mono),
              const SizedBox(height: 8),
            ],
            if (option.externalDependencies.isNotEmpty) ...[
              Text('Tools', style: theme.textTheme.labelLarge),
              for (final tool in option.externalDependencies) _Tool(tool: tool),
              const SizedBox(height: 8),
            ],
            if (option.pipDependencies.isNotEmpty) ...[
              Text('Python packages', style: theme.textTheme.labelLarge),
              for (final name in option.pipDependencies)
                Text(name, style: mono),
              const SizedBox(height: 8),
            ],
            Text(
              'Set this up on the server.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.tool});

  final ExternalDependency tool;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tool.name),
        if (tool.install.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  tool.install,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              IconButton(
                key: Key('copy-install-${tool.name}'),
                tooltip: 'Copy command',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: tool.install));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Copied')),
                  );
                },
              ),
            ],
          ),
      ],
    );
  }
}

class _ContextSection extends StatelessWidget {
  const _ContextSection({required this.controller});

  final ProvidersController controller;

  @override
  Widget build(BuildContext context) {
    final options = controller.contextOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'Context engine',
          'How long conversations are compressed',
        ),
        if (!controller.hasContextChoice)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (options.isNotEmpty) Text(options.first.name),
                const Text(
                  'No other context engines are available on this server',
                ),
              ],
            ),
          )
        else
          RadioGroup<String>(
            groupValue: controller.contextChoice,
            onChanged: (value) {
              if (value != null && !controller.saving) {
                controller.chooseContext(value);
              }
            },
            child: Column(
              children: [
                for (final option in options)
                  RadioListTile<String>(
                    key: Key('engine-${option.name}'),
                    value: option.name,
                    title: Text(option.name),
                    subtitle: option.description.isEmpty
                        ? null
                        : Text(option.description),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.controller, required this.onSave});

  final ProvidersController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Changes apply to new chats',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            key: const Key('providers-save'),
            onPressed: controller.dirty && !controller.saving ? onSave : null,
            child: controller.saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
