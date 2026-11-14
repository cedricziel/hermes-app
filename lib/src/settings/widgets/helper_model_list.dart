import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../models/auxiliary_models.dart';
import '../../models/model_provider_option.dart';
import '../../models/moa_setup.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/whats_the_difference_link.dart';

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
    this.onWhatsTheDifference,
  });

  final AuxiliaryModels models;
  final ValueChanged<AuxiliarySlot> onTap;
  final MoaSetup? moa;
  final ValueChanged<MoaSlot>? onTapMoa;
  final Set<String> saving;

  /// Opens the explanation of tools, skills, plugins and MCP servers; the link
  /// that ends the list. Null leaves it out.
  final VoidCallback? onWhatsTheDifference;

  @override
  Widget build(BuildContext context) {
    final moa = this.moa;
    final onTapMoa = this.onTapMoa;
    final onWhatsTheDifference = this.onWhatsTheDifference;
    // The Mac names the main model in the toolbar instead.
    final main = platformChromeOf(context) == PlatformChrome.macos
        ? null
        : mainModelName(models);
    final l10n = context.l10n;
    return GroupedListView(
      children: [
        GroupedSection(
          footer: [
            l10n.settingsHelperModelsFooterIntro,
            if (main != null) l10n.settingsHelperModelsFooterMainModel(main),
            l10n.settingsHelperModelsFooterApply,
          ].join(' '),
          children: [
            for (final slot in models.slots)
              GroupedValueRow(
                key: Key('helper-${slot.task}'),
                title: slot.label,
                value: _describe(l10n, slot.choice),
                caption: _details(l10n, slot.choice),
                busy: saving.contains(slot.task),
                onTap: () => onTap(slot),
              ),
          ],
        ),
        if (moa != null)
          GroupedSection(
            header: l10n.settingsHelperModelsMoaHeader,
            footer: moa.privacyFilterOn
                ? l10n.settingsHelperModelsMoaPrivacyFooter
                : null,
            children: [
              GroupedValueRow(
                key: const Key('helper-moa-preset'),
                title: l10n.settingsHelperModelsMoaPreset,
                value: moa.preset == 'default'
                    ? l10n.settingsHelperModelsMoaPresetDefault
                    : moa.preset,
              ),
              for (final slot in moa.slots)
                GroupedValueRow(
                  key: Key('helper-${slot.key}'),
                  title: slot.label,
                  value: _describe(l10n, slot.choice),
                  caption: _details(l10n, slot.choice, off: !slot.enabled),
                  busy: saving.contains(slot.key),
                  onTap: onTapMoa == null ? null : () => onTapMoa(slot),
                ),
            ],
          ),
        if (onWhatsTheDifference != null)
          WhatsTheDifferenceFooter(onTap: onWhatsTheDifference),
      ],
    );
  }

  static String _describe(AppLocalizations l10n, ModelChoice? choice) {
    if (choice == null) return l10n.settingsHelperModelsMainModel;
    if (choice.modelId.isEmpty) return l10n.settingsHelperModelsProviderDefault;
    return shortModelName(choice.modelId);
  }

  /// What the short value leaves out: "Off" for a slot switched off, the
  /// whole model id when it was shortened, the provider and the effort.
  static String? _details(
    AppLocalizations l10n,
    ModelChoice? choice, {
    bool off = false,
  }) {
    final effort = choice?.effort;
    final parts = [
      if (off) l10n.commonOff,
      if (choice != null) ...[
        if (shortModelName(choice.modelId) != choice.modelId) choice.modelId,
        if (choice.providerId.isNotEmpty) choice.providerId,
        if (effort != null && effort.isNotEmpty) effortLabel(effort),
      ],
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
