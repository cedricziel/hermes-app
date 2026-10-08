import 'package:flutter/material.dart';

import '../../models/auxiliary_models.dart';
import '../../models/model_provider_option.dart';
import '../../models/moa_setup.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
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
              _ValueRow(
                key: Key('helper-${slot.task}'),
                title: slot.label,
                value: _describe(slot.choice),
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
              _ValueRow(
                key: const Key('helper-moa-preset'),
                title: 'Preset',
                value: moa.preset == 'default' ? 'Default' : moa.preset,
              ),
              for (final slot in moa.slots)
                _ValueRow(
                  key: Key('helper-${slot.key}'),
                  title: slot.label,
                  value: slot.enabled ? _describe(slot.choice) : 'Off',
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
}

/// A job and its model: on iOS the model as a muted value before the
/// chevron, on Material under the job, and on the Mac in a pop-up button.
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    super.key,
    required this.title,
    required this.value,
    this.busy = false,
    this.onTap,
  });

  final String title;
  final String value;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chrome = platformChromeOf(context);
    final onTap = busy ? null : this.onTap;
    final progress = busy
        ? SizedBox.square(
            dimension: chrome == PlatformChrome.macos ? 14 : 18,
            child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        : null;
    return switch (chrome) {
      PlatformChrome.material => GroupedRow(
        title: title,
        subtitle: value,
        trailing: progress,
        chevron: false,
        onTap: onTap,
      ),
      PlatformChrome.macos => GroupedRow(
        title: title,
        trailing: progress ?? _PopUpValue(value: value, onPressed: onTap),
      ),
      PlatformChrome.ios => GroupedRow(
        title: title,
        // GroupedRow's own value does not shrink for a long model id.
        trailing:
            progress ??
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.4,
              ),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: GroupedMetrics.of(context).subtitleSize,
                  color: context.hermesColors.subtleText,
                ),
              ),
            ),
        chevron: onTap != null,
        onTap: onTap,
      ),
    };
  }
}

/// A Mac pop-up button showing [value], which opens the picker.
class _PopUpValue extends StatelessWidget {
  const _PopUpValue({required this.value, required this.onPressed});

  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final color = enabled ? scheme.onSurface : context.hermesColors.subtleText;
    final radius = BorderRadius.circular(6);
    return Semantics(
      button: true,
      enabled: enabled,
      value: value,
      onTap: onPressed,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: scheme.outline),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 2, 6, 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                  ),
                  AppIcon(AppIcons.expandMore, size: 12, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
