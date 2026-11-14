import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/disclosure_tile.dart';
import '../../widgets/grouped_list.dart';
import '../toolset_risk.dart';
import 'risk_note.dart';
import 'tools_target.dart';
import 'toolset_header.dart';

/// Everything a toolset's details show, as plain values.
class ToolsetDetailView {
  const ToolsetDetailView({
    required this.name,
    required this.sentence,
    required this.enabled,
    required this.where,
    this.needsSetup = false,
    this.phase = ToolsetHeaderPhase.idle,
    this.risk,
    this.tools = const [],
    this.error,
    this.unconfirmed = false,
    this.showTryAgain = false,
    this.locked = false,
  });

  final String name;
  final String sentence;

  /// The position the header's switch shows.
  final bool enabled;
  final bool needsSetup;
  final ToolsetHeaderPhase phase;

  /// "Used in your chats in this app and in the terminal." or the one-platform
  /// sentence, from the caller.
  final String where;

  /// A toolset in the risk table; its note shows before anything else can be
  /// changed. Null for the others.
  final ToolsetRisk? risk;

  /// The names the toolset's actions go by, shown collapsed.
  final List<String> tools;

  /// The error line of a change that failed, from the caller.
  final String? error;

  /// The last change could not be confirmed: the switch shows the saved
  /// state and the line says so.
  final bool unconfirmed;

  /// With [unconfirmed]: offer Try again, where there is no pull to refresh.
  final bool showTryAgain;

  /// A setup write of this toolset is out: the switch is disabled.
  final bool locked;
}

/// One toolset's details as the Tools screen shows them: the header with its
/// switch, the risk note, the slot for the setup sections, where the toolset
/// applies, and the collapsed tool names.
///
/// [setup] is where the sections that set the toolset up are added; it is
/// empty until they exist. [note] sits above the header, for the "Applies
/// from your next chat" note and the like. Plain values and callbacks only.
class ToolsetDetailBody extends StatelessWidget {
  const ToolsetDetailBody({
    super.key,
    required this.view,
    required this.onChanged,
    this.onTryAgain,
    this.note,
    this.setup = const [],
    this.namesOpen = false,
    this.physics,
  });

  final ToolsetDetailView view;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTryAgain;
  final Widget? note;

  /// The setup sections, in order, after the risk note.
  final List<Widget> setup;

  /// Starts with the tool names open (the catalog and tests).
  final bool namesOpen;

  /// The list's scroll physics; always scrollable where the details are
  /// pulled to refresh.
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final scheme = Theme.of(context).colorScheme;
    final risk = view.risk;
    final error = view.error;
    final tryAgain = view.unconfirmed && view.showTryAgain;
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: metrics.subtitleSize,
      color: scheme.onSurface,
    );
    return GroupedListView(
      physics: physics,
      children: [
        if (note != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: note),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ToolsetHeader(
            name: view.name,
            sentence: view.sentence,
            enabled: view.enabled,
            needsSetup: view.needsSetup,
            phase: view.phase,
            locked: view.locked,
            onChanged: onChanged,
          ),
        ),
        if (error != null || view.unconfirmed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error != null)
                  GroupedStatusLine(
                    icon: AppIcons.error,
                    text: error,
                    color: scheme.error,
                    size: metrics.subtitleSize,
                    scaleIcon: true,
                    liveRegion: true,
                  ),
                if (view.unconfirmed)
                  GroupedStatusLine(
                    icon: AppIcons.help,
                    text: tryAgain
                        ? l10n.toolsRowUnconfirmedRetry
                        : l10n.toolsRowUnconfirmedPull,
                    color: colors.warning,
                    size: metrics.subtitleSize,
                    scaleIcon: true,
                    liveRegion: true,
                  ),
                if (tryAgain)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: onTryAgain,
                      style: toolsButtonStyle(context),
                      child: Text(l10n.toolsTryAgain),
                    ),
                  ),
              ],
            ),
          ),
        if (risk != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RiskNote(
              kind: risk.kind,
              confirmLevel: risk.asksBeforeSwitchingOn,
            ),
          ),
        ...setup,
        GroupedSection(
          header: l10n.toolsWhereHeader,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.rowPadding,
                vertical: metrics.rowVerticalPadding + 4,
              ),
              child: Text(
                view.where,
                style: TextStyle(
                  fontSize: metrics.titleSize,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (view.tools.isNotEmpty)
          GroupedSection(
            footer: l10n.toolsInsideHelper,
            children: [
              DisclosureTile(
                initiallyExpanded: namesOpen,
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: EdgeInsets.symmetric(
                  horizontal: metrics.rowPadding,
                ),
                childrenPadding: EdgeInsets.fromLTRB(
                  metrics.rowPadding,
                  0,
                  metrics.rowPadding,
                  12,
                ),
                expandedAlignment: AlignmentDirectional.centerStart,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                minTileHeight: toolsTarget(context),
                title: Text(
                  l10n.toolsInsideTitle(view.tools.length),
                  style: TextStyle(
                    fontSize: metrics.titleSize,
                    color: scheme.onSurface,
                  ),
                ),
                children: [
                  for (final name in view.tools)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(name, style: mono),
                    ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
