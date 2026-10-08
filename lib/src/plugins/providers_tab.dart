import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_icons.dart';
import 'plugins_controller.dart' show PluginsFailure;
import 'provider_settings.dart';
import 'providers_controller.dart';

import '../theme/platform_chrome.dart';
import '../widgets/disclosure_tile.dart';
import '../widgets/grouped_list.dart';
import '../widgets/named_icon_button.dart';

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
          return const Center(child: CircularProgressIndicator.adaptive());
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
                child: GroupedListView(
                  key: const Key('providers-list'),
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

/// The width of a shrink-wrapped Material radio button.
const _radioSize = 40.0;

/// Where the separators of a group of [_ChoiceRow]s start: past the radio
/// button on Material.
double? _choiceIndent(BuildContext context) {
  if (platformChromeOf(context).isApple) return null;
  final metrics = GroupedMetrics.of(context);
  return metrics.rowPadding + _radioSize + metrics.leadingGap;
}

/// A provider the user can pick: a check mark at the trailing edge on Apple
/// platforms, a radio button at the leading edge on Material.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.value,
    required this.title,
    this.subtitle,
    this.meta,
    this.warning,
    this.enabled = true,
    required this.onSelect,
  });

  final String value;
  final String title;
  final String? subtitle;
  final String? meta;
  final String? warning;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final apple = platformChromeOf(context).isApple;
    final radio = Radio<String>.adaptive(
      value: value,
      enabled: enabled,
      useCupertinoCheckmarkStyle: true,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return GroupedRow(
      title: title,
      subtitle: subtitle,
      meta: meta,
      warning: warning,
      leading: apple ? null : radio,
      trailing: apple ? radio : null,
      chevron: false,
      onTap: enabled ? () => onSelect(value) : null,
    );
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({required this.controller});

  final ProvidersController controller;

  void _choose(String? value) {
    if (value != null && !controller.saving) controller.chooseMemory(value);
  }

  @override
  Widget build(BuildContext context) {
    final inUse = controller.settings.memoryProvider;
    return RadioGroup<String>(
      groupValue: controller.memoryChoice,
      onChanged: _choose,
      child: GroupedSection(
        header: 'Memory provider',
        dividerIndent: _choiceIndent(context),
        footer: 'Where the agent keeps long-term memory.',
        children: [
          _ChoiceRow(
            key: const Key('memory-builtin'),
            value: '',
            title: 'Built-in',
            subtitle: 'No external memory',
            onSelect: _choose,
          ),
          for (final option in controller.memoryOptions) ...[
            _ChoiceRow(
              key: Key('memory-${option.name}'),
              value: option.name,
              enabled: option.ready || option.name == inUse,
              title: option.name,
              meta: option.ready ? _statusText(option.status) : null,
              warning: option.ready ? null : _statusText(option.status),
              subtitle: option.description.isEmpty ? null : option.description,
              onSelect: _choose,
            ),
            if (!option.ready) _Needs(option: option),
          ],
        ],
      ),
    );
  }
}

String _statusText(ProviderStatus status) => switch (status) {
  ProviderStatus.ready => 'Ready',
  ProviderStatus.needsSetup => 'Needs setup',
  ProviderStatus.unavailable => 'Unavailable',
};

/// What a provider that is not ready needs. It is done on the server: the app
/// shows the names and commands and runs none of them.
class _Needs extends StatelessWidget {
  const _Needs({required this.option});

  final MemoryProviderOption option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = GroupedMetrics.of(context);
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
      child: DisclosureTile(
        key: Key('needs-${option.name}'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          'What it needs',
          semanticsLabel: 'What ${option.name} needs',
          style: TextStyle(
            fontSize: metrics.titleSize,
            color: theme.colorScheme.onSurface,
          ),
        ),
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
              NamedIconButton(
                key: Key('copy-install-${tool.name}'),
                label: 'Copy command',
                icon: AppIcons.copy,
                iconSize: 18,
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

  void _choose(String? value) {
    if (value != null && !controller.saving) controller.chooseContext(value);
  }

  @override
  Widget build(BuildContext context) {
    final options = controller.contextOptions;
    return RadioGroup<String>(
      groupValue: controller.contextChoice,
      onChanged: _choose,
      child: GroupedSection(
        header: 'Context engine',
        footer: 'How long conversations are compressed.',
        dividerIndent: _choiceIndent(context),
        children: [
          if (!controller.hasContextChoice)
            GroupedRow(
              title: options.isEmpty ? 'None' : options.first.name,
              subtitle: 'No other context engines are available on this server',
            )
          else
            for (final option in options)
              _ChoiceRow(
                key: Key('engine-${option.name}'),
                value: option.name,
                title: option.name,
                subtitle: option.description.isEmpty
                    ? null
                    : option.description,
                onSelect: _choose,
              ),
        ],
      ),
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
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
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
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
