import 'package:flutter/material.dart';

import '../../models/auxiliary_models.dart';
import '../../models/model_provider_option.dart';
import '../../models/moa_setup.dart';
import '../../theme/hermes_theme.dart';

/// The helper model slots of a profile, one row each with the model it runs
/// on, and below them the mixture-of-agents slots when there is a [moa].
/// Rows whose task or MoA key is in [saving] show progress instead of a
/// chevron and ignore taps.
class HelperModelList extends StatelessWidget {
  const HelperModelList({
    super.key,
    required this.models,
    required this.onTap,
    this.moa,
    this.onTapMoa,
    this.saving = const {},
  });

  final AuxiliaryModels models;
  final ValueChanged<AuxiliarySlot> onTap;
  final MoaSetup? moa;
  final ValueChanged<MoaSlot>? onTapMoa;
  final Set<String> saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moa = this.moa;
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
          _row(
            slot.task,
            slot.label,
            _describe(slot.choice),
            () => onTap(slot),
          ),
        if (moa != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
            child: Text(
              moa.preset == 'default'
                  ? 'Mixture of agents'
                  : 'Mixture of agents · ${moa.preset}',
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final slot in moa.slots)
            _row(
              slot.key,
              slot.label,
              [_describe(slot.choice), if (!slot.enabled) 'off'].join(' · '),
              onTapMoa == null ? null : () => onTapMoa!(slot),
            ),
        ],
      ],
    );
  }

  Widget _row(String key, String title, String subtitle, VoidCallback? onTap) {
    final busy = saving.contains(key);
    return ListTile(
      key: Key('helper-$key'),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: busy ? null : onTap,
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
