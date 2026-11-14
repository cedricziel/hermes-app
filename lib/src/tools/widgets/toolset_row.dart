import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import 'tools_switch.dart';

/// Where a toolset's switch is in its round trip to Hermes.
enum ToolsetRowPhase {
  idle,

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

/// Why a change to a toolset failed. The text beside it comes from the
/// caller: Hermes' own for [refused], fixed copy for the others.
enum ToolsetRowErrorKind { refused, notAllowed, offline, failed }

class ToolsetRowError {
  const ToolsetRowError(this.kind, this.text);

  final ToolsetRowErrorKind kind;
  final String text;
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
  final ToolsetRowError? error;

  /// The toolset whose details show beside the list.
  final bool selected;

  /// A plugin's toolset: Hermes' label and description, and no risk line,
  /// since the app knows nothing about what it does.
  final bool unknownPlugin;
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
      if (phase == ToolsetRowPhase.checking)
        Padding(
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
      if (view.riskLine && !view.unknownPlugin)
        GroupedStatusLine(
          icon: AppIcons.shield,
          text: l10n.toolsRowCanChangeThings,
          color: scheme.onSurface,
          size: size,
        ),
      if (view.needsSetup)
        GroupedStatusLine(
          icon: AppIcons.warningFilled,
          text: l10n.toolsNeedsSetup,
          color: colors.warning,
          size: size,
        ),
      if (unconfirmed)
        GroupedStatusLine(
          icon: AppIcons.help,
          text: tryAgain
              ? l10n.toolsRowUnconfirmedRetry
              : l10n.toolsRowUnconfirmedPull,
          color: colors.warning,
          size: size,
        ),
      if (error != null)
        GroupedStatusLine(
          icon: AppIcons.error,
          text: error.text,
          color: scheme.error,
          size: size,
        ),
    ];

    final control = ToolsSwitch(
      name: view.name,
      value: view.enabled,
      saving: phase == ToolsetRowPhase.saving,
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
