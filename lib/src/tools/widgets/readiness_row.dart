import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/disclosure_tile.dart';
import '../../widgets/grouped_list.dart';
import '../tools_models.dart';
import 'install_progress.dart';
import 'tools_switch.dart';
import 'tools_target.dart';

/// What a readiness check found. Each tone has its own icon, so it is never
/// told by colour alone.
enum ReadinessTone {
  /// A filled check in the success colour.
  ok,

  /// A filled cross in the warning colour, with a semibold value.
  bad,

  /// A filled question mark, muted.
  unknown,
}

/// One row of the Readiness section.
class ReadinessItem {
  const ReadinessItem({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final ReadinessTone tone;
}

/// One check Hermes ran, for the Details disclosure.
class ReadinessDetail {
  const ReadinessDetail({required this.label, this.text});

  final String label;
  final String? text;
}

/// The rows of the Readiness section for a server's [status]: the server's
/// system, the driver, the two permissions (only on a macOS server) and
/// whether Computer use is ready. A Linux server has the driver and ready
/// rows only.
List<ReadinessItem> readinessItems(
  AppLocalizations l10n,
  ComputerUseStatus status,
) {
  final mac = status.canGrant || status.platform?.toLowerCase() == 'darwin';
  ReadinessItem permission(String label, bool? value) => ReadinessItem(
    label: label,
    value: switch (value) {
      true => l10n.toolsReadinessAllowed,
      false => l10n.toolsReadinessNotAllowed,
      null => l10n.toolsReadinessCouldntTell,
    },
    tone: switch (value) {
      true => ReadinessTone.ok,
      false => ReadinessTone.bad,
      null => ReadinessTone.unknown,
    },
  );
  return [
    if (mac)
      ReadinessItem(
        label: l10n.toolsReadinessServerSystem,
        value: status.platformSupported
            ? l10n.toolsReadinessSystemSupported('macOS')
            : l10n.toolsReadinessSystemNotSupported('macOS'),
        tone: status.platformSupported ? ReadinessTone.ok : ReadinessTone.bad,
      ),
    ReadinessItem(
      label: l10n.toolsReadinessDriver,
      value: status.installed
          ? l10n.toolsReadinessInstalled
          : l10n.toolsReadinessNotInstalled,
      tone: status.installed ? ReadinessTone.ok : ReadinessTone.bad,
    ),
    if (mac) ...[
      permission(l10n.toolsReadinessAccessibility, status.accessibility),
      permission(l10n.toolsReadinessScreenRecording, status.screenRecording),
    ],
    ReadinessItem(
      label: l10n.toolsReadinessReady,
      value: switch (status.ready) {
        true => l10n.toolsReadinessYes,
        false => l10n.toolsReadinessNo,
        null => l10n.toolsReadinessCouldntTell,
      },
      tone: switch (status.ready) {
        true => ReadinessTone.ok,
        false => ReadinessTone.bad,
        null => ReadinessTone.unknown,
      },
    ),
  ];
}

/// A readiness row: the label at the start and the value with its icon at
/// the end. At the largest text sizes the value goes under the label. The
/// row reads as "label, value".
class ReadinessRow extends StatelessWidget {
  const ReadinessRow({super.key, required this.item});

  final ReadinessItem item;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, weight) = switch (item.tone) {
      ReadinessTone.ok => (
        AppIcons.checkCircleFilled,
        colors.success,
        FontWeight.w400,
      ),
      ReadinessTone.bad => (
        AppIcons.crossCircleFilled,
        colors.warning,
        FontWeight.w600,
      ),
      ReadinessTone.unknown => (
        AppIcons.questionCircleFilled,
        colors.subtleText,
        FontWeight.w400,
      ),
    };
    final value = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: AppIcon(
            icon,
            size: MediaQuery.textScalerOf(context)
                .scale(metrics.subtitleSize + 2),
            color: color,
          ),
        ),
        Flexible(
          child: Text(
            item.value,
            style: TextStyle(
              fontSize: metrics.subtitleSize + 1,
              fontWeight: weight,
              color: item.tone == ReadinessTone.unknown
                  ? colors.subtleText
                  : scheme.onSurface,
            ),
          ),
        ),
      ],
    );
    final label = Text(
      item.label,
      style: TextStyle(fontSize: metrics.titleSize, color: scheme.onSurface),
    );
    return Semantics(
      container: true,
      label: '${item.label}, ${item.value}',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.rowMinHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.rowPadding,
              vertical: metrics.rowVerticalPadding,
            ),
            child: toolsLargeText(context)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [label, const SizedBox(height: 2), value],
                  )
                // Both on one line when they fit, the value under the label
                // when they do not, instead of squeezing either.
                : Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 2,
                    children: [label, value],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The Readiness section of Computer use: the [items], an optional "Open the
