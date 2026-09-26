import 'package:flutter/material.dart';

import '../../theme/breakpoints.dart';
import '../model_provider_option.dart';

/// Opens [ModelPicker]: a bottom sheet on a phone, a dialog from
/// [kWideLayoutBreakpoint]. Without [withEffort] a pick is final, so it
/// closes the picker, and so does [onUseDefault].
Future<void> showModelPicker(
  BuildContext context, {
  required ModelOptions options,
  required ModelChoice? selected,
  required ValueChanged<ModelChoice> onChanged,
  bool withEffort = true,
  String title = 'Model',
  String? note,
  VoidCallback? onUseDefault,
}) {
  Widget picker(BuildContext sheet) => ModelPicker(
    options: options,
    selected: selected,
    withEffort: withEffort,
    title: title,
    note: note,
    onChanged: (choice) {
      onChanged(choice);
      if (!withEffort) Navigator.of(sheet).pop();
    },
    onUseDefault: onUseDefault == null
        ? null
        : () {
            onUseDefault();
            Navigator.of(sheet).pop();
          },
  );
  final size = MediaQuery.sizeOf(context);
  if (size.width >= kWideLayoutBreakpoint) {
    return showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
          child: picker(dialog),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.75),
        child: picker(sheet),
      ),
    ),
  );
}

/// Picks a model, grouped by provider, and the reasoning effort when the
/// model takes one, unless [withEffort] is off. Each pick is reported through
/// [onChanged] at once. [note], when given, is shown under [title].
class ModelPicker extends StatefulWidget {
  const ModelPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.withEffort = true,
    this.title = 'Model',
    this.note,
    this.onUseDefault,
  });

  final ModelOptions options;
  final ModelChoice? selected;
  final ValueChanged<ModelChoice> onChanged;
  final bool withEffort;
  final String title;
  final String? note;

  /// When set, a "Use the profile's default" entry comes first, checked
  /// while nothing is selected.
  final VoidCallback? onUseDefault;

  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<ModelPicker> {
  late ModelChoice? _selected = widget.selected;

  void _useDefault() {
    setState(() => _selected = null);
    widget.onUseDefault!();
  }

  void _pick(ModelChoice choice) {
    setState(() => _selected = choice);
    widget.onChanged(choice);
  }

  void _pickModel(String providerId, ModelOption model) {
    final effort = _selected?.effort;
    _pick(
      ModelChoice(
        providerId,
        model.id,
        effort: widget.withEffort && model.efforts.contains(effort)
            ? effort
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected;
    final efforts = selected == null || !widget.withEffort
        ? const <String>[]
        : widget.options.model(selected)?.efforts ?? const <String>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(widget.title, style: theme.textTheme.titleMedium),
        ),
        if (widget.note case final note?)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (widget.onUseDefault != null)
                ListTile(
                  key: const Key('model-default'),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: const Text('Use the profile’s default'),
                  trailing: selected == null
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: _useDefault,
                ),
              for (final provider in widget.options.providers) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    provider.displayLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final model in provider.models)
                  ListTile(
                    key: Key('model-${provider.id}-${model.id}'),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(model.id, overflow: TextOverflow.ellipsis),
                    trailing:
                        selected != null &&
                            selected.providerId == provider.id &&
                            selected.modelId == model.id
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () => _pickModel(provider.id, model),
                  ),
              ],
            ],
          ),
        ),
        if (efforts.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reasoning effort', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final effort in efforts)
                      ChoiceChip(
                        key: Key('effort-$effort'),
                        label: Text(effortLabel(effort)),
                        selected: selected!.effort == effort,
                        onSelected: (_) => _pick(
                          ModelChoice(
                            selected.providerId,
                            selected.modelId,
                            effort: effort,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
