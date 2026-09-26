import 'package:flutter/material.dart';

import '../../models/auxiliary_models.dart';
import '../../models/model_provider_option.dart';
import '../../theme/hermes_theme.dart';

/// The helper model slots of a profile, one row each with the model it runs
/// on. Rows in [saving] show progress instead of a chevron and ignore taps.
class HelperModelList extends StatelessWidget {
  const HelperModelList({
    super.key,
    required this.models,
    required this.onTap,
    this.saving = const {},
  });

  final AuxiliaryModels models;
  final ValueChanged<AuxiliarySlot> onTap;
  final Set<String> saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Hermes runs side jobs on these models. Changes apply to new '
            'chats.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.hermesColors.subtleText,
            ),
          ),
        ),
        for (final slot in models.slots)
          ListTile(
            key: Key('helper-${slot.task}'),
            title: Text(slot.label),
            subtitle: Text(
              _describe(slot.choice),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: saving.contains(slot.task)
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: saving.contains(slot.task) ? null : () => onTap(slot),
          ),
      ],
    );
  }

  String _describe(ModelChoice? choice) {
    if (choice == null) {
      final main = models.main?.modelId;
      return main == null || main.isEmpty
          ? 'Same as main model'
          : 'Same as main model ($main)';
    }
    final effort = choice.effort;
    return [
      if (choice.modelId.isEmpty) 'Provider default' else choice.modelId,
      choice.providerId,
      if (effort != null) effortLabel(effort),
    ].join(' · ');
  }
}
