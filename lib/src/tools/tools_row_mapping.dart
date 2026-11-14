import '../../l10n/l10n.dart';
import 'toolset_copy.dart';
import 'toolset_risk.dart';
import 'tools_controller.dart';
import 'tools_models.dart';
import 'widgets/toolset_detail_body.dart';
import 'widgets/toolset_header.dart';
import 'widgets/toolset_row.dart' as row;

/// The words of a failed change on its row: Hermes' own text for a refusal,
/// fixed copy for the rest. [name] is the toolset's display name.
String toolsRowErrorText(
  AppLocalizations l10n,
  ToolsRowError error,
  String name,
) => switch (error.kind) {
  ToolsRowErrorKind.refused =>
    (error.detail?.trim().isNotEmpty ?? false)
        ? error.detail!
        : l10n.toolsErrorFailed(name),
  ToolsRowErrorKind.forbidden => l10n.toolsErrorNotAllowed,
  ToolsRowErrorKind.offline => l10n.toolsErrorOffline(name),
  ToolsRowErrorKind.failed => l10n.toolsErrorFailed(name),
};

/// The display name of [toolset]: the app's own for a built-in, else the
/// server's label.
String toolsetName(AppLocalizations l10n, Toolset toolset) =>
    toolsetLabel(l10n, toolset.name, fallback: toolset.label);

/// The sentence of [toolset]: the app's own for a known built-in, else the
/// server's description.
String toolsetDescription(AppLocalizations l10n, Toolset toolset) =>
    toolsetSentence(l10n, toolset.name) ?? toolset.description;

row.ToolsetRowPhase _rowPhase(ToolsRowPhase phase) => switch (phase) {
  ToolsRowPhase.idle => row.ToolsetRowPhase.idle,
  ToolsRowPhase.preparing => row.ToolsetRowPhase.preparing,
  ToolsRowPhase.awaitingConfirmation =>
    row.ToolsetRowPhase.awaitingConfirmation,
  ToolsRowPhase.saving => row.ToolsetRowPhase.saving,
  ToolsRowPhase.checking => row.ToolsetRowPhase.checking,
  ToolsRowPhase.unconfirmed => row.ToolsetRowPhase.unconfirmed,
};

/// What a list row shows for [toolset] in [state].
///
/// Pure: no controller and no context. [desktop] (a Mac or a wide window,
/// where nothing pulls to refresh) turns "Couldn't confirm. Pull to refresh."
/// into the Try again form. A toolset the app has no sentence for is a
/// plugin's: it shows the server's label and description and no risk line.
row.ToolsetRowView toolsetRowView(
  AppLocalizations l10n,
  Toolset toolset,
  ToolsRowState state, {
  bool selected = false,
  bool desktop = false,
}) {
  final name = toolsetName(l10n, toolset);
  final error = state.error;
  return row.ToolsetRowView(
    name: name,
    sentence: toolsetDescription(l10n, toolset),
    enabled: state.shownEnabled ?? toolset.enabled,
    riskLine: toolsetRisk(toolset.name) != null,
    needsSetup: !toolset.configured,
    actionCount: toolset.tools.length,
    phase: _rowPhase(state.phase),
    showTryAgain: desktop,
    error: error == null ? null : toolsRowErrorText(l10n, error, name),
    selected: selected,
    unknownPlugin: toolsetSentence(l10n, toolset.name) == null,
  );
}

ToolsetHeaderPhase _headerPhase(ToolsRowPhase phase) => switch (phase) {
  ToolsRowPhase.preparing => ToolsetHeaderPhase.preparing,
  ToolsRowPhase.saving => ToolsetHeaderPhase.saving,
  ToolsRowPhase.checking => ToolsetHeaderPhase.checking,
  _ => ToolsetHeaderPhase.idle,
};

/// What the details of [toolset] show in [state].
ToolsetDetailView toolsetDetailView(
  AppLocalizations l10n,
  Toolset toolset,
  ToolsRowState state, {
  bool desktop = false,
}) {
  final name = toolsetName(l10n, toolset);
  final error = state.error;
  final platform = toolset.platformLabel.isNotEmpty
      ? toolset.platformLabel
      : toolset.platform;
  return ToolsetDetailView(
    name: name,
    sentence: toolsetDescription(l10n, toolset),
    enabled: state.shownEnabled ?? toolset.enabled,
    needsSetup: !toolset.configured,
    phase: _headerPhase(state.phase),
    where: toolset.platform == 'cli'
        ? l10n.toolsWhereCli
        : l10n.toolsWherePlatform(platform),
    risk: toolsetRisk(toolset.name),
    tools: toolset.tools,
    error: error == null ? null : toolsRowErrorText(l10n, error, name),
    unconfirmed: state.phase == ToolsRowPhase.unconfirmed,
    showTryAgain: desktop,
  );
}
