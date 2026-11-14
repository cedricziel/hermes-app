import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import 'tools_switch.dart';

/// The top of a toolset's details: its name as the page heading, the switch,
/// one sentence and a state line with an icon ("On", "Off", "On · needs
/// setup"). At the largest text sizes the switch moves under the name with
/// the state line beside it.
class ToolsetHeader extends StatelessWidget {
  const ToolsetHeader({
    super.key,
    required this.name,
    required this.sentence,
    required this.enabled,
    required this.onChanged,
    this.needsSetup = false,
    this.saving = false,
  });

  final String name;
  final String sentence;

  /// The position the switch shows; while [saving] the one being written.
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool needsSetup;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final large = toolsLargeText(context);

    final (icon, color, text) = needsSetup
        ? (
            AppIcons.warningFilled,
            colors.warning,
            enabled
                ? l10n.toolsHeaderOnNeedsSetup
                : l10n.toolsHeaderOffNeedsSetup,
          )
        : enabled
        ? (AppIcons.checkCircleFilled, colors.success, l10n.commonOn)
        : (AppIcons.radioOff, colors.subtleText, l10n.commonOff);
    final state = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AppIcon(
            icon,
            size: MediaQuery.textScalerOf(context)
                .scale(metrics.subtitleSize + 2),
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: metrics.subtitleSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
    final control = ToolsSwitch(
      name: name,
      value: enabled,
      saving: saving,
      onChanged: onChanged,
    );
    final heading = Semantics(
      header: true,
      child: Text(
        name,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(metrics.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (large) ...[
            heading,
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [control, state],
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: heading),
                const SizedBox(width: 12),
                control,
              ],
            ),
          if (sentence.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                sentence,
                style: TextStyle(
                  fontSize: metrics.titleSize,
                  color: colors.subtleText,
                ),
              ),
            ),
          if (!large) ...[const SizedBox(height: 10), state],
        ],
      ),
    );
  }
}
