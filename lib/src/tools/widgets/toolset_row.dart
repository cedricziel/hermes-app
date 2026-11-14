import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import 'tools_switch.dart';

/// Where a toolset's switch is in its round trip to Hermes.
enum ToolsetRowPhase {
  idle,

  /// Hermes is being asked what the switch needs, before a question or a
  /// write; nothing is sent yet. The switch is disabled at its saved
  /// position with a spinner.
  preparing,

  /// A write is out: the switch shows the new position, disabled.
  saving,

  /// The answer to a write was lost; the app is reading the list again.
  checking,

  /// The re-read failed or took too long: the row shows the last saved state.
  unconfirmed,

  /// A question is open that decides whether the switch moves; the switch is
  /// still at its saved position.
  awaitingConfirmation,
}

/// Everything a [ToolsetRow] shows, as plain values.
class ToolsetRowView {
  const ToolsetRowView({
    required this.name,
    required this.sentence,
    required this.enabled,
    this.riskLine = false,
    this.needsSetup = false,
    this.actionCount = 0,
    this.phase = ToolsetRowPhase.idle,
    this.showTryAgain = false,
    this.error,
    this.selected = false,
    this.unknownPlugin = false,
  });

  final String name;

  /// Up to three lines; the whole sentence at the largest text sizes.
  final String sentence;

  /// The position the switch shows.
  final bool enabled;

  /// Whether the toolset can change things ("Can change things").
  final bool riskLine;
  final bool needsSetup;

  /// How many actions the toolset has; none is not shown.
  final int actionCount;
  final ToolsetRowPhase phase;

  /// With [ToolsetRowPhase.unconfirmed]: offer Try again, where there is no
  /// pull to refresh.
  final bool showTryAgain;

  /// The error line of a change that failed, from the caller: Hermes' own
  /// text for a refusal, fixed copy for the rest.
  final String? error;

  /// The toolset whose details show beside the list.
  final bool selected;

  /// A plugin's toolset: Hermes' label and description, and no risk line,
  /// since the app knows nothing about what it does.
  final bool unknownPlugin;

  ToolsetRowView copyWith({
    bool? enabled,
    ToolsetRowPhase? phase,
    String? error,
    bool? selected,
  }) => ToolsetRowView(
    name: name,
    sentence: sentence,
    enabled: enabled ?? this.enabled,
    riskLine: riskLine,
    needsSetup: needsSetup,
    actionCount: actionCount,
    phase: phase ?? this.phase,
    showTryAgain: showTryAgain,
    error: error ?? this.error,
    selected: selected ?? this.selected,
    unknownPlugin: unknownPlugin,
  );
}

/// A toolset in the grouped list: name, sentence and state lines, with its
/// switch at the trailing edge. The text opens the details and the switch is
/// the row's only action, each its own control. At the largest text sizes the
/// switch has a line of its own with "On" or "Off" before it.
class ToolsetRow extends StatelessWidget {
  const ToolsetRow({
    super.key,
    required this.view,
    required this.onOpen,
    required this.onChanged,
    this.onTryAgain,
  });

  final ToolsetRowView view;
  final VoidCallback onOpen;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final large = toolsLargeText(context);
    final phase = view.phase;
    final size = metrics.subtitleSize;
    final unconfirmed = phase == ToolsetRowPhase.unconfirmed;
    final tryAgain = unconfirmed && view.showTryAgain;
    final error = view.error;

    final details = <Widget>[
      if (view.riskLine && !view.unknownPlugin)
        GroupedStatusLine(
          icon: AppIcons.shield,
          text: l10n.toolsRowCanChangeThings,
          color: scheme.onSurface,
          size: size,
          scaleIcon: true,
        ),
      if (view.needsSetup)
        GroupedStatusLine(
          icon: AppIcons.warningFilled,
          text: l10n.toolsNeedsSetup,
          color: colors.warning,
          size: size,
          scaleIcon: true,
        ),
      if (unconfirmed)
        GroupedStatusLine(
          icon: AppIcons.help,
          text: tryAgain
              ? l10n.toolsRowUnconfirmedRetry
              : l10n.toolsRowUnconfirmedPull,
          color: colors.warning,
          size: size,
          scaleIcon: true,
          liveRegion: true,
        ),
      if (error != null)
        GroupedStatusLine(
          icon: AppIcons.error,
          text: error,
          color: scheme.error,
          size: size,
          scaleIcon: true,
          liveRegion: true,
        ),
      // The count, which "Checking…" replaces in place.
      if (phase == ToolsetRowPhase.checking)
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              spacing: 6,
              children: [
                const ToolsSpinner(),
                Expanded(
                  child: Text(
                    l10n.toolsRowChecking,
                    style: TextStyle(
                      fontSize: metrics.footerSize,
                      color: colors.subtleText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
      else if (view.actionCount > 0)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            l10n.toolsActionCount(view.actionCount),
            style: TextStyle(
              fontSize: metrics.footerSize,
              color: colors.subtleText,
            ),
          ),
        ),
    ];

    final control = ToolsSwitch(
      name: view.name,
      value: view.enabled,
      saving: phase == ToolsetRowPhase.saving,
      preparing: phase == ToolsetRowPhase.preparing,
      showStateWord: large,
      onChanged: phase == ToolsetRowPhase.checking ? null : onChanged,
    );
    final trailing = tryAgain
        ? Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: onTryAgain,
                child: Text(l10n.toolsTryAgain),
              ),
              control,
            ],
          )
        : control;

    return GroupedRow(
      title: view.name,
      titleMaxLines: null,
      titleWeight: FontWeight.w600,
      subtitle: view.sentence.isEmpty ? null : view.sentence,
      subtitleMaxLines: large ? null : 3,
      details: details,
      trailing: trailing,
      separateTrailing: true,
      trailingBelow: large,
      onTap: onOpen,
      selected: view.selected,
    );
  }
}
