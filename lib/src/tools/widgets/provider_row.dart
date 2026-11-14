import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_choice_row.dart';
import '../../widgets/grouped_list.dart';
import 'status_chip.dart';

/// A radio row for a provider of a toolset or a terminal backend: the name
/// with its [badge] as an outlined tag, the [line] (a tag line or a
/// description) muted under it, the [status] chip on its own line, then any
/// notes. A picked row shows a check mark in the link colour at the trailing
/// edge on Apple platforms; Material has a radio button at the leading edge.
///
/// It takes plain values. A row of a group is told apart from the others only
/// by [picked]; the caller turns a tap ([onPick]) into the choice. The row
/// reads as one element: name, badge, line, status and notes in that order.
class ProviderRow extends StatelessWidget {
  const ProviderRow({
    super.key,
    required this.name,
    required this.status,
    required this.picked,
    required this.onPick,
    this.badge,
    this.line,
    this.needsNousSignIn = false,
    this.hermesText,
    this.commandsWillFail = false,
    this.enabled = true,
  });

  final String name;
  final ToolsStatus status;
  final bool picked;

  /// Null makes the row inert, like [enabled] false but without dimming.
  final VoidCallback? onPick;

  /// A short word from the server, such as "paid" or "subscription".
  final String? badge;

  /// The provider's tag line or the backend's description.
  final String? line;

  /// Says the provider needs a sign-in the app cannot do.
  final bool needsNousSignIn;

  /// Hermes' own words about why a backend is not ready, shown as given.
  final String? hermesText;

  /// Warns that picking this backend leaves commands failing, for a picked
  /// backend that is not ready.
  final bool commandsWillFail;

  /// False while the choice cannot be changed (a write is out): the whole row
  /// is dimmed on every platform, the picked mark included, and taps do
  /// nothing. A picked row of an enabled group is not dimmed, even though a
  /// tap on it sends nothing.
  final bool enabled;

  /// Where the separators of a group of provider rows start.
  static double? dividerIndent(BuildContext context) =>
      GroupedChoiceRow.dividerIndent(context);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final apple = platformChromeOf(context).isApple;
    final line = this.line;
    final hermesText = this.hermesText;
    final badge = this.badge;
    Widget note(String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: metrics.subtitleSize,
          color: colors.subtleText,
        ),
      ),
    );
    final row = GroupedRow(
      title: name,
      titleMaxLines: null,
      titleBadge: badge == null || badge.isEmpty ? null : _Tag(badge),
      subtitle: line == null || line.isEmpty ? null : line,
      subtitleMaxLines: null,
      details: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusChip(status),
          ),
        ),
        if (needsNousSignIn) note(l10n.toolsProviderNeedsSignInNote),
        if (hermesText != null && hermesText.isNotEmpty)
          note(l10n.toolsProviderFromHermes(hermesText)),
        if (commandsWillFail)
          GroupedStatusLine(
            icon: AppIcons.warningFilled,
            text: l10n.toolsBackendCommandsFail,
            color: colors.warning,
            size: metrics.subtitleSize,
          ),
      ],
      leading: apple
          ? null
          : RadioGroup<bool>(
              groupValue: picked,
              // The picked row has no action but is not disabled: Material
              // draws a disabled radio grey, which reads as unavailable.
              onChanged: (_) => onPick?.call(),
              child: Radio<bool>(
                value: true,
                enabled: enabled,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
      trailing: apple
          ? SizedBox(
              width: 22,
              child: picked
                  ? AppIcon(AppIcons.check, size: 20, color: colors.link)
                  : null,
            )
          : null,
      chevron: false,
      checked: picked,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      onTap: onPick,
    );
    return enabled ? row : Opacity(opacity: 0.5, child: row);
  }
}

/// A badge as an outlined tag: the text is the status, the border only frames
/// it.
class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.3,
          color: context.hermesColors.subtleText,
        ),
      ),
    );
  }
}
