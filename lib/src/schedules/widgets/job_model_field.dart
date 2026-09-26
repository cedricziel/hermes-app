import 'package:flutter/material.dart';

import '../../models/model_provider_option.dart';
import '../../models/widgets/model_picker.dart';

/// The job form's model, which opens [ModelPicker] without effort and with
/// the profile's default as the first entry. [options] is null while loading
/// or when the list is unavailable; the picker then offers only the default.
/// A saved [model] the options do not list is shown as it is and only
/// replaced by a new pick.
class JobModelField extends StatelessWidget {
  const JobModelField({
    super.key,
    required this.options,
    required this.model,
    required this.provider,
    required this.onChanged,
  });

  final ModelOptions? options;
  final String model;
  final String provider;

  /// Reports a picked model and its provider, or two empty strings for the
  /// profile's default.
  final void Function(String model, String provider) onChanged;

  String? get _helper {
    if (model.isEmpty) return null;
    final options = this.options;
    final listed = options?.providers
        .where((p) => p.id == provider)
        .firstOrNull;
    final label = listed?.displayLabel ?? provider;
    if (options == null ||
        options.model(ModelChoice(provider, model)) != null) {
      return label.isEmpty ? null : label;
    }
    return [
      if (label.isNotEmpty) label,
      'Not in the server’s list',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('job-model'),
    onTap: () => showModelPicker(
      context,
      options: options ?? const ModelOptions(),
      selected: model.isEmpty ? null : ModelChoice(provider, model),
      withEffort: false,
      onUseDefault: () => onChanged('', ''),
      onChanged: (choice) => onChanged(choice.modelId, choice.providerId),
    ),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: 'Model',
        helperText: _helper,
        suffixIcon: const Icon(Icons.expand_more),
      ),
      child: Text(
        model.isEmpty ? 'Profile default' : model,
        style: Theme.of(context).textTheme.bodyLarge,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  );
}
