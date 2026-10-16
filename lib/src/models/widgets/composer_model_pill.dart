import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/composer_selector_chip.dart';
import '../model_options_state.dart';
import '../model_provider_option.dart';
import 'model_picker.dart';

/// The current chat model and the state of its profile's model discovery.
class ComposerModelPill extends StatelessWidget {
  const ComposerModelPill({
    super.key,
    required this.options,
    required this.choice,
    required this.onChanged,
    this.state,
    this.onUseDefault,
    this.onRetry,
    this.onSetup,
  });

  final ModelOptions? options;
  final ModelChoice? choice;
  final ModelOptionsState? state;
  final ValueChanged<ModelChoice> onChanged;
  final VoidCallback? onUseDefault;
  final VoidCallback? onRetry;
  final VoidCallback? onSetup;

  @override
  Widget build(BuildContext context) {
    final options = this.options;
    final state =
        this.state ??
        (options == null
            ? ModelOptionsState.loading
            : options.providers.isEmpty
            ? ModelOptionsState.incomplete
            : ModelOptionsState.ready);
    final candidate = choice ?? options?.current;
    final shown = candidate != null && options?.model(candidate) != null
        ? candidate
        : null;
    final model =
        shown?.modelId ??
        (onUseDefault == null ? 'Choose a model' : 'Profile default');
    final effort = shown?.effort;
    final label = switch (state) {
      ModelOptionsState.loading => 'Loading models',
      ModelOptionsState.incomplete => 'Set up a model',
      ModelOptionsState.failed => 'Could not load models',
      ModelOptionsState.unsupported => choice?.modelId ?? 'Profile default',
      ModelOptionsState.ready =>
        '$model${effort == null ? '' : ' · ${effortLabel(effort)}'}',
    };
    return ComposerSelectorChip(
      key: const Key('composer-model-pill'),
      label: label,
      semanticLabel: state == ModelOptionsState.unsupported
          ? '$label. Model discovery is unavailable.'
          : (state == ModelOptionsState.loading ||
                    state == ModelOptionsState.failed) &&
                candidate != null
          ? '$label, selected model ${candidate.modelId}'
          : label,
      trailing: state == ModelOptionsState.ready
          ? const AppIcon(AppIcons.expandMore, size: 16)
          : null,
      actionLabel: state == ModelOptionsState.failed ? 'Retry' : null,
      actionSemanticLabel: 'Retry models',
      onAction: state == ModelOptionsState.failed ? onRetry : null,
      onPressed: switch (state) {
        ModelOptionsState.ready when options != null => () => showModelPicker(
          context,
          options: options,
          selected: shown,
          onChanged: onChanged,
          onUseDefault: onUseDefault,
        ),
        ModelOptionsState.incomplete ||
        ModelOptionsState.unsupported => onSetup,
        _ => null,
      },
    );
  }
}
