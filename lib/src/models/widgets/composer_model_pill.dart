import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../model_provider_option.dart';
import 'model_picker.dart';

/// A quiet pill naming the model a chat runs on, then its reasoning effort,
/// that opens [ModelPicker]. [choice] is the chat's own pick; without one the
/// pill names the profile's default model from [options]. Shows nothing
/// while [options] is null (loading, or not available) or offers no model.
class ComposerModelPill extends StatelessWidget {
  const ComposerModelPill({
    super.key,
    required this.options,
    required this.choice,
    required this.onChanged,
  });

  final ModelOptions? options;
  final ModelChoice? choice;
  final ValueChanged<ModelChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = this.options;
    if (options == null || options.providers.isEmpty) {
      return const SizedBox.shrink();
    }
    final shown = choice ?? options.current;
    final effort = shown?.effort;
    final theme = Theme.of(context);
    final quiet = context.hermesColors.subtleText;
    final style = theme.textTheme.labelMedium;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const Key('composer-model-pill'),
          borderRadius: BorderRadius.circular(999),
          onTap: () => showModelPicker(
            context,
            options: options,
            selected: shown,
            onChanged: onChanged,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    shown?.modelId ?? 'Choose a model',
                    style: style?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (effort != null)
                  Text(
                    ' · ${effortLabel(effort)}',
                    style: style?.copyWith(color: quiet),
                    maxLines: 1,
                  ),
                Icon(Icons.expand_more, size: 16, color: quiet),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