/// bot's screen" row, "Details" as the last row, Hermes' [errorText] under
/// the group, then either "Install on server" (the driver is missing) or
/// "Allow access" (a permission is missing), each the one filled button.
///
/// The callbacks are the actions a state offers; a null one hides its
/// control. The caller asks before it installs or grants.
class ReadinessSection extends StatelessWidget {
  const ReadinessSection({
    super.key,
    required this.items,
    this.details = const [],
    this.errorText,
    this.onOpenBotScreen,
    this.onInstall,
    this.onAllowAccess,
    this.detailsInitiallyOpen = false,
  });

  final List<ReadinessItem> items;
  final List<ReadinessDetail> details;
  final String? errorText;
  final VoidCallback? onOpenBotScreen;
  final VoidCallback? onInstall;
  final VoidCallback? onAllowAccess;

  /// Starts with Details open. Only the catalog sets it, to draw that state.
  final bool detailsInitiallyOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final error = errorText;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedSection(
          header: l10n.toolsReadinessHeader,
          children: [
            for (final item in items) ReadinessRow(item: item),
            if (onOpenBotScreen != null)
              GroupedRow(
                title: l10n.toolsReadinessOpenScreen,
                titleMaxLines: null,
                onTap: onOpenBotScreen,
              ),
            if (details.isNotEmpty)
              DisclosureTile(
                title: Text(
                  l10n.toolsReadinessDetails,
                  style: TextStyle(
                    fontSize: metrics.titleSize,
                    color: scheme.onSurface,
                  ),
                ),
                initiallyExpanded: detailsInitiallyOpen,
                shape: const Border(),
                collapsedShape: const Border(),
                minTileHeight: metrics.rowMinHeight,
                tilePadding: EdgeInsets.symmetric(
                  horizontal: metrics.rowPadding,
                ),
                childrenPadding: EdgeInsets.fromLTRB(
                  metrics.rowPadding,
                  0,
                  metrics.rowPadding,
                  12,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final detail in details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.label,
                              style: TextStyle(
                                fontSize: metrics.subtitleSize,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            if (detail.text != null && detail.text!.isNotEmpty)
                              Text(
                                detail.text!,
                                style: TextStyle(
                                  fontSize: metrics.subtitleSize,
                                  color: colors.subtleText,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (error != null && error.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.rowPadding,
              8,
              metrics.rowPadding,
              0,
            ),
            child: Semantics(
              liveRegion: true,
              container: true,
              label: error,
              child: ExcludeSemantics(
                child: GroupedStatusLine(
                  icon: AppIcons.warningFilled,
                  text: error,
                  color: colors.warning,
                  size: metrics.subtitleSize,
                ),
              ),
            ),
          ),
        if (onInstall != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ToolsInstallButton(needsSetup: true, onPressed: onInstall),
          ),
        if (onAllowAccess != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: onAllowAccess,
                  style: toolsButtonStyle(context, wide: true),
                  icon: ExcludeSemantics(
                    child: AppIcon(AppIcons.lockOpen, size: 18),
                  ),
                  label: Text(l10n.toolsReadinessAllowAccess),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    metrics.rowPadding,
                    6,
                    metrics.rowPadding,
                    0,
                  ),
                  child: Text(
                    l10n.toolsReadinessAllowHelper,
                    style: TextStyle(
                      fontSize: metrics.footerSize,
                      color: colors.subtleText,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
