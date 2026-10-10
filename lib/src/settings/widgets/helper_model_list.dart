import 'package:flutter/material.dart';

import '../../models/auxiliary_models.dart';
import '../../models/model_provider_option.dart';
import '../../models/moa_setup.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';

/// The last path segment of a model id, such as "deepseek-v4-pro" for
/// "deepseek/deepseek-v4-pro".
String shortModelName(String modelId) => modelId.split('/').last;

/// The short name of the main model of [models], or null when it is unknown.
String? mainModelName(AuxiliaryModels models) {
  final main = models.main?.modelId;
  return main == null || main.isEmpty ? null : shortModelName(main);
}

/// The helper model slots of a profile, one value row each with the model it
/// runs on, and below them the mixture-of-agents slots when there is a [moa].
/// Rows whose task or MoA key is in [saving] show progress and ignore taps.
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
    final moa = this.moa;
    final onTapMoa = this.onTapMoa;
    // The Mac names the main model in the toolbar instead.
    final main = platformChromeOf(context) == PlatformChrome.macos
        ? null
        : mainModelName(models);
    return GroupedListView(
      children: [
        GroupedSection(
          footer: [
            'Hermes runs side jobs on these models.',
            if (main != null) 'Main model is $main.',
            'Changes apply to new chats.',
          ].join(' '),
          children: [
            for (final slot in models.slots)
              GroupedValueRow(
                key: Key('helper-${slot.task}'),
                title: slot.label,
                value: _describe(slot.choice),
                caption: _details(slot.choice),
                busy: saving.contains(slot.task),
                onTap: () => onTap(slot),
              ),
          ],
        ),
        if (moa != null)
          GroupedSection(
            header: 'Mixture of agents',
            footer: moa.privacyFilterOn
                ? 'Hermes’ privacy filter is on, and saving here would turn '
                      'it off. Change these slots on the server.'
                : null,
            children: [
              GroupedValueRow(
                key: const Key('helper-moa-preset'),
                title: 'Preset',
                value: moa.preset == 'default' ? 'Default' : moa.preset,
              ),
              for (final slot in moa.slots)
                GroupedValueRow(
                  key: Key('helper-${slot.key}'),
                  title: slot.label,
                  value: _describe(slot.choice),
                  caption: _details(slot.choice, off: !slot.enabled),
                  busy: saving.contains(slot.key),
                  onTap: onTapMoa == null ? null : () => onTapMoa(slot),
                ),
            ],
          ),
      ],
    );
  }

  static String _describe(ModelChoice? choice) {
    if (choice == null) return 'Main model';
    if (choice.modelId.isEmpty) return 'Provider default';
    return shortModelName(choice.modelId);
  }

  /// What the short value leaves out: "Off" for a slot switched off, the
  /// whole model id when it was shortened, the provider and the effort.
  static String? _details(ModelChoice? choice, {bool off = false}) {
    final effort = choice?.effort;
    final parts = [
      if (off) 'Off',
      if (choice != null) ...[
        if (shortModelName(choice.modelId) != choice.modelId) choice.modelId,
        if (choice.providerId.isNotEmpty) choice.providerId,
        if (effort != null && effort.isNotEmpty) effortLabel(effort),
      ],
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
