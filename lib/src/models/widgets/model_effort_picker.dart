import 'package:flutter/material.dart';

import '../model_provider_option.dart';

/// Picks a provider, a model and (when the model takes one) a reasoning
/// effort. Plain model and callbacks: no controller, no repository. The
/// server only applies a change to sessions started after it, so a caller
/// wires [onSave] to `POST /api/model/set` and the copy below says so.
class ModelEffortPicker extends StatelessWidget {
  const ModelEffortPicker({
    super.key,
    required this.providers,
    required this.selectedProviderId,
    required this.selectedModelId,
    this.selectedEffort,
    required this.onModelSelected,
    required this.onEffortSelected,
    this.dirty = false,
    this.saving = false,
    this.onSave,
  });

  final List<ModelProviderOption> providers;
  final String selectedProviderId;
  final String selectedModelId;
  final String? selectedEffort;

  /// Called with the provider id and model id together: a model id is only
  /// unique within its provider.
  final void Function(String providerId, String modelId) onModelSelected;
  final ValueChanged<String?> onEffortSelected;

  final bool dirty;
  final bool saving;
  final VoidCallback? onSave;

  ModelOption? get _selectedModel {
    for (final provider in providers) {
      if (provider.id != selectedProviderId) continue;
      for (final model in provider.models) {
        if (model.id == selectedModelId) return model;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No model providers are configured on this server'),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioGroup<String>(
          groupValue: '$selectedProviderId::$selectedModelId',
          onChanged: (value) {
            if (value == null) return;
            final parts = value.split('::');
            onModelSelected(parts[0], parts[1]);
          },
          child: Column(
            children: [
              for (final provider in providers) _ProviderSection(provider),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _EffortSection(
          model: _selectedModel,
          selected: selectedEffort,
          onChanged: onEffortSelected,
        ),
        const SizedBox(height: 16),
        _SaveBar(dirty: dirty, saving: saving, onSave: onSave),
      ],
    );
  }
}

class _ProviderSection extends StatelessWidget {
  const _ProviderSection(this.provider);

  final ModelProviderOption provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(provider.displayLabel, style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              _StatusChip(provider.status),
            ],
          ),
        ),
        for (final model in provider.models)
          RadioListTile<String>(
            key: Key('model-${provider.id}-${model.id}'),
            value: '${provider.id}::${model.id}',
            enabled: provider.ready,
            title: Text(model.displayLabel),
          ),
        if (!provider.ready) _Needs(provider),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final ModelProviderStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = status == ModelProviderStatus.ready;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: ready ? scheme.primary : null,
        border: Border.all(color: ready ? scheme.primary : scheme.outline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ready ? 'Ready' : 'Needs setup',
        style: TextStyle(
          fontSize: 11,
          color: ready ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// What a provider that is not authenticated needs. It is set up on the
/// server: the app only shows the names.
class _Needs extends StatelessWidget {
  const _Needs(this.provider);

  final ModelProviderOption provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.requiredEnv.isEmpty)
            Text(
              'The server did not say what it needs.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            Text('Needs on the server', style: theme.textTheme.labelLarge),
            for (final name in provider.requiredEnv) Text(name, style: mono),
          ],
        ],
      ),
    );
  }
}

class _EffortSection extends StatelessWidget {
  const _EffortSection({
    required this.model,
    required this.selected,
    required this.onChanged,
  });

  final ModelOption? model;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = model?.supportedEfforts ?? const [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reasoning effort', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (options.isEmpty)
            Text(
              model == null
                  ? 'Pick a model to see its reasoning effort levels'
                  : '${model!.displayLabel} does not take a reasoning effort',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            SegmentedButton<String>(
              segments: [
                for (final option in options)
                  ButtonSegment(value: option, label: Text(_label(option))),
              ],
              selected: {selected ?? options.first},
              onSelectionChanged: (values) => onChanged(values.first),
            ),
        ],
      ),
    );
  }

  String _label(String effort) =>
      effort.isEmpty ? effort : effort[0].toUpperCase() + effort.substring(1);
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.dirty, required this.saving, this.onSave});

  final bool dirty;
  final bool saving;
  final VoidCallback? onSave;

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
              'Changes apply next time you start a chat with this profile',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            key: const Key('model-picker-save'),
            onPressed: dirty && !saving ? onSave : null,
            child: saving
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
